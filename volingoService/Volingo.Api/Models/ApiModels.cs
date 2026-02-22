namespace Volingo.Api.Models;

// ── Practice: Questions ──
public record QuestionsResponse(string QuestionType, string TextbookCode, int Remaining, List<object> Questions);
public record ReadingQuestionsResponse(string QuestionType, string TextbookCode, int Remaining, List<object> Passages);

// ── Practice: Today Package ──
public record TodayPackageResponse(string Date, string TextbookCode, int EstimatedMinutes, List<PackageItem> Items);
public record PackageItem(string Type, int Count, double Weight, List<object> Questions);

/// <summary>
/// Cosmos DB document for cached daily packages.
/// id = date string (yyyy-MM-dd), partition key = textbookCode.
/// </summary>
public record DailyPackageDocument(
    string id,
    string TextbookCode,
    int EstimatedMinutes,
    List<PackageItem> Items)
{
    public TodayPackageResponse ToResponse() => new(id, TextbookCode, EstimatedMinutes, Items);

    public static DailyPackageDocument FromResponse(TodayPackageResponse r) =>
        new(r.Date, r.TextbookCode, r.EstimatedMinutes, r.Items);
}

// ── Practice: Submit ──
public record SubmitRequest(List<SubmitResultItem> Results);
public record SubmitResultItem(string QuestionId, bool IsCorrect, string? QuestionType = null);

// ── Practice: Report ──
public record ReportRequest(string QuestionId, string? Reason = null, string? Description = null, string? QuestionType = null);
public record ReportResponse(string QuestionId, int ReportCount);

// ── User: Stats ──
public record StatsResponse(int TotalCompleted, int TotalCorrect, int CurrentStreak, int LongestStreak, List<DailyActivity> DailyActivity, List<QuestionTypeStats> QuestionTypeStats);
public record QuestionTypeStats(string QuestionType, int Total, int Correct);
public record DailyActivity(string Date, int Count, int CorrectCount);

// ── Wordbook ──
public record WordbookAddRequest(string Word, string? Phonetic, List<DefinitionItem> Definitions);
public record DefinitionItem(string PartOfSpeech, string Meaning, string? Example, string? ExampleTranslation);
public record WordbookEntry(string Id, string Word, string? Phonetic, List<DefinitionItem> Definitions, string AddedAt);
public record WordbookListResponse(int Total, List<WordbookEntry> Words);

// ── Dictionary ──
public record DictionaryResponse(
    string Word,
    string? Phonetic,
    List<DictionarySenseDto> Senses,
    DictionaryExchangeDto? Exchange,
    List<string> Synonyms,
    List<string> Antonyms,
    List<RelatedPhraseDto> RelatedPhrases,
    string? UsageNotes
);

public record DictionarySenseDto(
    string Pos,
    List<string> Definitions,
    List<string> Translations,
    List<DictionaryExampleDto> Examples
);

public record DictionaryExampleDto(string En, string Zh);

public record DictionaryExchangeDto(
    string? PastTense,
    string? PastParticiple,
    string? PresentParticiple,
    string? ThirdPersonSingular,
    string? Plural,
    string? Comparative,
    string? Superlative
);

public record RelatedPhraseDto(string Phrase, string Meaning);
