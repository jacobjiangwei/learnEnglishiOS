using System.Collections.Concurrent;
using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// In-memory mock data service. Replaces Cosmos DB until real question bank is ready.
/// Stores completion records, reports, and wordbook entries per device.
/// </summary>
public class MockDataService
{
    // deviceId -> list of completion records
    private readonly ConcurrentDictionary<string, List<CompletionRecord>> _completions = new();

    // deviceId -> list of wordbook entries
    private readonly ConcurrentDictionary<string, List<WordbookEntry>> _wordbooks = new();

    // all reports
    private readonly ConcurrentBag<(string DeviceId, ReportRequest Report, string ReportId)> _reports = [];

    // Mock question bank: textbookCode -> questionType -> list of questions
    private readonly Dictionary<string, Dictionary<string, List<object>>> _questionBank;

    // Flat index: questionId -> (textbookCode, questionType)
    private readonly Dictionary<string, (string TextbookCode, string QuestionType)> _questionIndex = new();

    public MockDataService()
    {
        _questionBank = BuildMockQuestionBank();

        // Build flat lookup index
        foreach (var (textbookCode, types) in _questionBank)
            foreach (var (questionType, questions) in types)
                foreach (var q in questions)
                    if (q is Dictionary<string, object> dict && dict.TryGetValue("id", out var id))
                        _questionIndex[id.ToString()!] = (textbookCode, questionType);
    }

    // ── Questions ──

    public (List<object> Questions, int Remaining) GetQuestions(string deviceId, string textbookCode, string questionType, int count)
    {
        var completedIds = GetCompletedQuestionIds(deviceId, textbookCode);

        if (!_questionBank.TryGetValue(textbookCode, out var types))
            types = _questionBank.Values.FirstOrDefault() ?? [];

        if (!types.TryGetValue(questionType, out var allQuestions))
            allQuestions = [];

        var available = allQuestions
            .Where(q => !completedIds.Contains(GetQuestionId(q)))
            .ToList();

        var selected = available.OrderBy(_ => Random.Shared.Next()).Take(count).ToList();
        var remaining = available.Count - selected.Count;

        return (selected, remaining);
    }

    // ── Today Package ──

    public TodayPackageResponse GetTodayPackage(string deviceId, string textbookCode)
    {
        var types = new[] {
            ("multipleChoice", 10, 0.35),
            ("cloze", 5, 0.20),
            ("reading", 3, 0.20),
            ("listening", 3, 0.15),
            ("vocabulary", 5, 0.10)
        };

        var items = new List<PackageItem>();
        foreach (var (type, count, weight) in types)
        {
            var (questions, _) = GetQuestions(deviceId, textbookCode, type, count);
            if (questions.Count > 0)
            {
                items.Add(new PackageItem(type, questions.Count, weight, questions));
            }
        }

        return new TodayPackageResponse(
            Date: DateTime.UtcNow.ToString("yyyy-MM-dd"),
            TextbookCode: textbookCode,
            EstimatedMinutes: 15,
            Items: items
        );
    }

    // ── Submit ──

    public void Submit(string deviceId, SubmitRequest request)
    {
        var records = _completions.GetOrAdd(deviceId, _ => []);

        foreach (var item in request.Results)
        {
            // ON CONFLICT DO NOTHING — idempotent
            if (records.Any(r => r.QuestionId == item.QuestionId))
                continue;

            // Look up textbookCode & questionType from question bank
            var (textbookCode, questionType) = _questionIndex.TryGetValue(item.QuestionId, out var meta)
                ? meta
                : ("unknown", "unknown");

            records.Add(new CompletionRecord(
                deviceId, item.QuestionId, questionType, textbookCode,
                item.IsCorrect, 0, DateTime.UtcNow
            ));
        }
    }

    // ── Report ──

    public string Report(string deviceId, ReportRequest request)
    {
        var reportId = Guid.NewGuid().ToString("N");
        _reports.Add((deviceId, request, reportId));
        return reportId;
    }

    // ── Stats ──

    public StatsResponse GetStats(string deviceId, int days)
    {
        var records = _completions.GetOrAdd(deviceId, _ => []);

        var totalCompleted = records.Count;
        var totalCorrect = records.Count(r => r.IsCorrect);

        var cutoff = DateTime.UtcNow.Date.AddDays(-days);
        var dailyGroups = records
            .Where(r => r.CompletedAt >= cutoff)
            .GroupBy(r => r.CompletedAt.ToString("yyyy-MM-dd"))
            .ToDictionary(g => g.Key, g => (Count: g.Count(), Correct: g.Count(r => r.IsCorrect)));

        // Build daily activity array (fill missing days with 0)
        var dailyActivity = new List<DailyActivity>();
        for (var d = DateTime.UtcNow.Date; d >= cutoff; d = d.AddDays(-1))
        {
            var key = d.ToString("yyyy-MM-dd");
            dailyGroups.TryGetValue(key, out var val);
            dailyActivity.Add(new DailyActivity(key, val.Count, val.Correct));
        }

        // Calculate streaks
        var (current, longest) = CalculateStreaks(dailyActivity);

        return new StatsResponse(totalCompleted, totalCorrect, current, longest, dailyActivity);
    }

