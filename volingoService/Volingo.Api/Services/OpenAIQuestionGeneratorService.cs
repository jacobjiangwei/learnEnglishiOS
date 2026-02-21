using System.Text.Json;
using Azure;
using Azure.AI.OpenAI;
using OpenAI.Chat;
using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Uses GPT-4o to generate practice questions from textbook analysis data.
/// Each question type is generated in a separate API call to ensure correct counts.
/// </summary>
public class OpenAIQuestionGeneratorService(
    IConfiguration config,
    ILogger<OpenAIQuestionGeneratorService> logger)
    : IQuestionGeneratorService
{
    private ChatClient? _chatClient;

    private ChatClient GetChatClient()
    {
        if (_chatClient is not null) return _chatClient;

        var endpoint = config["AzureOpenAI:Endpoint"]
            ?? throw new InvalidOperationException("AzureOpenAI:Endpoint not configured.");
        var key = config["AzureOpenAI:Key"]
            ?? throw new InvalidOperationException("AzureOpenAI:Key not configured.");
        var deployment = config["AzureOpenAI:Deployment"] ?? "gpt-4o";

        var azureClient = new AzureOpenAIClient(new Uri(endpoint), new AzureKeyCredential(key));
        _chatClient = azureClient.GetChatClient(deployment);
        return _chatClient;
    }

    public async Task<List<Dictionary<string, object>>> GenerateQuestionsAsync(GenerateQuestionsRequest request)
    {
        var typeSpecs = GetTypeSpecs(request.Batch);
        var allQuestions = new List<Dictionary<string, object>>();
        var client = GetChatClient();

        // Generate each question type in a separate API call to ensure correct counts
        foreach (var spec in typeSpecs)
        {
            logger.LogInformation(
                "Generating {Count}× {Type} for {TextbookCode} Unit {Unit}",
                spec.Count, spec.TypeName, request.TextbookCode, request.UnitNumber);

            var systemPrompt = BuildSystemPrompt(request, spec);
            var userPrompt = BuildUserPrompt(request, spec);

            var options = new ChatCompletionOptions
            {
                Temperature = 0.7f,
                MaxOutputTokenCount = 16384,
                ResponseFormat = ChatResponseFormat.CreateJsonObjectFormat(),
            };

            var messages = new ChatMessage[]
            {
                new SystemChatMessage(systemPrompt),
                new UserChatMessage(userPrompt),
            };

            var completion = await client.CompleteChatAsync(messages, options);
            var content = completion.Value.Content[0].Text;
            var finishReason = completion.Value.FinishReason;

            logger.LogInformation(
                "GPT-4o [{Type}]: {Chars} chars, finish={Reason}, usage: {Input}+{Output} tokens",
                spec.TypeName, content.Length, finishReason,
                completion.Value.Usage.InputTokenCount,
                completion.Value.Usage.OutputTokenCount);

            if (finishReason == ChatFinishReason.Length)
            {
                logger.LogWarning("GPT-4o output TRUNCATED for {Type}. Questions may be incomplete.", spec.TypeName);
            }

            var parsed = JsonSerializer.Deserialize<JsonElement>(content);
            if (parsed.TryGetProperty("questions", out var questionsArray)
                && questionsArray.ValueKind == JsonValueKind.Array)
            {
                var count = 0;
                foreach (var item in questionsArray.EnumerateArray())
                {
                    var dict = JsonElementToDict(item);
                    dict.TryAdd("id", Guid.NewGuid().ToString());
                    dict.TryAdd("textbookCode", request.TextbookCode);
                    dict.TryAdd("unitNumber", request.UnitNumber);
                    dict.TryAdd("level", request.Level);
                    dict.TryAdd("generatedBy", "gpt-4o");
                    dict.TryAdd("generatedAt", DateTime.UtcNow.ToString("o"));
                    allQuestions.Add(dict);
                    count++;
                }
                logger.LogInformation("Got {Count}/{Expected} {Type} questions",
                    count, spec.Count, spec.TypeName);
            }
        }

        logger.LogInformation("Total: {Count} questions from GPT-4o for batch {Batch}",
            allQuestions.Count, request.Batch);
        return allQuestions;
    }

    // ── Type specs & prompt builders ──

    private record TypeSpec(string TypeName, string ChineseName, int Count, string FieldSpec);

    private static List<TypeSpec> GetTypeSpecs(QuestionBatch batch) => batch switch
    {
        QuestionBatch.VocabCloze =>
        [
            new("vocabulary", "词汇选择题", 15, """
                JSON 字段: id, questionType("vocabulary"), word, phonetic, meaning, stem, translation,
                  options(4个选项), correctIndex(0-based), exampleSentence, exampleTranslation,
                  explanation, category("meaning"/"spelling"/"form"/"synonym")
                - category 要均匀分布
                """),
            new("cloze", "填空题", 10, """
                JSON 字段: id, questionType("cloze"), sentence(用___标记空白), translation,
                  correctAnswer, hints(提示数组), explanation
                """),
        ],
        QuestionBatch.GrammarMcqError =>
        [
            new("grammar", "语法选择题", 8, """
                JSON 字段: id, questionType("grammar"), stem, translation,
                  options(4个选项), correctIndex(0-based), grammarPoint, grammarPointTranslation,
                  explanation
                """),
            new("multipleChoice", "综合选择题", 10, """
                JSON 字段: id, questionType("multipleChoice"), stem, translation,
                  options(4个选项), correctIndex(0-based), explanation
                """),
            new("errorCorrection", "纠错题", 5, """
                JSON 字段: id, questionType("errorCorrection"), sentence, translation,
                  errorRange(错误部分的文本), correction(正确写法),
                  explanation
                """),
        ],
        QuestionBatch.TransRewriteOrder =>
        [
            new("translation", "翻译题", 6, """
                JSON 字段: id, questionType("translation"), sourceText, direction("enToZh"或"zhToEn"),
                  referenceAnswer, keywords(关键词数组), explanation
                - 中译英和英译中各占一半
                """),
            new("rewriting", "句型改写题", 5, """
                JSON 字段: id, questionType("rewriting"), originalSentence, originalTranslation,
                  instruction, instructionTranslation, referenceAnswer, referenceTranslation,
                  explanation
                """),
            new("sentenceOrdering", "排序题", 5, """
                JSON 字段: id, questionType("sentenceOrdering"), shuffledParts(打乱的单词/短语数组),
                  correctOrder(正确顺序的索引数组), correctSentence, translation,
                  explanation
                """),
        ],
        QuestionBatch.ReadingWriting =>
        [
            new("reading", "阅读理解", 3, """
                JSON 字段: id, questionType("reading"), title, content(短文内容),
                  translation(短文中文翻译),
                  questions(子题数组, 每个子题包含: id, stem, translation, options(4个), correctIndex,
                    explanation)
                - 短文内容必须使用本单元词汇和句型
                - 每篇短文配 3-4 个子题
                """),
            new("writing", "写作题", 3, """
                JSON 字段: id, questionType("writing"), prompt, promptTranslation,
                  category("sentence"/"paragraph"/"essay"/"application"),
                  wordLimit(包含 min 和 max), referenceAnswer, referenceTranslation
                """),
        ],
        QuestionBatch.ListeningSpeaking =>
        [
            new("listening", "听力题", 6, """
                JSON 字段: id, questionType("listening"), transcript, transcriptTranslation,
                  stem, stemTranslation, options(4个选项), correctIndex(0-based),
                  explanation
                - 不需要 audioURL，后期由 TTS 生成
                """),
            new("speaking", "口语题", 6, """
                JSON 字段: id, questionType("speaking"), prompt, referenceText, translation,
                  category("readAloud"/"translateSpeak"/"listenRepeat"/"completeSpeak")
                - readAloud: prompt 提示朗读, referenceText 为英文句子
                - translateSpeak: prompt 提示翻译, referenceText 为英文, translation 为中文题干
                - listenRepeat: prompt 提示跟读, referenceText 为英文句子
                - completeSpeak: prompt 中含 ___ 空白, referenceText 为完整句子
                - category 要均匀分布
                """),
        ],
        _ => [],
    };

    private static string BuildSystemPrompt(GenerateQuestionsRequest request, TypeSpec spec)
    {
        return $$"""
            你是一个专业的英语教育出题专家。
            
            出题规范：
            - 每道选择题必须有且只有一个正确答案。出完题后自查：把每个选项逐一代入 stem，必须只有正确答案成立、其余三个都说不通，否则废弃重出
            - 选择题的 stem 用补全句子、补全对话、选词填空、释义匹配等形式
            - 干扰项必须是同类词/同词性，且在语法上能嵌入 stem，仅在语义上错误
            - 题目要有层次感：基础记忆题与语境理解题合理搭配
            
            严格规则：
            1. 所有题目必须基于给定的词汇和句型，不能超纲
            2. 中文翻译准确自然，适合 {{request.Level}} 学生
            3. 干扰项优先从「全书词汇表」中选择形近/义近词
            4. 每道题都要有详细的解析（explanation），用中文写，可以自然地穿插英文单词
            5. 输出严格 JSON 格式，顶层 key 为 "questions"，值为数组
            6. 每道题必须包含 "questionType" 字段
            7. 每道题的 id 用 UUID 格式
            8. 选择题的正确答案始终放在 options[0]（correctIndex 固定为 0），服务端会自动打乱顺序
            9. 题干（stem）不能泄露答案。vocabulary meaning 题用中文释义提问（如 Which of the following means "再见"？）

            本次任务：生成恰好 {{spec.Count}} 道 {{spec.ChineseName}}（questionType: "{{spec.TypeName}}"）

            {{spec.FieldSpec}}
            """;
    }

    private static string BuildUserPrompt(GenerateQuestionsRequest request, TypeSpec spec)
    {
        var vocabJson = JsonSerializer.Serialize(request.Unit.Vocabulary, JsonOpts);
        var patternsJson = JsonSerializer.Serialize(request.Unit.SentencePatterns, JsonOpts);
        var grammarJson = JsonSerializer.Serialize(request.Unit.Grammar, JsonOpts);
        var commandsJson = JsonSerializer.Serialize(request.Unit.Commands, JsonOpts);

        var glossarySubset = request.Glossary.Count > 200
            ? request.Glossary.Take(200).ToList()
            : request.Glossary;
        var glossaryJson = JsonSerializer.Serialize(glossarySubset, JsonOpts);

        return $$"""
            === 当前教材信息 ===
            教材代码: {{request.TextbookCode}}
            教材名称: {{request.DisplayName}}
            学段: {{request.Level}}
            单元: Unit {{request.UnitNumber}} — {{request.Unit.UnitTitle ?? ""}}
            话题: {{request.Unit.Topic ?? "未指定"}}

            === 本单元词汇表 ===
            {{vocabJson}}

            === 本单元核心句型 ===
            {{patternsJson}}

            === 本单元语法要点 ===
            {{grammarJson}}

            === 本单元课堂指令 ===
            {{commandsJson}}

            {{(request.Unit.StorySummary is not null ? $"=== 本单元故事 ===\n{request.Unit.StoryTitle}: {request.Unit.StorySummary}" : "")}}

            === 全书词汇表（用于生成干扰项）===
            {{glossaryJson}}

            === 生成要求 ===
            请生成恰好 {{spec.Count}} 道 {{spec.ChineseName}}（questionType: "{{spec.TypeName}}"），不多不少。

            请以 JSON 格式输出，格式为 {"questions": [...]}
            """;
    }

    // ── Helpers ──

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = false,
    };

    /// <summary>
    /// Recursively convert a JsonElement to a Dictionary or List structure
    /// so it can be serialized back to Cosmos as dynamic JSON.
    /// </summary>
    private static Dictionary<string, object> JsonElementToDict(JsonElement element)
    {
        var dict = new Dictionary<string, object>();
        foreach (var prop in element.EnumerateObject())
        {
            dict[prop.Name] = ConvertJsonElement(prop.Value);
        }
        return dict;
    }

    private static object ConvertJsonElement(JsonElement element) => element.ValueKind switch
    {
        JsonValueKind.String => element.GetString() ?? "",
        JsonValueKind.Number => element.TryGetInt32(out var i) ? i : element.GetDouble(),
        JsonValueKind.True => true,
        JsonValueKind.False => false,
        JsonValueKind.Array => element.EnumerateArray().Select(ConvertJsonElement).ToList(),
        JsonValueKind.Object => JsonElementToDict(element),
        _ => element.GetRawText(),
    };

    /// <summary>
    /// Shuffle options and update correctIndex so the correct answer position is truly random.
    /// Handles both in-memory types (List&lt;object&gt;, int) from generation
    /// and JsonElement types from HTTP deserialization (commit endpoint).
    /// </summary>
    public static void ShuffleOptions(Dictionary<string, object> q)
    {
        // Extract options as a mutable list
        List<object>? options = null;
        if (q.TryGetValue("options", out var optObj))
        {
            if (optObj is List<object> list)
                options = list;
            else if (optObj is JsonElement je && je.ValueKind == JsonValueKind.Array)
            {
                options = je.EnumerateArray().Select(ConvertJsonElement).ToList();
                q["options"] = options; // replace JsonElement with mutable list
            }
        }

        // Extract correctIndex as int
        int correctIdx = -1;
        if (q.TryGetValue("correctIndex", out var idxObj))
        {
            if (idxObj is int i) correctIdx = i;
            else if (idxObj is JsonElement je && je.ValueKind == JsonValueKind.Number)
                correctIdx = je.GetInt32();
        }

        if (options is not null && correctIdx >= 0 && correctIdx < options.Count)
        {
            var correctAnswer = options[correctIdx];
            var rng = Random.Shared;
            // Fisher-Yates shuffle
            for (int i = options.Count - 1; i > 0; i--)
            {
                int j = rng.Next(i + 1);
                (options[i], options[j]) = (options[j], options[i]);
            }
            q["correctIndex"] = options.IndexOf(correctAnswer);
        }

        // Handle sub-questions (reading comprehension)
        if (q.TryGetValue("questions", out var subObj))
        {
            List<Dictionary<string, object>>? subQuestions = null;
            if (subObj is List<object> subList)
                subQuestions = subList.OfType<Dictionary<string, object>>().ToList();
            else if (subObj is JsonElement sje && sje.ValueKind == JsonValueKind.Array)
            {
                // Deserialize sub-questions from JsonElement
                subQuestions = sje.EnumerateArray()
                    .Where(e => e.ValueKind == JsonValueKind.Object)
                    .Select(e => JsonSerializer.Deserialize<Dictionary<string, object>>(e.GetRawText())!)
                    .ToList();
                q["questions"] = subQuestions.Select(d => (object)d).ToList();
            }

            if (subQuestions is not null)
            {
                foreach (var sub in subQuestions)
                    ShuffleOptions(sub);
            }
        }
    }

    // ── Eval (LLM-as-Judge) ──

    /// <summary>
    /// Evaluate a batch of questions using GPT-4o as judge.
    /// Returns per-question verdicts: pass/fail + issues.
    /// </summary>
    public async Task<List<QuestionEvalResult>> EvalQuestionsAsync(List<Dictionary<string, object>> questions)
    {
        var client = GetChatClient();
        var questionsJson = JsonSerializer.Serialize(questions, new JsonSerializerOptions { WriteIndented = true });

        var systemPrompt = """
            你是英语考试出题质量审核员。逐题检查以下题目，对每道题给出 pass 或 fail 的判定。

            检查标准（按优先级排序）：
            1. 答案唯一性（最重要）：把每个选项逐一代入 stem，必须只有 correctIndex 指向的选项成立，其余三个都说不通。如果有任何一个干扰项也能说通，直接 fail
            2. stem 不泄露：题干中不能包含正确答案的英文原词
            3. 干扰项合理：所有选项词性一致、语法上可替换，仅语义不同
            4. 答案正确：correctIndex 指向的选项确实是该题的正确答案
            5. 格式完整：必需字段不缺失

            输出严格 JSON：{"results": [{"index": 0, "pass": true/false, "issues": ["问题描述"]}]}
            index 从 0 开始，与输入数组对应。pass 为 true 时 issues 为空数组。
            """;

        var userPrompt = $"请逐题审核以下 {questions.Count} 道题目：\n\n{questionsJson}";

        var options = new ChatCompletionOptions
        {
            Temperature = 0.1f,
            MaxOutputTokenCount = 8192,
            ResponseFormat = ChatResponseFormat.CreateJsonObjectFormat(),
        };

        var messages = new ChatMessage[]
        {
            new SystemChatMessage(systemPrompt),
            new UserChatMessage(userPrompt),
        };

        logger.LogInformation("Evaluating {Count} questions with LLM-as-Judge", questions.Count);

        var completion = await client.CompleteChatAsync(messages, options);
        var content = completion.Value.Content[0].Text;

        logger.LogInformation("Eval response: {Chars} chars, {Input}+{Output} tokens",
            content.Length,
            completion.Value.Usage.InputTokenCount,
            completion.Value.Usage.OutputTokenCount);

        var parsed = JsonSerializer.Deserialize<JsonElement>(content);
        var results = new List<QuestionEvalResult>();

        if (parsed.TryGetProperty("results", out var resultsArray)
            && resultsArray.ValueKind == JsonValueKind.Array)
        {
            foreach (var item in resultsArray.EnumerateArray())
            {
                var index = item.TryGetProperty("index", out var idx) ? idx.GetInt32() : -1;
                var pass = item.TryGetProperty("pass", out var p) && p.GetBoolean();
                var issues = new List<string>();
                if (item.TryGetProperty("issues", out var issuesArr) && issuesArr.ValueKind == JsonValueKind.Array)
                {
                    foreach (var issue in issuesArr.EnumerateArray())
                        issues.Add(issue.GetString() ?? "");
                }
                results.Add(new QuestionEvalResult(index, pass, issues));
            }
        }

        logger.LogInformation("Eval complete: {Pass}/{Total} passed",
            results.Count(r => r.Pass), results.Count);

        return results;
    }
}

public record QuestionEvalResult(int Index, bool Pass, List<string> Issues);
