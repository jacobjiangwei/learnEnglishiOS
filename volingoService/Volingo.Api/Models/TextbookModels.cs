namespace Volingo.Api.Models;

/// <summary>
/// Textbook metadata — mirrors iOS OnboardingModels + Python models.py
/// ID rules:
///   Grade-sync: {seriesCode}-{gradeNumber}{a|b}  e.g. juniorPEP-7a
///   Non-grade:  {seriesCode}                      e.g. collegeCet4
/// </summary>
public static class TextbookCatalog
{
    // ── All textbook series ──
    public static readonly Dictionary<string, string> TextbookOptions = new()
    {
        // 小学
        ["primaryPEP"]    = "小学·人教版",
        ["primaryFLTRP"]  = "小学·外研版",
        ["primaryYilin"]  = "小学·译林版",
        ["primaryHujiao"] = "小学·沪教版",
        // 初中
        ["juniorPEP"]     = "初中·人教版",
        ["juniorFLTRP"]   = "初中·外研版",
        ["juniorYilin"]   = "初中·译林版",
        ["juniorHujiao"]  = "初中·沪教版",
        // 高中
        ["seniorPEP"]     = "高中·人教版",
        ["seniorFLTRP"]   = "高中·外研版",
        ["seniorYilin"]   = "高中·译林版",
        ["seniorHujiao"]  = "高中·沪教版",
        // 非学段
        ["collegeCet4"]      = "大学英语四级",
        ["collegeCet6"]      = "大学英语六级",
        ["graduateExam"]     = "考研英语",
        ["preschoolPhonics"] = "启蒙/自然拼读",
        ["cefr"]             = "CEFR 分级",
        ["cambridge"]        = "剑桥 English in Use",
        ["longman"]          = "朗文 Speakout/Cutting Edge",
        ["ielts"]            = "雅思备考",
        ["toefl"]            = "托福备考",
    };

    public static readonly HashSet<string> GradeSyncSeries =
    [
        "primaryPEP", "primaryFLTRP", "primaryYilin", "primaryHujiao",
        "juniorPEP",  "juniorFLTRP",  "juniorYilin",  "juniorHujiao",
        "seniorPEP",  "seniorFLTRP",  "seniorYilin",  "seniorHujiao",
    ];

    public static readonly HashSet<string> NonGradeSeries =
    [
        "collegeCet4", "collegeCet6", "graduateExam", "preschoolPhonics",
        "cefr", "cambridge", "longman", "ielts", "toefl",
    ];

    public static readonly Dictionary<int, string> GradeNames = new()
    {
        [1] = "一年级", [2] = "二年级", [3] = "三年级", [4] = "四年级",
        [5] = "五年级", [6] = "六年级", [7] = "七年级", [8] = "八年级",
        [9] = "九年级", [10] = "高一", [11] = "高二", [12] = "高三",
    };

    public static readonly Dictionary<string, string> SemesterNames = new()
    {
        ["a"] = "上册", ["b"] = "下册",
    };

    /// <summary>Grade ranges for each grade-sync series.</summary>
    public static readonly Dictionary<string, (int Start, int End)> SeriesGrades = new()
    {
        ["primaryPEP"]    = (1, 6),  ["primaryFLTRP"]  = (1, 6),
        ["primaryYilin"]  = (1, 6),  ["primaryHujiao"] = (1, 6),
        ["juniorPEP"]     = (7, 9),  ["juniorFLTRP"]   = (7, 9),
        ["juniorYilin"]   = (7, 9),  ["juniorHujiao"]  = (7, 9),
        ["seniorPEP"]     = (10, 12), ["seniorFLTRP"]  = (10, 12),
        ["seniorYilin"]   = (10, 12), ["seniorHujiao"] = (10, 12),
    };

    // ── Helper methods ──

    public static string MakeId(string seriesCode, int? grade = null, string? semester = null)
    {
        if (NonGradeSeries.Contains(seriesCode))
            return seriesCode;
        if (grade is null || semester is null)
            throw new ArgumentException($"Grade-sync series {seriesCode} requires grade and semester.");
        return $"{seriesCode}-{grade}{semester}";
    }

