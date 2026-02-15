using System.Text.Json.Serialization;

namespace Volingo.Api.Models;

// ── Base Question ──

public abstract record QuestionBase
{
    public required string Id { get; init; }
    public required string Type { get; init; }
    public required string TextbookCode { get; init; }
}

// ── 2.1 Multiple Choice ──

public record MCQQuestion : QuestionBase
{
    public required string Stem { get; init; }
    public required string Translation { get; init; }
    public required string[] Options { get; init; }
    public required int CorrectIndex { get; init; }
    public required string Explanation { get; init; }
}

// ── 2.2 Cloze ──

public record ClozeQuestion : QuestionBase
{
    public required string Sentence { get; init; }
    public required string Translation { get; init; }
    public required string Answer { get; init; }
    public string? Hint { get; init; }
    public required string Explanation { get; init; }
}

// ── 2.3 Reading ──

public record ReadingPassage
{
    public required string Title { get; init; }
    public required string Content { get; init; }
    public required string Translation { get; init; }
}

public record ReadingSubQuestion
{
    public required string Id { get; init; }
    public required string Stem { get; init; }
    public required string Translation { get; init; }
    public required string[] Options { get; init; }
    public required int CorrectIndex { get; init; }
    public required string Explanation { get; init; }
}

public record ReadingQuestion : QuestionBase
{
    public required ReadingPassage Passage { get; init; }
    public required ReadingSubQuestion[] Questions { get; init; }
}

// ── 2.4 Translation ──

public record TranslationQuestion : QuestionBase
{
    public required string SourceText { get; init; }
    public required string SourceLanguage { get; init; }
    public required string ReferenceAnswer { get; init; }
    public required string[] Keywords { get; init; }
    public required string Explanation { get; init; }
}

// ── 2.5 Rewriting ──

public record RewritingQuestion : QuestionBase
{
    public required string OriginalSentence { get; init; }
    public required string OriginalTranslation { get; init; }
    public required string Instruction { get; init; }
    public required string ReferenceAnswer { get; init; }
    public required string ReferenceTranslation { get; init; }
    public required string Explanation { get; init; }
}

// ── 2.6 Error Correction ──

public record ErrorCorrectionQuestion : QuestionBase
{
    public required string Sentence { get; init; }
    public required string Translation { get; init; }
    public required string ErrorRange { get; init; }
    public required string Correction { get; init; }
    public required string Explanation { get; init; }
}

// ── 2.7 Sentence Ordering ──

public record OrderingQuestion : QuestionBase
{
    public required string[] ShuffledParts { get; init; }
    public required int[] CorrectOrder { get; init; }
    public required string Translation { get; init; }
    public required string Explanation { get; init; }
}

// ── 2.8 Listening ──

public record ListeningQuestion : QuestionBase
{
    public string? AudioURL { get; init; }
    public required string Transcript { get; init; }
    public required string TranscriptTranslation { get; init; }
    public required string Stem { get; init; }
    public required string StemTranslation { get; init; }
    public required string[] Options { get; init; }
    public required int CorrectIndex { get; init; }
    public required string Explanation { get; init; }
}

// ── 2.9 Speaking ──

public record SpeakingQuestion : QuestionBase
{
    public required string Prompt { get; init; }
    public required string ReferenceText { get; init; }
    public required string Translation { get; init; }
    public required string Category { get; init; }
}

// ── 2.10 Writing ──

public record WordLimit
{
    public required int Min { get; init; }
    public required int Max { get; init; }
}

public record WritingQuestion : QuestionBase
{
    public required string Prompt { get; init; }
    public required string PromptTranslation { get; init; }
    public required string Category { get; init; }
    public required WordLimit WordLimit { get; init; }
    public required string ReferenceAnswer { get; init; }
    public required string ReferenceTranslation { get; init; }
}

// ── 2.11 Vocabulary ──

public record VocabularyQuestion : QuestionBase
{
    public required string Word { get; init; }
    public string? Phonetic { get; init; }
    public required string Stem { get; init; }
    public required string Translation { get; init; }
    public required string[] Options { get; init; }
    public required int CorrectIndex { get; init; }
    public required string Explanation { get; init; }
    public required string Category { get; init; }
}

// ── 2.12 Grammar ──

public record GrammarQuestion : QuestionBase
{
    public required string Stem { get; init; }
    public required string Translation { get; init; }
    public required string[] Options { get; init; }
    public required int CorrectIndex { get; init; }
    public required string Explanation { get; init; }
    public required string Topic { get; init; }
}

// ── 2.13 Scenario ──

public record DialogueLine
{
    public required string Speaker { get; init; }
    public required string Text { get; init; }
    public string? Translation { get; init; }
}

public record ScenarioQuestion : QuestionBase
{
    public required string ScenarioTitle { get; init; }
    public required string Context { get; init; }
    public required DialogueLine[] DialogueLines { get; init; }
    public required string UserPrompt { get; init; }
    public string[]? Options { get; init; }
    public int? CorrectIndex { get; init; }
    public required string ReferenceResponse { get; init; }
    public required string ReferenceTranslation { get; init; }
}
