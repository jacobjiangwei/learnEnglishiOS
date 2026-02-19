using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Analyze textbook raw content with GPT-4o to produce structured JSON
/// (units, vocabulary, grammar, sentence patterns, etc.).
/// </summary>
public interface ITextbookAnalyzerService
{
    Task<TextbookAnalysis> AnalyzeAsync(string rawContent, string displayName);
}
