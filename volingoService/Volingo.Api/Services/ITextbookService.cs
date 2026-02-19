using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Textbook document CRUD in Cosmos DB (container: "textbook", PK: /textbook).
/// </summary>
public interface ITextbookService
{
    Task<List<DocumentSummary>> ListDocumentsAsync();
    Task<TextbookDocument?> GetDocumentAsync(string docId, string textbook);
    Task<SaveResult> SaveDocumentAsync(SaveTextbookRequest request);
    Task<TextbookDocument> SaveAnalysisAsync(string docId, string textbook, TextbookAnalysis analysis);
    Task<bool> DeleteDocumentAsync(string docId, string textbook);
}
