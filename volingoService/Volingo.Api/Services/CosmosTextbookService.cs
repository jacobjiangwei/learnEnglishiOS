using Microsoft.Azure.Cosmos;
using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Cosmos DB implementation for textbook document CRUD.
/// Container: "textbook", Partition Key: /textbook (= seriesCode).
/// </summary>
public class CosmosTextbookService(CosmosClient cosmos, IConfiguration config, ILogger<CosmosTextbookService> logger)
    : ITextbookService
{
    private Container Container => cosmos
        .GetDatabase(config["CosmosDb:DatabaseName"] ?? "volingo")
        .GetContainer("textbook");

    public async Task<List<DocumentSummary>> ListDocumentsAsync()
    {
        const string query = """
            SELECT c.id, c.textbook, c.volume, c.displayName, c.totalPages,
                   c.createdAt, c.updatedAt,
                   IS_DEFINED(c.analysis) AS hasAnalysis,
                   c.analysisUpdatedAt
            FROM c
            """;

        var results = new List<DocumentSummary>();
        using var feed = Container.GetItemQueryIterator<dynamic>(new QueryDefinition(query));
        while (feed.HasMoreResults)
        {
            var response = await feed.ReadNextAsync();
            foreach (var item in response)
            {
                results.Add(new DocumentSummary(
                    Id: (string)item.id,
                    Textbook: (string)item.textbook,
                    Volume: (string?)item.volume,
                    DisplayName: (string)(item.displayName ?? ""),
                    TotalPages: (int)(item.totalPages ?? 0),
                    CreatedAt: item.createdAt != null ? (DateTime)item.createdAt : DateTime.MinValue,
                    UpdatedAt: item.updatedAt != null ? (DateTime)item.updatedAt : DateTime.MinValue,
                    HasAnalysis: (bool)(item.hasAnalysis ?? false),
                    AnalysisUpdatedAt: item.analysisUpdatedAt != null ? (DateTime?)item.analysisUpdatedAt : null
                ));
            }
        }
        return results;
    }

    public async Task<TextbookDocument?> GetDocumentAsync(string docId, string textbook)
    {
        try
        {
            var response = await Container.ReadItemAsync<TextbookDocument>(docId, new PartitionKey(textbook));
            return response.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
    }

    public async Task<SaveResult> SaveDocumentAsync(SaveTextbookRequest request)
    {
        if (!TextbookCatalog.TextbookOptions.ContainsKey(request.SeriesCode))
            throw new ArgumentException($"Unknown series: {request.SeriesCode}");

        int? grade = null;
        string? semester = null;
        if (TextbookCatalog.GradeSyncSeries.Contains(request.SeriesCode))
        {
            if (string.IsNullOrEmpty(request.Volume))
                throw new ArgumentException("Grade-sync textbook requires a volume.");
            semester = request.Volume[^1..];
            if (int.TryParse(request.Volume[..^1], out var g))
                grade = g;
            else
                throw new ArgumentException($"Invalid volume: {request.Volume}");
        }

        var docId = TextbookCatalog.MakeId(request.SeriesCode, grade, semester);
        var displayName = TextbookCatalog.MakeDisplayName(request.SeriesCode, grade, semester);
        var now = DateTime.UtcNow;

        // Preserve createdAt if document already exists
        var createdAt = now;
        try
        {
            var existing = await Container.ReadItemAsync<TextbookDocument>(docId, new PartitionKey(request.SeriesCode));
            createdAt = existing.Resource.CreatedAt;
            logger.LogInformation("Updating existing textbook document: {DocId}", docId);
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            logger.LogInformation("Creating new textbook document: {DocId}", docId);
        }

        var document = new TextbookDocument
        {
            Id = docId,
            Textbook = request.SeriesCode,
            Volume = request.Volume,
            DisplayName = displayName,
            TotalPages = request.TotalPages,
            RawContent = request.RawContent,
            CreatedAt = createdAt,
            UpdatedAt = now,
        };

        await Container.UpsertItemAsync(document, new PartitionKey(request.SeriesCode));
        logger.LogInformation("Saved textbook {DocId} ({Display}): {Pages} pages, {Chars} chars",
            docId, displayName, request.TotalPages, request.RawContent.Length);

        return new SaveResult(true, docId, displayName, request.TotalPages, request.RawContent.Length);
    }

    public async Task<TextbookDocument> SaveAnalysisAsync(string docId, string textbook, TextbookAnalysis analysis)
    {
        var doc = await GetDocumentAsync(docId, textbook)
            ?? throw new KeyNotFoundException($"Document not found: {docId}");

        doc.Analysis = analysis;
        doc.AnalysisUpdatedAt = DateTime.UtcNow;
        doc.UpdatedAt = DateTime.UtcNow;

        await Container.UpsertItemAsync(doc, new PartitionKey(textbook));
        logger.LogInformation("Analysis saved for {DocId}: {Units} units", docId, analysis.Units.Count);
        return doc;
    }

    public async Task<bool> DeleteDocumentAsync(string docId, string textbook)
    {
        try
        {
            await Container.DeleteItemAsync<TextbookDocument>(docId, new PartitionKey(textbook));
            logger.LogInformation("Deleted textbook document: {DocId}", docId);
            return true;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return false;
        }
    }
}
