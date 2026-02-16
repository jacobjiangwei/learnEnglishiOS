using System.Text;
using System.Text.Json;
using Microsoft.Azure.Cosmos;

namespace Volingo.Api.Services;

/// <summary>
/// Seeds the "questions" container on first startup if empty.
/// Reuses the same sample question data that was previously in MockDataService.
/// </summary>
public static class QuestionSeeder
{
    private static readonly string[] TextbookCodes =
    [
        "juniorPEP-7a", "juniorPEP-7b", "juniorPEP-8a",
        "primaryPEP-3a", "primaryPEP-3b", "primaryPEP-4a", "primaryPEP-4b",
        "primaryPEP-5a", "primaryPEP-5b", "primaryPEP-6a", "primaryPEP-6b",
        "seniorPEP-1a", "seniorPEP-1b", "seniorPEP-2a"
    ];

    /// <summary>
    /// Seed questions into the container if it is empty.
    /// </summary>
    public static async Task SeedAsync(Container container, ILogger logger)
    {
        // Quick check — if any document exists, skip seeding
        var probe = container.GetItemQueryIterator<object>(
            new QueryDefinition("SELECT TOP 1 c.id FROM c"),
            requestOptions: new QueryRequestOptions { MaxItemCount = 1 });

        if (probe.HasMoreResults)
        {
            var page = await probe.ReadNextAsync();
            if (page.Count > 0)
            {
                logger.LogInformation("Questions container already seeded — skipping.");
                return;
            }
        }

        logger.LogInformation("Seeding questions container...");

        // Group all questions per partition key and upsert in parallel (per partition)
        var allQuestions = TextbookCodes
            .SelectMany(code => BuildQuestionsForTextbook(code).Select(q => (code, q)))
            .ToList();

        int total = allQuestions.Count;
        int done = 0;

        // Parallel within each partition key (safe for Cosmos), max 10 concurrent
        await Parallel.ForEachAsync(
            allQuestions,
            new ParallelOptions { MaxDegreeOfParallelism = 10 },
            async (item, ct) =>
            {
                var json = JsonSerializer.Serialize(item.q);
                using var stream = new MemoryStream(Encoding.UTF8.GetBytes(json));
                await container.UpsertItemStreamAsync(stream, new PartitionKey(item.code));
                Interlocked.Increment(ref done);
            });

        logger.LogInformation("✅ Seeded {Count} questions across {Textbooks} textbooks.", total, TextbookCodes.Length);
    }

    // ──────────────────────────────────────────────────
    //  Question generators (same data as old MockDataService)
    // ──────────────────────────────────────────────────

    private static List<Dictionary<string, object>> BuildQuestionsForTextbook(string code)
    {
        var all = new List<Dictionary<string, object>>();
        all.AddRange(GenerateMCQ(code, 20));
        all.AddRange(GenerateCloze(code, 10));
        all.AddRange(GenerateReading(code, 5));
        all.AddRange(GenerateTranslation(code, 8));
        all.AddRange(GenerateRewriting(code, 6));
        all.AddRange(GenerateErrorCorrection(code, 6));
        all.AddRange(GenerateOrdering(code, 6));
        all.AddRange(GenerateListening(code, 8));
        all.AddRange(GenerateSpeaking(code, 6));
        all.AddRange(GenerateWriting(code, 4));
        all.AddRange(GenerateVocabulary(code, 10));
        all.AddRange(GenerateGrammar(code, 8));
        return all;
    }

    private static List<Dictionary<string, object>> GenerateMCQ(string textbookCode, int count)
    {
        var stems = new (string Stem, string Translation, string[] Options, int Correct)[]
        {
            ("What is the capital of the UK?", "英国的首都是什么？", ["Paris", "London", "Berlin", "Madrid"], 1),
            ("Which word means 'happy'?", "\u201c快乐的\u201d是哪个词？", ["sad", "angry", "joyful", "tired"], 2),
            ("She ___ to school every day.", "她每天___去学校。", ["go", "goes", "going", "went"], 1),
            ("The opposite of 'hot' is ___.", "\u201c热\u201d的反义词是___。", ["warm", "cool", "cold", "freezing"], 2),
            ("I have ___ apple.", "我有___苹果。", ["a", "an", "the", "some"], 1),
        };

        return Enumerable.Range(0, count).Select(i =>
        {
            var (stem, translation, options, correct) = stems[i % stems.Length];
            return new Dictionary<string, object>
            {
                ["id"] = Guid.NewGuid().ToString(),
                ["questionType"] = "multipleChoice",
                ["textbookCode"] = textbookCode,
                ["stem"] = $"{stem} (#{i + 1})",
                ["translation"] = translation,
                ["options"] = options,
                ["correctIndex"] = correct,
                ["explanation"] = "This is the correct answer based on grammar rules.",
                ["explanationTranslation"] = "根据语法规则，这是正确答案。"
            };
        }).ToList();
    }

