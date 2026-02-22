using System.Text.Encodings.Web;
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
        var spec = GetTypeSpec(request.QuestionType, request.Level);
        var client = GetChatClient();

        logger.LogInformation(
            "Generating {Count}× {Type} for {TextbookCode} Unit {Unit}",
            spec.Count, spec.TypeName, request.TextbookCode, request.UnitNumber);

        var systemPrompt = BuildSystemPrompt(request, spec);
        var userPrompt = BuildUserPrompt(request, spec);

        logger.LogDebug("[GEN {Type}] ===== System Prompt =====\n{SystemPrompt}", spec.TypeName, systemPrompt);
        logger.LogDebug("[GEN {Type}] ===== User Prompt =====\n{UserPrompt}", spec.TypeName, userPrompt);

        var genOptions = new ChatCompletionOptions
        {
            Temperature = 0.7f,
            MaxOutputTokenCount = 16384,
            ResponseFormat = ChatResponseFormat.CreateJsonObjectFormat(),
        };

        // ── Multi-turn chat: gen → eval → fix all in one conversation ──
        var chatHistory = new List<ChatMessage>
        {
            new SystemChatMessage(systemPrompt),
            new UserChatMessage(userPrompt),
        };

        // ── Turn 1: Generate ──
        var completion = await client.CompleteChatAsync(chatHistory, genOptions);
        var content = completion.Value.Content[0].Text;
        var finishReason = completion.Value.FinishReason;

        logger.LogDebug("[GEN {Type}] ===== Raw Response =====\n{Content}", spec.TypeName, content);

        logger.LogInformation(
            "GPT-4o [{Type}]: {Chars} chars, finish={Reason}, usage: {Input}+{Output} tokens",
            spec.TypeName, content.Length, finishReason,
            completion.Value.Usage.InputTokenCount,
            completion.Value.Usage.OutputTokenCount);

        if (finishReason == ChatFinishReason.Length)
        {
            logger.LogWarning("GPT-4o output TRUNCATED for {Type}. Questions may be incomplete.", spec.TypeName);
        }

        chatHistory.Add(new AssistantChatMessage(content));
        var questions = ParseQuestionsFromJson(content, request);

        if (questions.Count == 0)
        {
            logger.LogWarning("No questions parsed from GPT response for {Type}", spec.TypeName);
            return questions;
        }

        // ── Turn 2: Eval (in same chat) ──
        var evalSystemPrompt = BuildEvalSystemPrompt(spec.TypeName, request.Level);

        var evalOptions = new ChatCompletionOptions
        {
            Temperature = 0.1f,
            MaxOutputTokenCount = 8192,
            ResponseFormat = ChatResponseFormat.CreateJsonObjectFormat(),
        };

        var questionsJson = JsonSerializer.Serialize(questions, LogJsonOpts);
        var evalPrompt = $$"""
            现在请你切换为严格的质检员角色，逐条审核你刚才生成的 {{questions.Count}} 道题目。
            不要因为是自己生成的就放水，必须严格按规则逐项检查。

            === 审核规则 ===
            {{evalSystemPrompt}}

            === 待审核题目 ===
            {{questionsJson}}

            === 审核要求 ===
            1. 每道题逐条过规则，有问题就写进 issues
            2. 阅读理解：必须逐个子题检查（答案、干扰项、explanation 语言），issues 中标明子题编号
            3. explanation 语言检查（最容易遗漏的错误！）：
               - 逐个读一遍每道题/每个子题的 explanation 字段
               - 如果 explanation 是英文句子 → 立即 fail（G3），写入 issues
               - 正确的 explanation 应该像这样："文中提到 Tom 说了 'Hello'，所以选 A"
               - 错误的 explanation 像这样："Tom says 'Hello' in the text, so the answer is A"
            4. pass=true 仅当所有规则都通过

            输出 JSON：{"results": [{"index": 0, "pass": true/false, "issues": ["规则编号: 具体问题..."]}]}
            """;

        chatHistory.Add(new UserChatMessage(evalPrompt));

        logger.LogInformation("Auto-eval for {Type}: {Count} questions", spec.TypeName, questions.Count);

        var evalCompletion = await client.CompleteChatAsync(chatHistory, evalOptions);
        var evalContent = evalCompletion.Value.Content[0].Text;

        chatHistory.Add(new AssistantChatMessage(evalContent));

        logger.LogDebug("[EVAL {Type}] ===== Eval Response =====\n{Content}", spec.TypeName, evalContent);
        logger.LogInformation("Eval [{Type}]: {Chars} chars, {Input}+{Output} tokens",
            spec.TypeName, evalContent.Length,
            evalCompletion.Value.Usage.InputTokenCount,
            evalCompletion.Value.Usage.OutputTokenCount);

        var evalResults = ParseEvalResults(evalContent);
        var failed = evalResults.Where(r => !r.Pass).ToList();

        foreach (var r in evalResults)
        {
            if (r.Pass)
                logger.LogDebug("[AUTO-EVAL {Type}] Q#{Index} ✅ PASS", spec.TypeName, r.Index);
            else
                logger.LogDebug("[AUTO-EVAL {Type}] Q#{Index} ❌ FAIL: {Issues}",
                    spec.TypeName, r.Index, string.Join(" | ", r.Issues));
        }

        if (failed.Count == 0)
        {
            logger.LogInformation("Auto-eval: all {Count} {Type} passed ✅", questions.Count, spec.TypeName);
        }
        else
        {
            // ── Turn 3: Fix failed questions (in same chat) ──
            var failedIndices = failed.Select(f => f.Index).ToHashSet();
            var failedDetails = failed
                .Where(f => f.Index >= 0 && f.Index < questions.Count)
                .Select(f => new { index = f.Index, question = questions[f.Index], issues = f.Issues })
                .ToList();
            var passedQuestions = questions.Where((_, i) => !failedIndices.Contains(i)).ToList();

            logger.LogInformation("Auto-eval: {Failed}/{Total} {Type} failed, requesting fix",
                failed.Count, questions.Count, spec.TypeName);

            if (failedDetails.Count > 0)
            {
                var evalRules = GetEvalRulesForType(spec.TypeName);
                var failedJson = JsonSerializer.Serialize(
                    failedDetails.Select(f => new { f.question, f.issues }), LogJsonOpts);

                logger.LogDebug("[FIX {Type}] ===== Failed Questions =====\n{FailedJson}",
                    spec.TypeName, failedJson);

                var fixPrompt = $$"""
                    以上 {{failedDetails.Count}} 道题未通过质检，请根据问题修复并重新输出。
                    保持原有题型和字段格式不变，只修正质检指出的问题。

                    === 质检规则说明 ===
                    {{evalRules}}

                    === 未通过的题目 ===
                    {{failedJson}}

                    请输出修复后的题目，JSON 格式：{"questions": [...]}
                    只输出修复后的题目，不要输出已通过的。
                    """;

                chatHistory.Add(new UserChatMessage(fixPrompt));

                var fixCompletion = await client.CompleteChatAsync(chatHistory, genOptions);
                var fixContent = fixCompletion.Value.Content[0].Text;

                logger.LogDebug("[FIX {Type}] ===== Fix Response =====\n{FixContent}",
                    spec.TypeName, fixContent);
                logger.LogInformation("Fix [{Type}]: {Chars} chars, {Input}+{Output} tokens",
                    spec.TypeName, fixContent.Length,
                    fixCompletion.Value.Usage.InputTokenCount,
                    fixCompletion.Value.Usage.OutputTokenCount);

                var fixedQuestions = ParseQuestionsFromJson(fixContent, request);
                questions = [.. passedQuestions, .. fixedQuestions];
            }
            else
            {
                questions = passedQuestions;
            }
        }

        logger.LogInformation("Final: {Count} {Type} questions after auto-eval",
            questions.Count, spec.TypeName);

        return questions;
    }

    /// <summary>
    /// Parse GPT JSON response into a list of question dictionaries, adding metadata fields.
    /// </summary>
    private static List<Dictionary<string, object>> ParseQuestionsFromJson(
        string json, GenerateQuestionsRequest request)
    {
        var result = new List<Dictionary<string, object>>();
        var parsed = JsonSerializer.Deserialize<JsonElement>(json);
        if (parsed.TryGetProperty("questions", out var questionsArray)
            && questionsArray.ValueKind == JsonValueKind.Array)
        {
            foreach (var item in questionsArray.EnumerateArray())
            {
                var dict = JsonElementToDict(item);
                dict.TryAdd("id", Guid.NewGuid().ToString());
                dict.TryAdd("textbookCode", request.TextbookCode);
                dict.TryAdd("unitNumber", request.UnitNumber);
                dict.TryAdd("level", request.Level);
                dict.TryAdd("generatedBy", "gpt-4o");
                dict.TryAdd("generatedAt", DateTime.UtcNow.ToString("o"));
                result.Add(dict);
            }
        }
        return result;
    }

    // ── Type specs & prompt builders ──

    private record TypeSpec(string TypeName, string ChineseName, int Count, string FieldSpec);

    private static TypeSpec GetTypeSpec(string questionType, string level) => questionType switch
    {
        "vocabulary" => new("vocabulary", "词汇选择题", 15, """
            JSON 字段: id, questionType("vocabulary"), word, phonetic, meaning, stem, translation,
              options(4个选项), correctIndex(0-based), exampleSentence, exampleTranslation,
              explanation, category("meaning"/"spelling"/"form"/"synonym")
            - category 要均匀分布
            """),
        "cloze" => new("cloze", "填空题", 10, """
            JSON 字段: id, questionType("cloze"), sentence(用___标记空白), translation,
              correctAnswer, hints(提示数组), explanation
            """),
        "grammar" => new("grammar", "语法选择题", 8, """
            JSON 字段: id, questionType("grammar"), stem, translation,
              options(4个选项), correctIndex(0-based), grammarPoint, grammarPointTranslation,
              explanation
            """),
        "multipleChoice" => new("multipleChoice", "综合选择题", 10, """
            JSON 字段: id, questionType("multipleChoice"), stem, translation,
              options(4个选项), correctIndex(0-based), explanation
            """),
        "errorCorrection" => new("errorCorrection", "纠错题", 5, """
            JSON 字段: id, questionType("errorCorrection"), sentence, translation,
              errorRange(错误部分的文本), correction(正确写法),
              explanation
            """),
        "translation" => new("translation", "翻译题", 6, """
            JSON 字段: id, questionType("translation"), sourceText, direction("enToZh"或"zhToEn"),
              referenceAnswer, keywords(关键词数组), explanation
            - 中译英和英译中各占一半
            """),
        "rewriting" => new("rewriting", "句型改写题", 5, """
            JSON 字段: id, questionType("rewriting"), originalSentence,
              instruction, instructionTranslation, referenceAnswer, referenceTranslation,
              explanation
            """),
        "sentenceOrdering" => new("sentenceOrdering", "排序题", 5, """
            JSON 字段: id, questionType("sentenceOrdering"), shuffledParts(打乱的单词/短语数组),
              correctOrder(正确顺序的索引数组), correctSentence, translation,
              explanation
            - 自查：shuffledParts[correctOrder[0]] + " " + shuffledParts[correctOrder[1]] + ... 必须恰好等于 correctSentence
            """),
        "reading" => new("reading", "阅读理解", 1, $"""
            JSON 字段: id, questionType("reading"), title, content(短文内容),
              questions(子题数组, 每个子题包含: stem, options(4个), correctIndex,
                explanation(中文解析，用中文写，可穿插英文单词))
            
            ⚠️ 子题 explanation 必须用中文写（可穿插英文单词），绝对不能用英文写！
            
            篇幅要求（当前学段: "{level}"）：
            - 小学一~三年级：60-100 词，简单句为主，贴近日常生活场景
            - 小学四~六年级：100-160 词，可包含复合句，话题稍广
            - 初中：160-260 词，包含一定比例从句和过渡词，内容有逻辑层次
            - 高中及以上：260-400 词，语篇结构完整，涵盖议论/说明/叙事等多种文体

            内容要求：
            - 短文必须是一篇完整、连贯的文章（叙事/说明/对话/书信等），不能是几个孤立的句子
            - 必须使用本单元词汇和句型，但融入自然语境中
            - 标题简洁概括主题
            - 只生成 1 篇阅读理解，配 5-6 个子题
            - 子题类型多样化（细节理解、主旨概括、词义猜测、推理判断等）
            """),
        "listening" => new("listening", "听力题", 6, """
            JSON 字段: id, questionType("listening"), transcript, transcriptTranslation,
              stem, stemTranslation, options(4个选项), correctIndex(0-based),
              explanation
            - 不需要 audioURL，后期由 TTS 生成
            """),
        "speaking" => new("speaking", "口语题", 6, """
            JSON 字段: id, questionType("speaking"), prompt, referenceText, translation,
              category("readAloud"/"translateSpeak"/"listenRepeat"/"completeSpeak")
            - readAloud: prompt 提示朗读, referenceText 为英文句子
            - translateSpeak: prompt 提示翻译, referenceText 为英文, translation 为中文题干
            - listenRepeat: prompt 提示跟读, referenceText 为英文句子
            - completeSpeak: prompt 中含 ___ 空白, referenceText 为完整句子
            - category 要均匀分布
            """),
        _ => throw new ArgumentException($"Unknown question type: {questionType}")
    };

    private static string BuildSystemPrompt(GenerateQuestionsRequest request, TypeSpec spec)
    {
        return $$"""
            你是一个经验丰富、极其严谨的英语教育出题专家。每道题都必须经过反复验证才能输出，绝不允许出现答案错误、多个正确选项、或数据不一致的情况。
            
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

    /// JSON options for log output: UTF-8 Chinese, indented
    private static readonly JsonSerializerOptions LogJsonOpts = new()
    {
        WriteIndented = true,
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    };

    /// Eval rules summary for inclusion in fix prompts so the fixer LLM knows what the codes mean
    private static string GetEvalRulesForType(string questionType) => questionType switch
    {
        "vocabulary" or "grammar" or "multipleChoice" or "cloze" or "listening" or "errorCorrection" =>
            """
            G1=格式完整  G2=翻译准确  G3=解析质量  G4=拼写标点
            A1=答案唯一性(逐一把选项代入stem,只有correctIndex成立)  A2=stem不泄露答案
            A3=干扰项词性一致,仅语义不同  A4=correctIndex正确
            """,
        "reading" =>
            """
            G1=格式完整  G2=翻译准确  G3=解析质量  G4=拼写标点
            B1=子题答案正确(根据文章,correctIndex是唯一正确答案)
            B2=干扰项根据文章不成立  B3=短文完整连贯  B4=子题类型多样
            注意:答案在原文中能找到是正常的(细节理解题),低年级题目简单也是正常的
            """,
        "translation" or "rewriting" or "speaking" =>
            """
            G1=格式完整  G2=翻译准确  G3=解析质量  G4=拼写标点
            C1=prompt清晰  C2=referenceAnswer正确  C3=翻译准确
            """,
        "sentenceOrdering" =>
            """
            G1=格式完整  G2=翻译准确  G3=解析质量  G4=拼写标点
            D1=shuffledParts[correctOrder[i]]拼接必须等于correctSentence  D2=拆分粒度合理
            """,
        _ => "G1=格式完整  G2=翻译准确  G3=解析质量  G4=拼写标点"
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
    /// Per-type eval prompt builder. Each question type gets its own focused rules
    /// so the judge LLM never applies the wrong criteria.
    /// </summary>
    private static string BuildEvalSystemPrompt(string questionType, string level)
    {
        var header = $$"""
            # 角色
            你是一位严格但合理的英语考试出题质量审核员。
            当前审核的题目面向「{{level}}」学生，请据此合理调整期望（低年级题目理应简单）。

            # 通用检查（任一不满足即 fail）
            G1. 格式完整：必需字段不缺失，id / questionType 等必须存在
            G2. 翻译准确：中文翻译（如有）必须准确对应英文内容
            G3. 解析质量：explanation 必须用中文写，清晰说明解题思路，可穿插英文单词
            G4. 拼写与标点：英文拼写、标点、大小写必须正确，不含乱码或控制字符

            """;

        var typeRules = questionType switch
        {
            "vocabulary" or "grammar" or "multipleChoice" or "cloze" or "listening" or "errorCorrection" => """
                # 选择题专项检查
                A1. 答案唯一性（最重要）：逐一把每个选项代入 stem，必须只有 correctIndex 选项成立，其余都说不通。任一干扰项也能说通 → fail
                A2. stem 不泄露答案：题干不能包含正确答案的英文原词
                A3. 干扰项质量：所有选项词性一致、语法可替换，仅在语义上错误
                A4. correctIndex 正确：指向的选项确实是唯一正确答案
                A5. explanation 禁引字母：explanation 中不能出现“答案是 A/B/C/D”或“选 A/B/C/D”，因为选项顺序后期会被打乱。只需解释为什么正确答案是对的
                """,

            "reading" => """
                # 阅读理解专项检查（不要套用选择题的 A 类规则）
                你必须逐个子题检查，不能笼统说"全部通过"。

                ## 逐子题必查项（每个子题都要过一遍）
                B1. 答案正确性：根据短文内容，correctIndex 指向的选项是否是唯一正确/最佳答案？如果有多个选项都能成立 → fail
                B2. 干扰项合理性：其他三个选项根据短文是否明确不成立？如有干扰项也能成立 → fail
                B5. explanation 语言：explanation 是否用中文写的？如果是英文 → 立即 fail（G3）
                B6. explanation 禁引字母：explanation 中不能出现“答案是 A/B/C/D”或“选 A/B/C/D”，因为选项顺序会被打乱。只需解释为什么正确答案是对的 → 如有 fail

                ## 整体检查
                B3. 短文质量：文章完整连贯，有情节或信息主线，不能是孤立句子拼凑
                B4. 子题多样性：不能全是直接查找题（如全部都是"文中提到了什么"），应包含推理、主旨、词义猜测等不同层次

                ## 审核态度（阅读理解专属）
                - 阅读理解考查的就是对文章的理解，答案自然来自文章，这是正常的
                - 「答案可以在原文中找到」≠ 错误，这是「细节理解题」的正常形式
                - 不要因为题目"简单"就 fail —— 低年级题目本应简单
                - fail 的情况：答案错误、多个正确选项、explanation 是英文、文章不连贯、子题全部雷同

                ## issues 格式
                issues 中请注明是哪个子题出了问题，例如 "B5-Q3: explanation 是英文，应改为中文"

                ## 输出格式（阅读理解专属，覆盖通用格式）
                阅读理解必须输出 subChecks 数组，展示每个子题的检查结果：
                {"results": [{"index": 0, "pass": true/false, "issues": [...], "subChecks": [{"q": 0, "pass": true, "note": "答案正确，explanation中文"}, {"q": 1, "pass": false, "note": "B5: explanation是英文"}]}]}
                subChecks 中 q 从 0 开始，note 简要说明检查结论。任一子题 pass=false → 整题 pass=false。
                """,

            "translation" or "rewriting" or "speaking" => """
                # 开放题专项检查
                C1. prompt 清晰：题目要求明确，学生能理解要做什么
                C2. referenceAnswer 正确：参考答案语法正确、语义准确
                C3. 翻译准确：prompt / referenceAnswer 的中英文对应正确
                C4. 不审查：不要评判字数限制合理性、答案多样性、表述灵活度
                """,

            "sentenceOrdering" => """
                # 排序题专项检查
                D1. 数据一致性（最重要）：shuffledParts[correctOrder[0]] + " " + shuffledParts[correctOrder[1]] + ... 拼接结果必须恰好等于 correctSentence，不等 → 立即 fail
                D2. 难度合理：拆分粒度适中，不能太碎（单个字母）也不能太少（两段）
                """,

            _ => """
                # 通用检查
                请根据 questionType 和字段判断：答案是否正确、数据是否一致、格式是否完整。
                """
        };

        var footer = """

            # 审核态度
            - 重点审查：答案正确性、数据一致性、格式完整性
            - 不要过度审查难度（难度由学段决定，不是审核重点）
            - issues 中写清楚具体问题和违反的规则编号（如 B1、D1）

            # 输出格式
            严格 JSON：{"results": [{"index": 0, "pass": true/false, "issues": ["B1: 具体问题..."]}]}
            index 从 0 开始，与输入数组对应。pass=true 时 issues 为空数组。
            """;

        return header + typeRules + footer;
    }

    /// <summary>
    /// Evaluate a batch of same-type questions using GPT-4o as judge.
    /// Called by auto-eval loop (single type) or by manual eval (per-group).
    /// </summary>
    public async Task<List<QuestionEvalResult>> EvalQuestionsAsync(
        List<Dictionary<string, object>> questions, string questionType)
    {
        var client = GetChatClient();
        var questionsJson = JsonSerializer.Serialize(questions, LogJsonOpts);

        // Detect level from first question
        var level = "";
        if (questions.Count > 0 && questions[0].TryGetValue("level", out var lvlObj))
            level = lvlObj?.ToString() ?? "";

        var systemPrompt = BuildEvalSystemPrompt(questionType, level);

        var userPrompt = $"请逐题审核以下 {questions.Count} 道 {questionType} 题目：\n\n{questionsJson}";

        logger.LogDebug("[EVAL {Type}] ===== Eval Request ({Count} questions) =====\n{QuestionsJson}",
            questionType, questions.Count, questionsJson);

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

        logger.LogInformation("Evaluating {Count}× {Type} with LLM-as-Judge", questions.Count, questionType);

        var completion = await client.CompleteChatAsync(messages, options);
        var content = completion.Value.Content[0].Text;

        logger.LogDebug("[EVAL {Type}] ===== Eval Raw Response =====\n{Content}", questionType, content);

        logger.LogInformation("Eval [{Type}]: {Chars} chars, {Input}+{Output} tokens",
            questionType, content.Length,
            completion.Value.Usage.InputTokenCount,
            completion.Value.Usage.OutputTokenCount);

        var results = ParseEvalResults(content);

        logger.LogInformation("Eval [{Type}]: {Pass}/{Total} passed",
            questionType, results.Count(r => r.Pass), results.Count);

        return results;
    }

    /// <summary>
    /// Parse the JSON eval results from the LLM judge response.
    /// </summary>
    private static List<QuestionEvalResult> ParseEvalResults(string content)
    {
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

        return results;
    }
}

public record QuestionEvalResult(int Index, bool Pass, List<string> Issues);
