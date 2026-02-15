using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Mock question service – returns sample data matching API_PROTOCOL.md.
/// Replace with Cosmos DB / real data source later.
/// </summary>
public class QuestionService
{
    public MCQQuestion[] GetMCQQuestions(string textbookCode, int count)
    {
        return Enumerable.Range(1, count).Select(i => new MCQQuestion
        {
            Id = Guid.NewGuid().ToString(),
            Type = "multipleChoice",
            TextbookCode = textbookCode,
            Stem = $"The word 'abandon' means ___. (#{i})",
            Translation = $"'abandon' 这个词的意思是 ___。(#{i})",
            Options = ["to keep", "to give up", "to find", "to carry"],
            CorrectIndex = 1,
            Explanation = "abandon 意为'放弃、抛弃'。"
        }).ToArray();
    }

    public ClozeQuestion[] GetClozeQuestions(string textbookCode, int count)
    {
        return Enumerable.Range(1, count).Select(i => new ClozeQuestion
        {
            Id = Guid.NewGuid().ToString(),
            Type = "cloze",
            TextbookCode = textbookCode,
            Sentence = "I have ___ finished my homework.",
            Translation = "我已经完成了我的作业。",
            Answer = "already",
            Hint = "已经",
            Explanation = "already 用于肯定句中，表示'已经'。"
        }).ToArray();
    }

    public ReadingQuestion[] GetReadingQuestions(string textbookCode, int count)
    {
        return Enumerable.Range(1, count).Select(i => new ReadingQuestion
        {
            Id = Guid.NewGuid().ToString(),
            Type = "reading",
            TextbookCode = textbookCode,
            Passage = new ReadingPassage
            {
                Title = "The Discovery of Penicillin",
                Content = "In 1928, Alexander Fleming noticed that a mold called Penicillium notatum had contaminated one of his petri dishes...",
                Translation = "1928年，亚历山大·弗莱明注意到一种名为青霉菌的霉菌污染了他的一个培养皿……"
            },
            Questions = [
                new ReadingSubQuestion
                {
                    Id = $"{Guid.NewGuid()}-q1",
                    Stem = "What did Fleming discover?",
                    Translation = "弗莱明发现了什么？",
                    Options = ["A new virus", "A mold that kills bacteria", "A new medicine", "A type of food"],
                    CorrectIndex = 1,
                    Explanation = "文中明确提到 Fleming 发现了一种能杀死细菌的霉菌。"
                }
            ]
        }).ToArray();
    }

    public VocabularyQuestion[] GetVocabularyQuestions(string textbookCode, int count)
    {
        return Enumerable.Range(1, count).Select(i => new VocabularyQuestion
        {
            Id = Guid.NewGuid().ToString(),
            Type = "vocabulary",
            TextbookCode = textbookCode,
            Word = "brave",
            Phonetic = "/breɪv/",
            Stem = "Which word means '勇敢的'?",
            Translation = "哪个词的意思是'勇敢的'？",
            Options = ["afraid", "brave", "shy", "lazy"],
            CorrectIndex = 1,
            Explanation = "brave 意为'勇敢的'。",
            Category = "meaning"
        }).ToArray();
    }

    public GrammarQuestion[] GetGrammarQuestions(string textbookCode, int count)
    {
        return Enumerable.Range(1, count).Select(i => new GrammarQuestion
        {
            Id = Guid.NewGuid().ToString(),
            Type = "grammar",
            TextbookCode = textbookCode,
            Stem = "She ___ to school every day.",
            Translation = "她每天去上学。",
            Options = ["go", "goes", "going", "gone"],
            CorrectIndex = 1,
            Explanation = "主语 She 是第三人称单数，一般现在时动词加 -es。",
            Topic = "tense"
        }).ToArray();
    }

    public ListeningQuestion[] GetListeningQuestions(string textbookCode, int count)
    {
        return Enumerable.Range(1, count).Select(i => new ListeningQuestion
        {
            Id = Guid.NewGuid().ToString(),
            Type = "listening",
            TextbookCode = textbookCode,
            AudioURL = null,
            Transcript = "Good morning, class. Today we're going to learn about the solar system.",
            TranscriptTranslation = "早上好，同学们。今天我们要学习太阳系。",
            Stem = "What is the topic of the lesson?",
            StemTranslation = "这节课的主题是什么？",
            Options = ["History", "The solar system", "English grammar", "Music"],
            CorrectIndex = 1,
            Explanation = "原文明确说 learn about the solar system。"
        }).ToArray();
    }