    // ── Wordbook ──

    public WordbookEntry AddWord(string deviceId, WordbookAddRequest request)
    {
        var entries = _wordbooks.GetOrAdd(deviceId, _ => []);

        var existing = entries.FirstOrDefault(e => e.Word.Equals(request.Word, StringComparison.OrdinalIgnoreCase));
        if (existing is not null)
            return existing;

        var id = Guid.NewGuid().ToString();
        var now = DateTime.UtcNow.ToString("o");
        var entry = new WordbookEntry(id, request.Word, request.Phonetic, request.Definitions, now);
        entries.Add(entry);

        return entry;
    }

    public bool DeleteWord(string deviceId, string wordId)
    {
        if (!_wordbooks.TryGetValue(deviceId, out var entries)) return false;
        return entries.RemoveAll(e => e.Id == wordId) > 0;
    }

    public WordbookListResponse GetWordbook(string deviceId)
    {
        var entries = _wordbooks.GetOrAdd(deviceId, _ => []);
        var sorted = entries.OrderByDescending(e => e.AddedAt).ToList();
        return new WordbookListResponse(sorted.Count, sorted);
    }

    // ── Helpers ──

    private HashSet<string> GetCompletedQuestionIds(string deviceId, string textbookCode)
    {
        if (!_completions.TryGetValue(deviceId, out var records)) return [];
        return records.Where(r => r.TextbookCode == textbookCode).Select(r => r.QuestionId).ToHashSet();
    }

    private int GetTotalQuestionsForTextbook(string textbookCode)
    {
        if (!_questionBank.TryGetValue(textbookCode, out var types))
            types = _questionBank.Values.FirstOrDefault() ?? [];
        return types.Values.Sum(q => q.Count);
    }

    private static string GetQuestionId(object q)
    {
        if (q is Dictionary<string, object> dict && dict.TryGetValue("id", out var id))
            return id?.ToString() ?? "";
        return "";
    }

    private static (int Current, int Longest) CalculateStreaks(List<DailyActivity> daily)
    {
        int current = 0, longest = 0, streak = 0;
        bool countingCurrent = true;

        foreach (var d in daily) // already sorted desc (today first)
        {
            if (d.Count > 0)
            {
                streak++;
                if (countingCurrent) current = streak;
                longest = Math.Max(longest, streak);
            }
            else
            {
                countingCurrent = false;
                streak = 0;
            }
        }
        return (current, longest);
    }

    // ── Mock Question Bank ──

    private static Dictionary<string, Dictionary<string, List<object>>> BuildMockQuestionBank()
    {
        var bank = new Dictionary<string, Dictionary<string, List<object>>>();

        // Generate for sample textbooks (cover all stages for mock)
        var textbookCodes = new[] {
            "juniorPEP-7a", "juniorPEP-7b", "juniorPEP-8a",
            "primaryPEP-3a", "primaryPEP-3b", "primaryPEP-4a", "primaryPEP-4b",
            "primaryPEP-5a", "primaryPEP-5b", "primaryPEP-6a", "primaryPEP-6b",
            "seniorPEP-1a", "seniorPEP-1b", "seniorPEP-2a"
        };

        foreach (var code in textbookCodes)
        {
            bank[code] = new Dictionary<string, List<object>>
            {
                ["multipleChoice"] = GenerateMCQ(code, 20),
                ["cloze"] = GenerateCloze(code, 10),
                ["reading"] = GenerateReading(code, 5),
                ["translation"] = GenerateTranslation(code, 8),
                ["rewriting"] = GenerateRewriting(code, 6),
                ["errorCorrection"] = GenerateErrorCorrection(code, 6),
                ["sentenceOrdering"] = GenerateOrdering(code, 6),
                ["listening"] = GenerateListening(code, 8),
                ["speaking"] = GenerateSpeaking(code, 6),
                ["writing"] = GenerateWriting(code, 4),
                ["vocabulary"] = GenerateVocabulary(code, 10),
                ["grammar"] = GenerateGrammar(code, 8),
            };
        }

        return bank;
    }

