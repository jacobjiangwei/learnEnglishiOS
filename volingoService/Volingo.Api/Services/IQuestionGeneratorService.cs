using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// AI-powered question generation from textbook analysis data.
/// Generates questions per unit × question type.
/// </summary>
public interface IQuestionGeneratorService
{
    /// <summary>
    /// Generate questions for a specific unit and question type.
    /// Returns raw question dictionaries (dynamic JSON schema for Cosmos DB).
    /// </summary>
    Task<List<Dictionary<string, object>>> GenerateQuestionsAsync(
        GenerateQuestionsRequest request);
}

/// <summary>
/// All supported question types.
/// </summary>
public static class QuestionTypes
{
    public const string Vocabulary = "vocabulary";
    public const string Cloze = "cloze";
    public const string Grammar = "grammar";
    public const string MultipleChoice = "multipleChoice";
    public const string ErrorCorrection = "errorCorrection";
    public const string Translation = "translation";
    public const string Rewriting = "rewriting";
    public const string SentenceOrdering = "sentenceOrdering";
    public const string Reading = "reading";
    public const string Listening = "listening";
    public const string Speaking = "speaking";

    public static readonly string[] All =
    [
        Vocabulary, Cloze, Grammar, MultipleChoice, ErrorCorrection,
        Translation, Rewriting, SentenceOrdering, Reading, Listening, Speaking
    ];

    public static bool IsValid(string type) => All.Contains(type);
}

public record GenerateQuestionsRequest(
    string TextbookCode,
    string DisplayName,
    string Level,
    int UnitNumber,
    UnitInfo Unit,
    List<GlossaryEntry> Glossary,
    string QuestionType
);

