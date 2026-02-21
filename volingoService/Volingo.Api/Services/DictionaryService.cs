using System.Text.Json;
using Azure;
using Azure.AI.OpenAI;
using Microsoft.Azure.Cosmos;
using OpenAI.Chat;
using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Dictionary service backed by Cosmos DB + Azure OpenAI.
/// Container: dictionary, partition key: /word.
/// Flow: Cosmos lookup → (miss) AI generate → upsert → return.
/// </summary>
public class DictionaryService : IDictionaryService
{
    private readonly Container _container;
    private readonly IConfiguration _config;
    private readonly ILogger<DictionaryService> _logger;
    private ChatClient? _chatClient;

    private const string SystemPrompt = """
        You are an English dictionary engine. Generate a comprehensive dictionary entry
        for the given word in the following JSON format:

        {
          "word": "...",
          "phonetic": "/IPA notation/",
          "senses": [
            {
              "pos": "part of speech abbreviation (n., v., adj., adv., prep., conj., etc.)",
              "definitions": ["English definition 1", "English definition 2"],
              "translations": ["中文翻译1", "中文翻译2"],
              "examples": [
                { "en": "Example sentence in English.", "zh": "中文翻译。" }
              ]
            }
          ],
          "exchange": {
            "pastTense": "...", "pastParticiple": "...",
            "presentParticiple": "...", "thirdPersonSingular": "...",
            "plural": "...", "comparative": "...", "superlative": "..."
          },
          "synonyms": ["..."],
          "antonyms": ["..."],
          "relatedPhrases": [
            { "phrase": "...", "meaning": "中文含义" }
          ],
          "usageNotes": "中文使用说明，包含易混淆词对比和常见错误提示"
        }

        Rules:
        - If the input is NOT a real, recognized English word (including slang, abbreviations, or non-English text), return ONLY: {"error": "UNKNOWN_WORD"}
        - Include ALL common parts of speech for this word
        - Each sense should have 1-2 examples
        - Provide 3-5 synonyms and antonyms if applicable
        - Related phrases should be real, commonly used collocations
        - Usage notes should target Chinese English learners
        - Set irrelevant exchange fields to null
        - The phonetic field MUST use IPA wrapped in slashes, e.g. "/bæd/". Only ONE pronunciation. No brackets, no duplicates, no spaces around the IPA inside the slashes
        - Return ONLY valid JSON, no markdown
        """;

    public DictionaryService(CosmosClient cosmos, IConfiguration config, ILogger<DictionaryService> logger)
    {
        var db = config["CosmosDb:DatabaseName"] ?? "volingo";
        _container = cosmos.GetContainer(db, "dictionary");
        _config = config;
        _logger = logger;
    }

    public async Task<DictionaryResponse> LookupAsync(string word)
    {
        var normalised = word.Trim().ToLowerInvariant();
        if (string.IsNullOrEmpty(normalised))
            throw new ArgumentException("Word cannot be empty.", nameof(word));

        // ① Try Cosmos DB
        var doc = await TryReadFromCosmosAsync(normalised);
        if (doc is not null)
        {
            // Fire-and-forget: bump queryCount
            _ = Task.Run(() => IncrementQueryCountAsync(doc));
            return ToResponse(doc);
        }

        // ② Not found — generate via AI
        _logger.LogInformation("Dictionary miss for '{Word}', generating via AI...", normalised);
        doc = await GenerateWithAIAsync(normalised);

        // ③ Upsert to Cosmos (idempotent — handles concurrent requests for the same word)
        await _container.UpsertItemAsync(doc, new PartitionKey(normalised));
        _logger.LogInformation("Dictionary entry created for '{Word}'.", normalised);

        return ToResponse(doc);
    }

    // ── Cosmos helpers ──

