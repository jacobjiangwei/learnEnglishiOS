using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Extract text/markdown from PDFs using Azure Document Intelligence.
/// </summary>
public interface IDocumentIntelligenceService
{
    Task<ExtractResult> ExtractPdfAsync(Stream pdfStream, string filename);
}
