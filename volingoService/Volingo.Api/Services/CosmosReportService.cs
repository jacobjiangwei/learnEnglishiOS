using Microsoft.Azure.Cosmos;
using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Cosmos DB implementation of <see cref="IReportService"/>.
/// Container: reports — one document per questionId, counter-based.
/// id = questionId, partition key = /id
/// </summary>
public class CosmosReportService : IReportService
{
    private readonly Container _container;

    public CosmosReportService(CosmosClient cosmos, IConfiguration config)
    {
        var db = config["CosmosDb:DatabaseName"] ?? "volingo";
        _container = cosmos.GetContainer(db, "reports");
    }

    /// <summary>
    /// Upsert: if doc exists for this questionId, increment count; otherwise create with count=1.
    /// </summary>
    public async Task<ReportDocument> ReportAsync(ReportRequest request)
    {
        var pk = new PartitionKey(request.QuestionId);
        ReportDocument doc;

        try
        {
            var resp = await _container.ReadItemAsync<ReportDocument>(request.QuestionId, pk);
            doc = resp.Resource;
            doc.ReportCount++;
            doc.LastReportedAt = DateTime.UtcNow;
            // Update fields if provided
            if (request.QuestionType is not null) doc.QuestionType = request.QuestionType;
            if (request.Reason is not null) doc.Reason = request.Reason;
            if (request.Description is not null) doc.LatestDescription = request.Description;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            doc = new ReportDocument
            {
                Id = request.QuestionId,
                QuestionType = request.QuestionType,
                Reason = request.Reason,
                LatestDescription = request.Description,
                ReportCount = 1,
                FirstReportedAt = DateTime.UtcNow,
                LastReportedAt = DateTime.UtcNow
            };
        }

        await _container.UpsertItemAsync(doc, pk);
        return doc;
    }

    /// <summary>
    /// List all reports ordered by reportCount DESC with offset/limit paging.
    /// </summary>
    public async Task<(List<ReportDocument> Items, int Total)> ListAsync(int offset = 0, int limit = 20)
    {
        // Get total count
        var countQuery = new QueryDefinition("SELECT VALUE COUNT(1) FROM c");
        int total = 0;
        using (var countIt = _container.GetItemQueryIterator<int>(countQuery))
        {
            if (countIt.HasMoreResults)
            {
                var r = await countIt.ReadNextAsync();
                total = r.FirstOrDefault();
            }
        }

        // Paged query ordered by reportCount DESC
        var query = new QueryDefinition(
            "SELECT * FROM c ORDER BY c.reportCount DESC OFFSET @offset LIMIT @limit")
            .WithParameter("@offset", offset)
            .WithParameter("@limit", limit);

        var items = new List<ReportDocument>();
        using var iterator = _container.GetItemQueryIterator<ReportDocument>(query);
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            items.AddRange(response);
        }

        return (items, total);
    }

    /// <summary>Delete the report counter document for a question.</summary>
    public async Task<bool> DeleteAsync(string questionId)
    {
        try
        {
            await _container.DeleteItemAsync<ReportDocument>(questionId, new PartitionKey(questionId));
            return true;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return false;
        }
    }
}