    public static string MakeDisplayName(string seriesCode, int? grade = null, string? semester = null)
    {
        var publisher = TextbookOptions.GetValueOrDefault(seriesCode, seriesCode);
        if (publisher.Contains('·'))
            publisher = publisher.Split('·')[1];

        if (NonGradeSeries.Contains(seriesCode))
            return publisher;

        var gradeName = grade.HasValue && GradeNames.TryGetValue(grade.Value, out var gn) ? gn : $"{grade}年级";
        var semName = semester is not null && SemesterNames.TryGetValue(semester, out var sn) ? sn : semester ?? "";
        return $"{publisher}·英语{gradeName}{semName}";
    }

    public static List<VolumeInfo> GetAllVolumes(string seriesCode)
    {
        if (NonGradeSeries.Contains(seriesCode))
            return [new VolumeInfo(null, TextbookOptions.GetValueOrDefault(seriesCode, seriesCode))];

        if (!SeriesGrades.TryGetValue(seriesCode, out var range))
            return [];

        var volumes = new List<VolumeInfo>();
        for (var g = range.Start; g <= range.End; g++)
        {
            foreach (var s in new[] { "a", "b" })
            {
                var vol = $"{g}{s}";
                var display = $"{GradeNames[g]}{SemesterNames[s]}";
                volumes.Add(new VolumeInfo(vol, display));
            }
        }
        return volumes;
    }
}

// ── DTOs ──

public record VolumeInfo(string? Volume, string Display);

public record TextbookSeriesInfo(string SeriesCode, string DisplayName, bool IsGradeSync);

// ── Cosmos "textbook" container document ──

public class TextbookDocument
{
    public string Id { get; set; } = "";
    /// <summary>Partition key — the series code, e.g. "juniorPEP"</summary>
    public string Textbook { get; set; } = "";
    public string? Volume { get; set; }
    public string DisplayName { get; set; } = "";
    public int TotalPages { get; set; }
    public string? RawContent { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    /// <summary>Structured analysis from GPT-4o</summary>
    public TextbookAnalysis? Analysis { get; set; }
    public DateTime? AnalysisUpdatedAt { get; set; }
}

// ── Analysis result models (output from GPT-4o) ──

public class TextbookAnalysis
{
    public BookInfo? BookInfo { get; set; }
    public List<UnitInfo> Units { get; set; } = [];
    public List<GlossaryEntry> VocabularyGlossary { get; set; } = [];
}

public class BookInfo
{
    public string? Title { get; set; }
    public string? Publisher { get; set; }
    public string? Grade { get; set; }
    public string? Semester { get; set; }
    public string? StartingPoint { get; set; }
    public List<string> Characters { get; set; } = [];
}

public class UnitInfo
{
    public int UnitNumber { get; set; }
    public string? UnitTitle { get; set; }
    public string? Topic { get; set; }
    public List<VocabularyItem> Vocabulary { get; set; } = [];
    public List<SentencePattern> SentencePatterns { get; set; } = [];
    public List<string> Grammar { get; set; } = [];
    public List<SongInfo> Songs { get; set; } = [];
    public List<string> Commands { get; set; } = [];
    public string? StoryTitle { get; set; }
    public string? StorySummary { get; set; }
}

public class VocabularyItem
{
    public string Word { get; set; } = "";
    public string Meaning { get; set; } = "";
    public string? Type { get; set; }
}

public class SentencePattern
{
    public string Pattern { get; set; } = "";
    public string? Usage { get; set; }
}

public class SongInfo
{
    public string Title { get; set; } = "";
    public string? Type { get; set; }
    public string? FirstLine { get; set; }
}

public class GlossaryEntry
{
    public string Word { get; set; } = "";
    public string Meaning { get; set; } = "";
    public string? Type { get; set; }
    public int? UnitFirst { get; set; }
}

// ── Request / Response DTOs ──

public record ExtractResult(string Content, int TotalPages, int CharCount, string Filename);

public record SaveTextbookRequest(string SeriesCode, string? Volume, string RawContent, int TotalPages);

public record SaveResult(bool Success, string Id, string DisplayName, int TotalPages, int CharCount);

public record AnalyzeResult(bool Success, string Id, string DisplayName, int UnitCount, TextbookAnalysis Analysis);

public record DocumentSummary(
    string Id, string Textbook, string? Volume, string DisplayName,
    int TotalPages, DateTime CreatedAt, DateTime UpdatedAt,
    bool HasAnalysis, DateTime? AnalysisUpdatedAt);