    private static List<Dictionary<string, object>> GenerateCloze(string textbookCode, int count)
    {
        var items = new (string Sentence, string Translation, string Answer, string[] Hints)[]
        {
            ("I have ___ been to Beijing.", "我___去过北京。", "already", ["already", "yet", "still", "never"]),
            ("She is good ___ singing.", "她擅长___唱歌。", "at", ["at", "in", "on", "for"]),
            ("They ___ playing football now.", "他们现在正在踢足球。", "are", ["are", "is", "was", "were"]),
        };

        return Enumerable.Range(0, count).Select(i =>
        {
            var (sentence, translation, answer, hints) = items[i % items.Length];
            return new Dictionary<string, object>
            {
                ["id"] = Guid.NewGuid().ToString(),
                ["questionType"] = "cloze",
                ["textbookCode"] = textbookCode,
                ["sentence"] = $"{sentence} (#{i + 1})",
                ["translation"] = translation,
                ["correctAnswer"] = answer,
                ["hints"] = hints,
                ["explanation"] = $"The correct word is '{answer}'.",
                ["explanationTranslation"] = $"正确答案是 '{answer}'。"
            };
        }).ToList();
    }

    private static List<Dictionary<string, object>> GenerateReading(string textbookCode, int count)
    {
        return Enumerable.Range(0, count).Select(i => new Dictionary<string, object>
        {
            ["id"] = Guid.NewGuid().ToString(),
            ["questionType"] = "reading",
            ["textbookCode"] = textbookCode,
            ["title"] = $"A Day at School #{i + 1}",
            ["content"] = "Tom gets up at seven o'clock every morning. He has breakfast and then goes to school by bus. He likes English and math. After school, he plays basketball with his friends.",
            ["translation"] = "汤姆每天早上七点起床。他吃完早餐后坐公交去学校。他喜欢英语和数学。放学后，他和朋友们打篮球。",
            ["questions"] = new List<Dictionary<string, object>>
            {
                new()
                {
                    ["id"] = Guid.NewGuid().ToString(),
                    ["stem"] = "What time does Tom get up?",
                    ["translation"] = "汤姆几点起床？",
                    ["options"] = new[] { "Six o'clock", "Seven o'clock", "Eight o'clock", "Nine o'clock" },
                    ["correctIndex"] = 1,
                    ["explanation"] = "The passage says 'Tom gets up at seven o'clock every morning.'"
                },
                new()
                {
                    ["id"] = Guid.NewGuid().ToString(),
                    ["stem"] = "How does Tom go to school?",
                    ["translation"] = "汤姆怎么去学校？",
                    ["options"] = new[] { "By bike", "By bus", "On foot", "By car" },
                    ["correctIndex"] = 1,
                    ["explanation"] = "The passage says 'goes to school by bus.'"
                }
            }
        }).ToList();
    }

    private static List<Dictionary<string, object>> GenerateTranslation(string textbookCode, int count)
    {
        var items = new[]
        {
            ("I want to be a teacher when I grow up.", "我长大后想当一名老师。"),
            ("Can you help me with my homework?", "你能帮我做作业吗？"),
            ("The weather is very nice today.", "今天天气很好。"),
        };

        return Enumerable.Range(0, count).Select(i =>
        {
            var (source, reference) = items[i % items.Length];
            return new Dictionary<string, object>
            {
                ["id"] = Guid.NewGuid().ToString(),
                ["questionType"] = "translation",
                ["textbookCode"] = textbookCode,
                ["sourceText"] = $"{source} (#{i + 1})",
                ["direction"] = "enToZh",
                ["referenceAnswer"] = reference,
                ["keywords"] = new[] { "teacher", "homework", "weather" },
                ["explanation"] = "Pay attention to the key vocabulary and sentence structure.",
                ["explanationTranslation"] = "注意关键词汇和句型结构。"
            };
        }).ToList();
    }

    private static List<Dictionary<string, object>> GenerateRewriting(string textbookCode, int count)
    {
        return Enumerable.Range(0, count).Select(i => new Dictionary<string, object>
        {
            ["id"] = Guid.NewGuid().ToString(),
            ["questionType"] = "rewriting",
            ["textbookCode"] = textbookCode,
            ["originalSentence"] = $"He goes to school by bus. (#{i + 1})",
            ["originalTranslation"] = "他坐公交去学校。",
            ["instruction"] = "Change to a question.",
            ["instructionTranslation"] = "改为疑问句。",
            ["referenceAnswer"] = "Does he go to school by bus?",
            ["referenceTranslation"] = "他坐公交去学校吗？",
            ["explanation"] = "To form a yes/no question with 'goes', use 'Does he go...?'",
            ["explanationTranslation"] = "要将含有 'goes' 的陈述句变为一般疑问句，使用 'Does he go...?'"
        }).ToList();
    }

