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

// ── Dictionary (stored in "dictionary" container, PK: /word) ──

public class DictionaryDocument
{
    public string Id { get; set; } = "";           // same as Word (lowercase)
    public string Word { get; set; } = "";
    public string? Phonetic { get; set; }
    public string? AudioUrl { get; set; }
    public List<DictionarySense> Senses { get; set; } = [];
    public DictionaryExchange? Exchange { get; set; }
    public List<string> Synonyms { get; set; } = [];
    public List<string> Antonyms { get; set; } = [];
    public List<RelatedPhrase> RelatedPhrases { get; set; } = [];
    public string? UsageNotes { get; set; }
    public string Source { get; set; } = "ai";      // "ai" | "manual"
    public DateTime CreatedAt { get; set; }
    public int QueryCount { get; set; }
}

public class DictionarySense
{
    public string Pos { get; set; } = "";
    public List<string> Definitions { get; set; } = [];
    public List<string> Translations { get; set; } = [];
    public List<DictionaryExample> Examples { get; set; } = [];
}

public class DictionaryExample
{
    public string En { get; set; } = "";
    public string Zh { get; set; } = "";
}

public class DictionaryExchange
{
    public string? PastTense { get; set; }
    public string? PastParticiple { get; set; }
    public string? PresentParticiple { get; set; }
    public string? ThirdPersonSingular { get; set; }
    public string? Plural { get; set; }
    public string? Comparative { get; set; }
    public string? Superlative { get; set; }
}

public class RelatedPhrase
{
    public string Phrase { get; set; } = "";
    public string Meaning { get; set; } = "";
}
