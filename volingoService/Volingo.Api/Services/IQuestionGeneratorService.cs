using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// AI-powered question generation from textbook analysis data.
/// Generates questions per unit × batch (to stay within token limits).
/// </summary>
public interface IQuestionGeneratorService
{
    /// <summary>
    /// Generate questions for a specific unit and batch.
    /// Returns raw question dictionaries (dynamic JSON schema for Cosmos DB).
    /// </summary>
    Task<List<Dictionary<string, object>>> GenerateQuestionsAsync(
        GenerateQuestionsRequest request);
}

/// <summary>
/// Batch identifiers — each batch groups related question types.
/// </summary>
public enum QuestionBatch
{
    /// <summary>vocabulary + cloze</summary>
    VocabCloze,
    /// <summary>grammar + multipleChoice + errorCorrection</summary>
    GrammarMcqError,
    /// <summary>translation + rewriting + sentenceOrdering</summary>
    TransRewriteOrder,
    /// <summary>reading + writing</summary>
    ReadingWriting,
    /// <summary>listening + speaking</summary>
    ListeningSpeaking,
}

public record GenerateQuestionsRequest(
    string TextbookCode,
    string DisplayName,
    string Level,
    int UnitNumber,
    UnitInfo Unit,
    List<GlossaryEntry> Glossary,
    QuestionBatch Batch
);