    private static List<Dictionary<string, object>> GenerateErrorCorrection(string textbookCode, int count)
    {
        return Enumerable.Range(0, count).Select(i => new Dictionary<string, object>
        {
            ["id"] = Guid.NewGuid().ToString(),
            ["questionType"] = "errorCorrection",
            ["textbookCode"] = textbookCode,
            ["sentence"] = $"She don't like apples. (#{i + 1})",
            ["translation"] = "她不喜欢苹果。",
            ["errorRange"] = "don't",
            ["correction"] = "doesn't",
            ["explanation"] = "Third person singular uses 'doesn't'.",
            ["explanationTranslation"] = "第三人称单数用 'doesn't'。"
        }).ToList();
    }

    private static List<Dictionary<string, object>> GenerateOrdering(string textbookCode, int count)
    {
        return Enumerable.Range(0, count).Select(i => new Dictionary<string, object>
        {
            ["id"] = Guid.NewGuid().ToString(),
            ["questionType"] = "sentenceOrdering",
            ["textbookCode"] = textbookCode,
            ["shuffledParts"] = new[] { "school", "I", "to", "go", "every day" },
            ["correctOrder"] = new[] { 1, 3, 2, 0, 4 },
            ["correctSentence"] = $"I go to school every day. (#{i + 1})",
            ["translation"] = "我每天去上学。",
            ["explanation"] = "The correct order forms: I go to school every day.",
            ["explanationTranslation"] = "正确的语序是：I go to school every day."
        }).ToList();
    }

    private static List<Dictionary<string, object>> GenerateListening(string textbookCode, int count)
    {
        return Enumerable.Range(0, count).Select(i => new Dictionary<string, object>
        {
            ["id"] = Guid.NewGuid().ToString(),
            ["questionType"] = "listening",
            ["textbookCode"] = textbookCode,
            ["audioURL"] = $"https://mock-audio.volingo.app/listen-{i:D3}.mp3",
            ["transcript"] = $"Good morning! How are you today? (#{i + 1})",
            ["transcriptTranslation"] = "早上好！你今天怎么样？",
            ["stem"] = "What does the speaker say?",
            ["stemTranslation"] = "说话人说了什么？",
            ["options"] = new[] { "Good morning", "Good evening", "Good night", "Goodbye" },
            ["correctIndex"] = 0,
            ["explanation"] = "The speaker greets with 'Good morning'.",
            ["explanationTranslation"] = "说话人用 'Good morning' 打招呼。"
        }).ToList();
    }

    private static List<Dictionary<string, object>> GenerateVocabulary(string textbookCode, int count)
    {
        var words = new[]
        {
            ("achieve", "实现；达到", "She worked hard to achieve her goals.", "她努力工作以实现她的目标。"),
            ("brilliant", "杰出的；明亮的", "He is a brilliant student.", "他是一个杰出的学生。"),
            ("confident", "自信的", "She feels confident about the exam.", "她对考试感到自信。"),
        };

        return Enumerable.Range(0, count).Select(i =>
        {
            var (word, meaning, example, exampleTrans) = words[i % words.Length];
            return new Dictionary<string, object>
            {
                ["id"] = Guid.NewGuid().ToString(),
                ["questionType"] = "vocabulary",
                ["textbookCode"] = textbookCode,
                ["word"] = word,
                ["phonetic"] = "/əˈtʃiːv/",
                ["meaning"] = meaning,
                ["stem"] = $"Choose the correct meaning of '{word}'. (#{i + 1})",
                ["translation"] = $"选择 '{word}' 的正确含义。",
                ["options"] = new[] { meaning, "放弃", "忽视", "破坏" },
                ["correctIndex"] = 0,
                ["exampleSentence"] = example,
                ["exampleTranslation"] = exampleTrans,
                ["explanation"] = $"'{word}' means '{meaning}'.",
                ["explanationTranslation"] = $"'{word}' 的意思是 '{meaning}'。",
                ["category"] = "meaning"
            };
        }).ToList();
    }

