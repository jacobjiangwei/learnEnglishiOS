namespace Volingo.Api.Models;

// ── Practice Request / Response Models ──

public record PracticeQuestionsResponse
{
    public required string QuestionType { get; init; }
    public required string TextbookCode { get; init; }
    public object[]? Questions { get; init; }
    public object[]? Passages { get; init; }
}

public record TodayPackageItem
{
    public required string Type { get; init; }
    public required int Count { get; init; }
    public required double Weight { get; init; }
    public object[]? Questions { get; init; }
    public object[]? Passages { get; init; }
}

public record TodayPackageResponse
{
    public required string Date { get; init; }
    public required string TextbookCode { get; init; }
    public required int EstimatedMinutes { get; init; }
    public required TodayPackageItem[] Items { get; init; }
}

public record HomeProgressResponse
{
    public required int WeeklyQuestionsDone { get; init; }
    public required int Streak { get; init; }
    public required int TodayErrorCount { get; init; }
    public required string[] WeakTypes { get; init; }
    public required string CurrentTextbookCode { get; init; }
}

// ── Submit Answer ──

public record SubmitAnswerRequest
{
    public required string QuestionId { get; init; }
    public required string QuestionType { get; init; }
    public required string TextbookCode { get; init; }
    public required Dictionary<string, object> UserAnswer { get; init; }
    public required long TimeSpentMs { get; init; }
    public required string Timestamp { get; init; }
}

public record SubmitAnswerResponse
{
    public required bool Correct { get; init; }
    public required int Score { get; init; }
    public required string Feedback { get; init; }
    public required Dictionary<string, object> CorrectAnswer { get; init; }
}

// ── Report ──

public record ReportRequest
{
    public required string QuestionId { get; init; }
    public required string Reason { get; init; }
    public string? Description { get; init; }
}

public record ReportResponse
{
    public required string ReportId { get; init; }
}

// ── Auth ──

public record MergeDeviceRequest
{
    public required string DeviceId { get; init; }
}

public record MergeDeviceResponse
{
    public required int MergedRecords { get; init; }
    public required string Message { get; init; }
}
