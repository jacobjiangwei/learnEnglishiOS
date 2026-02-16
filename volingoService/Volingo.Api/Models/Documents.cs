namespace Volingo.Api.Models;

// Questions use dynamic schemas and are read as raw JSON streams — no document class needed.

// ── Completion (stored in "completions" container, PK: /deviceId) ──

public class CompletionDocument
{
    public string Id { get; set; } = "";
    public string DeviceId { get; set; } = "";
    public string QuestionId { get; set; } = "";
    public string? QuestionType { get; set; }
    public bool IsCorrect { get; set; }
    public DateTime CompletedAt { get; set; }
}

// ── Wordbook (stored in "wordbook" container, PK: /deviceId) ──

public class WordbookDocument
{
    public string Id { get; set; } = "";
    public string DeviceId { get; set; } = "";
    public string Word { get; set; } = "";
    public string? Phonetic { get; set; }
    public List<DefinitionItem> Definitions { get; set; } = [];
    public DateTime AddedAt { get; set; }
}

// ── Report (stored in "reports" container, PK: /deviceId) ──

public class ReportDocument
{
    public string Id { get; set; } = "";
    public string DeviceId { get; set; } = "";
    public string QuestionId { get; set; } = "";
    public string Reason { get; set; } = "";
    public string? Description { get; set; }
    public DateTime CreatedAt { get; set; }
}