    private static List<Dictionary<string, object>> GenerateGrammar(string textbookCode, int count)
    {
        return Enumerable.Range(0, count).Select(i => new Dictionary<string, object>
        {
            ["id"] = Guid.NewGuid().ToString(),
            ["questionType"] = "grammar",
            ["textbookCode"] = textbookCode,
            ["stem"] = $"Choose the correct form: She ___ (study) English every day. (#{i + 1})",
            ["translation"] = "选择正确的形式：她每天___（学习）英语。",
            ["options"] = new[] { "study", "studies", "studying", "studied" },
            ["correctIndex"] = 1,
            ["grammarPoint"] = "Present Simple - Third Person Singular",
            ["grammarPointTranslation"] = "一般现在时 - 第三人称单数",
            ["explanation"] = "Third person singular adds -es to verbs ending in -y.",
            ["explanationTranslation"] = "第三人称单数，以 -y 结尾的动词变 -ies。"
        }).ToList();
    }

    private static List<Dictionary<string, object>> GenerateSpeaking(string textbookCode, int count)
    {
        var items = new (string Prompt, string Reference, string Translation, string Category)[]
        {
            ("Please read the following sentence aloud:", "The weather is beautiful today, isn't it?", "今天天气真好，不是吗？", "readAloud"),
            ("Listen and repeat:", "I would like a cup of coffee, please.", "我想要一杯咖啡，谢谢。", "readAloud"),
            ("Answer the following question:", "What do you usually do on weekends?", "你周末通常做什么？", "respond"),
            ("Retell the story in your own words:", "A boy found a lost puppy and took it home. His mother helped him find the owner.", "一个男孩发现了一只走失的小狗并把它带回了家。他的妈妈帮他找到了主人。", "retell"),
            ("Describe what you see in the picture:", "There is a park with children playing on the swings and slides.", "公园里有孩子们在荡秋千和滑滑梯。", "describe"),
        };

        return Enumerable.Range(0, count).Select(i =>
        {
            var (prompt, reference, translation, category) = items[i % items.Length];
            return new Dictionary<string, object>
            {
                ["id"] = Guid.NewGuid().ToString(),
                ["questionType"] = "speaking",
                ["textbookCode"] = textbookCode,
                ["prompt"] = $"{prompt} (#{i + 1})",
                ["referenceText"] = reference,
                ["translation"] = translation,
                ["category"] = category
            };
        }).ToList();
    }

    private static List<Dictionary<string, object>> GenerateWriting(string textbookCode, int count)
    {
        var items = new (string Prompt, string PromptTranslation, string Category, int MinWords, int MaxWords, string Reference, string ReferenceTranslation)[]
        {
            ("Write a short paragraph about your favorite hobby.", "写一段关于你最喜欢的爱好的短文。", "paragraph", 50, 100,
             "My favorite hobby is reading. I enjoy it because it allows me to explore different worlds and learn new things. I usually read for about an hour every evening before bed.",
             "我最喜欢的爱好是阅读。我喜欢它，因为它让我探索不同的世界并学习新事物。我通常每天晚上睡前读大约一个小时的书。"),
            ("Write a sentence using the word 'beautiful'.", "用 'beautiful' 这个词写一个句子。", "sentence", 5, 20,
             "The sunset over the ocean was truly beautiful.",
             "海上的日落真的很美。"),
            ("Write a short essay about the importance of learning English.", "写一篇关于学习英语重要性的短文。", "essay", 80, 150,
             "Learning English is important because it is a global language. It helps us communicate with people from different countries and opens up many opportunities for work and study.",
             "学习英语很重要，因为它是一门全球性语言。它帮助我们与来自不同国家的人交流，并为工作和学习开辟了许多机会。"),
            ("Write a letter to your pen pal introducing yourself.", "写一封信给你的笔友，介绍你自己。", "application", 60, 120,
             "Dear Tom, My name is Li Ming. I am 14 years old and I live in Beijing. I like playing basketball and reading books. I hope we can be good friends. Best wishes, Li Ming",
             "亲爱的汤姆，我叫李明。我14岁，住在北京。我喜欢打篮球和读书。希望我们能成为好朋友。祝好，李明"),
        };

        return Enumerable.Range(0, count).Select(i =>
        {
            var (prompt, promptTrans, category, minWords, maxWords, reference, refTrans) = items[i % items.Length];
            return new Dictionary<string, object>
            {
                ["id"] = Guid.NewGuid().ToString(),
                ["questionType"] = "writing",
                ["textbookCode"] = textbookCode,
                ["prompt"] = $"{prompt} (#{i + 1})",
                ["promptTranslation"] = promptTrans,
                ["category"] = category,
                ["wordLimit"] = new Dictionary<string, object> { ["min"] = minWords, ["max"] = maxWords },
                ["referenceAnswer"] = reference,
                ["referenceTranslation"] = refTrans
            };
        }).ToList();
    }
}
