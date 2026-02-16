namespace Volingo.Api.Models;

// ── Error response ──
public record ErrorResponse(string Error);

// ── Practice: Questions ──
public record QuestionsResponse(string QuestionType, string TextbookCode, int Remaining, List<object> Questions);

// ── Practice: Today Package ──
public record TodayPackageResponse(string Date, string TextbookCode, int EstimatedMinutes, List<PackageItem> Items);
public record PackageItem(string Type, int Count, double Weight, List<object> Questions);

// ── Practice: Submit ──
public record SubmitRequest(List<SubmitResultItem> Results);
public record SubmitResultItem(string QuestionId, bool IsCorrect);

// ── Practice: Report ──
public record ReportRequest(string QuestionId, string Reason, string? Description);
public record ReportResponse(string ReportId);

// ── User: Stats ──
public record StatsResponse(int TotalCompleted, int TotalCorrect, int CurrentStreak, int LongestStreak, List<DailyActivity> DailyActivity);
public record DailyActivity(string Date, int Count, int CorrectCount);

// ── Wordbook ──
public record WordbookAddRequest(string Word, string? Phonetic, List<DefinitionItem> Definitions);
public record DefinitionItem(string PartOfSpeech, string Meaning, string? Example, string? ExampleTranslation);
public record WordbookEntry(string Id, string Word, string? Phonetic, List<DefinitionItem> Definitions, string AddedAt);
public record WordbookListResponse(int Total, List<WordbookEntry> Words);

// ── Completion record (internal) ──
public record CompletionRecord(string DeviceId, string QuestionId, string QuestionType, string TextbookCode, bool IsCorrect, int TimeSpentMs, DateTime CompletedAt);