    private static List<object> GenerateMCQ(string textbookCode, int count)
    {
        var stems = new (string Stem, string Translation, string[] Options, int Correct)[] {
            ("What is the capital of the UK?", "英国的首都是什么？", ["Paris", "London", "Berlin", "Madrid"], 1),
            ("Which word means 'happy'?", "\u201c快乐的\u201d是哪个词？", ["sad", "angry", "joyful", "tired"], 2),
            ("She ___ to school every day.", "她每天___去学校。", ["go", "goes", "going", "went"], 1),
            ("The opposite of 'hot' is ___.", "\u201c热\u201d的反义词是___。", ["warm", "cool", "cold", "freezing"], 2),
            ("I have ___ apple.", "我有___苹果。", ["a", "an", "the", "some"], 1),
        };

        return Enumerable.Range(0, count).Select(i =>
        {
            var (stem, translation, options, correct) = stems[i % stems.Length];
            return (object)new Dictionary<string, object>
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

    private static List<object> GenerateCloze(string textbookCode, int count)
    {
        var items = new (string Sentence, string Translation, string Answer, string[] Hints)[] {
            ("I have ___ been to Beijing.", "我___去过北京。", "already", ["already", "yet", "still", "never"]),
            ("She is good ___ singing.", "她擅长___唱歌。", "at", ["at", "in", "on", "for"]),
            ("They ___ playing football now.", "他们现在正在踢足球。", "are", ["are", "is", "was", "were"]),
        };

        return Enumerable.Range(0, count).Select(i =>
        {
            var (sentence, translation, answer, hints) = items[i % items.Length];
            return (object)new Dictionary<string, object>
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

    private static List<object> GenerateReading(string textbookCode, int count)
    {
        return Enumerable.Range(0, count).Select(i => (object)new Dictionary<string, object>
        {
            ["id"] = Guid.NewGuid().ToString(),
            ["questionType"] = "reading",
            ["textbookCode"] = textbookCode,
            ["title"] = $"A Day at School #{i + 1}",
            ["content"] = "Tom gets up at seven o'clock every morning. He has breakfast and then goes to school by bus. He likes English and math. After school, he plays basketball with his friends.",
            ["translation"] = "汤姆每天早上七点起床。他吃完早餐后坐公交去学校。他喜欢英语和数学。放学后，他和朋友们打篮球。",
            ["questions"] = new List<object>
            {
                new Dictionary<string, object>
                {
                    ["id"] = Guid.NewGuid().ToString(),
                    ["stem"] = "What time does Tom get up?",
                    ["translation"] = "汤姆几点起床？",
                    ["options"] = new[] { "Six o'clock", "Seven o'clock", "Eight o'clock", "Nine o'clock" },
                    ["correctIndex"] = 1,
                    ["explanation"] = "The passage says 'Tom gets up at seven o'clock every morning.'"
                },
                new Dictionary<string, object>
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

    private static List<object> GenerateTranslation(string textbookCode, int count)
    {
        var items = new[] {
            ("I want to be a teacher when I grow up.", "我长大后想当一名老师。"),
            ("Can you help me with my homework?", "你能帮我做作业吗？"),
            ("The weather is very nice today.", "今天天气很好。"),
        };

        return Enumerable.Range(0, count).Select(i =>
        {
            var (source, reference) = items[i % items.Length];
            return (object)new Dictionary<string, object>
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

    private static List<object> GenerateRewriting(string textbookCode, int count)
    {
        return Enumerable.Range(0, count).Select(i => (object)new Dictionary<string, object>
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

    private static List<object> GenerateErrorCorrection(string textbookCode, int count)
    {
        return Enumerable.Range(0, count).Select(i => (object)new Dictionary<string, object>
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

    private static List<object> GenerateOrdering(string textbookCode, int count)
    {
        return Enumerable.Range(0, count).Select(i => (object)new Dictionary<string, object>
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

    private static List<object> GenerateListening(string textbookCode, int count)
    {
        return Enumerable.Range(0, count).Select(i => (object)new Dictionary<string, object>
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

    private static List<object> GenerateVocabulary(string textbookCode, int count)
    {
        var words = new[] {
            ("achieve", "实现；达到", "She worked hard to achieve her goals.", "她努力工作以实现她的目标。"),
            ("brilliant", "杰出的；明亮的", "He is a brilliant student.", "他是一个杰出的学生。"),
            ("confident", "自信的", "She feels confident about the exam.", "她对考试感到自信。"),
        };

        return Enumerable.Range(0, count).Select(i =>
        {
            var (word, meaning, example, exampleTrans) = words[i % words.Length];
            return (object)new Dictionary<string, object>
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

    private static List<object> GenerateGrammar(string textbookCode, int count)
    {
        return Enumerable.Range(0, count).Select(i => (object)new Dictionary<string, object>
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

    private static List<object> GenerateSpeaking(string textbookCode, int count)
    {
        var items = new (string Prompt, string Reference, string Translation, string Category)[] {
            ("Please read the following sentence aloud:", "The weather is beautiful today, isn't it?", "今天天气真好，不是吗？", "readAloud"),
            ("Listen and repeat:", "I would like a cup of coffee, please.", "我想要一杯咖啡，谢谢。", "readAloud"),
            ("Answer the following question:", "What do you usually do on weekends?", "你周末通常做什么？", "respond"),
            ("Retell the story in your own words:", "A boy found a lost puppy and took it home. His mother helped him find the owner.", "一个男孩发现了一只走失的小狗并把它带回了家。他的妈妈帮他找到了主人。", "retell"),
            ("Describe what you see in the picture:", "There is a park with children playing on the swings and slides.", "公园里有孩子们在荡秋千和滑滑梯。", "describe"),
        };

        return Enumerable.Range(0, count).Select(i =>
        {
            var (prompt, reference, translation, category) = items[i % items.Length];
            return (object)new Dictionary<string, object>
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

    private static List<object> GenerateWriting(string textbookCode, int count)
    {
        var items = new (string Prompt, string PromptTranslation, string Category, int MinWords, int MaxWords, string Reference, string ReferenceTranslation)[] {
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
            return (object)new Dictionary<string, object>
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