    private async Task<DictionaryDocument?> TryReadFromCosmosAsync(string word)
    {
        try
        {
            var response = await _container.ReadItemAsync<DictionaryDocument>(word, new PartitionKey(word));
            return response.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
    }

    private async Task IncrementQueryCountAsync(DictionaryDocument doc)
    {
        try
        {
            doc.QueryCount++;
            await _container.ReplaceItemAsync(doc, doc.Id, new PartitionKey(doc.Word));
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to increment queryCount for '{Word}'.", doc.Word);
        }
    }

    // ── AI generation ──

    private ChatClient GetChatClient()
    {
        if (_chatClient is not null) return _chatClient;

        var endpoint = _config["AzureOpenAI:Endpoint"]
            ?? throw new InvalidOperationException("AzureOpenAI:Endpoint not configured.");
        var key = _config["AzureOpenAI:Key"]
            ?? throw new InvalidOperationException("AzureOpenAI:Key not configured.");
        var deployment = _config["AzureOpenAI:Deployment"] ?? "gpt-4o";

        var azureClient = new AzureOpenAIClient(new Uri(endpoint), new AzureKeyCredential(key));
        _chatClient = azureClient.GetChatClient(deployment);
        return _chatClient;
    }

    private async Task<DictionaryDocument> GenerateWithAIAsync(string word)
    {
        var client = GetChatClient();

        var options = new ChatCompletionOptions
        {
            Temperature = 0.2f,
            MaxOutputTokenCount = 4000,
            ResponseFormat = ChatResponseFormat.CreateJsonObjectFormat(),
        };

        var messages = new ChatMessage[]
        {
            new SystemChatMessage(SystemPrompt),
            new UserChatMessage($"Generate a dictionary entry for: {word}"),
        };

        var completion = await client.CompleteChatAsync(messages, options);
        var content = completion.Value.Content[0].Text;

        _logger.LogInformation("AI generated dictionary entry for '{Word}': {Chars} chars, {Input}+{Output} tokens",
            word, content.Length,
            completion.Value.Usage.InputTokenCount,
            completion.Value.Usage.OutputTokenCount);

        // Check if AI rejected the word as not a real English word
        using var jsonDoc = JsonDocument.Parse(content);
        if (jsonDoc.RootElement.TryGetProperty("error", out var errorProp)
            && errorProp.GetString() == "UNKNOWN_WORD")
        {
            _logger.LogInformation("AI rejected '{Word}' as not a real English word.", word);
            throw new WordNotFoundException(word);
        }

        var generated = JsonSerializer.Deserialize<DictionaryDocument>(content, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true,
        }) ?? throw new InvalidOperationException($"AI returned invalid JSON for '{word}'.");

        // Ensure canonical fields
        generated.Id = word;
        generated.Word = word;
        generated.Source = "ai";
        generated.CreatedAt = DateTime.UtcNow;
        generated.QueryCount = 1;

        return generated;
    }

    // ── Mapping ──

    private static DictionaryResponse ToResponse(DictionaryDocument doc) =>
        new(
            Word: doc.Word,
            Phonetic: doc.Phonetic,
            Senses: doc.Senses.Select(s => new DictionarySenseDto(
                s.Pos,
                s.Definitions,
                s.Translations,
                s.Examples.Select(e => new DictionaryExampleDto(e.En, e.Zh)).ToList()
            )).ToList(),
            Exchange: doc.Exchange is null ? null : new DictionaryExchangeDto(
                doc.Exchange.PastTense,
                doc.Exchange.PastParticiple,
                doc.Exchange.PresentParticiple,
                doc.Exchange.ThirdPersonSingular,
                doc.Exchange.Plural,
                doc.Exchange.Comparative,
                doc.Exchange.Superlative
            ),
            Synonyms: doc.Synonyms,
            Antonyms: doc.Antonyms,
            RelatedPhrases: doc.RelatedPhrases.Select(p => new RelatedPhraseDto(p.Phrase, p.Meaning)).ToList(),
            UsageNotes: doc.UsageNotes
        );
}
