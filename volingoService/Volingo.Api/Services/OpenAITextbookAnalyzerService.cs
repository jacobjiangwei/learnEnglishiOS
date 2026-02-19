using System.Text.Json;
using Azure;
using Azure.AI.OpenAI;
using OpenAI.Chat;
using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// GPT-4o textbook content analyzer — reads rawContent, produces structured JSON
/// with units, vocabulary, grammar, sentence patterns, songs, etc.
/// </summary>
public class OpenAITextbookAnalyzerService(IConfiguration config, ILogger<OpenAITextbookAnalyzerService> logger)
    : ITextbookAnalyzerService
{
    private const string SystemPrompt = """
        你是一位专业的英语教材分析专家。你的任务是从教材的 OCR 提取文本中，精确地提取并整理每个单元的知识点。

        请严格按照以下 JSON schema 输出，不要输出任何其他内容（不要 markdown 代码块包裹）:

        {
          "bookInfo": {
            "title": "教材完整标题",
            "publisher": "出版社",
            "grade": "年级",
            "semester": "上册/下册",
            "startingPoint": "三年级起点 / 一年级起点 (如适用)",
            "characters": ["教材中出现的角色名"]
          },
          "units": [
            {
              "unitNumber": 0,
              "unitTitle": "Starter / Unit X Title",
              "topic": "本单元的主题（中文描述）",
              "vocabulary": [
                {"word": "英文单词", "meaning": "中文释义", "type": "noun/verb/adj/num/pron/other"}
              ],
              "sentencePatterns": [
                {"pattern": "I have a ___.", "usage": "表示拥有某物"}
              ],
              "grammar": [
                "语法点的中文描述"
              ],
              "songs": [
                {"title": "歌曲/歌谣名称", "type": "chant/song", "firstLine": "歌词第一句"}
              ],
              "commands": ["课堂指令，如 Stand up!"],
              "storyTitle": "Story Time 标题或主题",
              "storySummary": "用1-2句中文概括故事内容"
            }
          ],
          "vocabularyGlossary": [
            {"word": "apple", "meaning": "苹果", "type": "noun", "unitFirst": 6}
          ]
        }

        规则:
        1. unitNumber=0 用于 Starter 部分（如有）
        2. Revision 部分不作为独立 unit，可忽略
        3. vocabulary 只列出本单元的核心生词（非附录中的完整词汇表）
        4. sentencePatterns 只列出本单元的核心句型
        5. grammar 用中文简洁描述语法要点，面向中国学生
        6. 附录中的歌谣和歌曲列表可辅助 songs 字段的提取
        7. 附录中的"单元词汇表"和"总词汇表"可辅助 vocabulary 的中文释义
        8. 附录中的"常用语表"可辅助 commands 字段
        9. 确保每个单元都被完整提取，不要遗漏
        10. type 字段: noun=名词, verb=动词, adj=形容词, num=数词, pron=代词, other=其他
        11. vocabularyGlossary 是整本书的完整词汇总表（参考教材附录"词汇表"），按字母排序
        12. vocabularyGlossary 中的 unitFirst 表示该词首次出现的单元编号
        13. vocabularyGlossary 应包含附录词汇表中的所有单词
        """;

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

    public async Task<TextbookAnalysis> AnalyzeAsync(string rawContent, string displayName)
    {
        var client = GetChatClient();

        var userPrompt = $"""
            请分析以下教材内容，提取每个单元的知识点。

            教材: {displayName}

            --- 教材原文 (OCR 提取) ---
            {rawContent}
            --- 原文结束 ---

            请按照 system prompt 中的 JSON schema 输出结构化分析结果。
            """;

        logger.LogInformation("Analyzing textbook: {DisplayName} ({Chars} chars)", displayName, rawContent.Length);

        var options = new ChatCompletionOptions
        {
            Temperature = 0.1f,
            MaxOutputTokenCount = 16000,
            ResponseFormat = ChatResponseFormat.CreateJsonObjectFormat(),
        };

        var messages = new ChatMessage[]
        {
            new SystemChatMessage(SystemPrompt),
            new UserChatMessage(userPrompt),
        };

        var completion = await client.CompleteChatAsync(messages, options);
        var content = completion.Value.Content[0].Text;

        logger.LogInformation("GPT-4o response: {Chars} chars, usage: {Input}+{Output} tokens",
            content.Length,
            completion.Value.Usage.InputTokenCount,
            completion.Value.Usage.OutputTokenCount);

        var result = JsonSerializer.Deserialize<TextbookAnalysis>(content, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true,
        }) ?? throw new InvalidOperationException("GPT-4o returned invalid JSON.");

        return result;
    }
}