    public ErrorCorrectionQuestion[] GetErrorCorrectionQuestions(string textbookCode, int count)
    {
        return Enumerable.Range(1, count).Select(i => new ErrorCorrectionQuestion
        {
            Id = Guid.NewGuid().ToString(),
            Type = "errorCorrection",
            TextbookCode = textbookCode,
            Sentence = "She don't like apples.",
            Translation = "她不喜欢苹果。",
            ErrorRange = "don't",
            Correction = "doesn't",
            Explanation = "第三人称单数主语 She 后应该用 doesn't。"
        }).ToArray();
    }

    public OrderingQuestion[] GetOrderingQuestions(string textbookCode, int count)
    {
        return Enumerable.Range(1, count).Select(i => new OrderingQuestion
        {
            Id = Guid.NewGuid().ToString(),
            Type = "sentenceOrdering",
            TextbookCode = textbookCode,
            ShuffledParts = ["going", "I", "am", "to school"],
            CorrectOrder = [1, 2, 0, 3],
            Translation = "我正要去学校。",
            Explanation = "正确语序为 I am going to school."
        }).ToArray();
    }

    public TranslationQuestion[] GetTranslationQuestions(string textbookCode, int count)
    {
        return Enumerable.Range(1, count).Select(i => new TranslationQuestion
        {
            Id = Guid.NewGuid().ToString(),
            Type = "translation",
            TextbookCode = textbookCode,
            SourceText = "科技改变了我们的生活方式。",
            SourceLanguage = "zh",
            ReferenceAnswer = "Technology has changed our way of life.",
            Keywords = ["technology", "changed", "way of life"],
            Explanation = "注意时态用现在完成时 has changed。"
        }).ToArray();
    }

    public object[] GetQuestionsByType(string type, string textbookCode, int count)
    {
        return type switch
        {
            "multipleChoice" => GetMCQQuestions(textbookCode, count).Cast<object>().ToArray(),
            "cloze" => GetClozeQuestions(textbookCode, count).Cast<object>().ToArray(),
            "reading" => GetReadingQuestions(textbookCode, count).Cast<object>().ToArray(),
            "vocabulary" => GetVocabularyQuestions(textbookCode, count).Cast<object>().ToArray(),
            "grammar" => GetGrammarQuestions(textbookCode, count).Cast<object>().ToArray(),
            "listening" => GetListeningQuestions(textbookCode, count).Cast<object>().ToArray(),
            "errorCorrection" => GetErrorCorrectionQuestions(textbookCode, count).Cast<object>().ToArray(),
            "sentenceOrdering" => GetOrderingQuestions(textbookCode, count).Cast<object>().ToArray(),
            "translation" => GetTranslationQuestions(textbookCode, count).Cast<object>().ToArray(),
            _ => GetMCQQuestions(textbookCode, count).Cast<object>().ToArray(),
        };
    }

    public TodayPackageResponse GetTodayPackage(string textbookCode)
    {
        return new TodayPackageResponse
        {
            Date = DateTime.UtcNow.ToString("yyyy-MM-dd"),
            TextbookCode = textbookCode,
            EstimatedMinutes = 15,
            Items =
            [
                new TodayPackageItem
                {
                    Type = "multipleChoice",
                    Count = 10,
                    Weight = 0.35,
                    Questions = GetMCQQuestions(textbookCode, 10).Cast<object>().ToArray()
                },
                new TodayPackageItem
                {
                    Type = "cloze",
                    Count = 5,
                    Weight = 0.20,
                    Questions = GetClozeQuestions(textbookCode, 5).Cast<object>().ToArray()
                },
                new TodayPackageItem
                {
                    Type = "reading",
                    Count = 1,
                    Weight = 0.20,
                    Passages = GetReadingQuestions(textbookCode, 1).Cast<object>().ToArray()
                },
                new TodayPackageItem
                {
                    Type = "listening",
                    Count = 3,
                    Weight = 0.15,
                    Questions = GetListeningQuestions(textbookCode, 3).Cast<object>().ToArray()
                },
                new TodayPackageItem
                {
                    Type = "vocabulary",
                    Count = 5,
                    Weight = 0.10,
                    Questions = GetVocabularyQuestions(textbookCode, 5).Cast<object>().ToArray()
                }
            ]
        };
    }

    public HomeProgressResponse GetHomeProgress(string deviceId)
    {
        return new HomeProgressResponse
        {
            WeeklyQuestionsDone = 87,
            Streak = 5,
            TodayErrorCount = 4,
            WeakTypes = ["cloze", "listening"],
            CurrentTextbookCode = "juniorPEP-8a"
        };
    }
}
