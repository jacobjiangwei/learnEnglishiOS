using Microsoft.Azure.Cosmos;
using Microsoft.Azure.Cosmos.Linq;
using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Cosmos DB implementation of <see cref="IWordbookService"/>.
/// Container: wordbook, partition key: /deviceId
/// </summary>
public class CosmosWordbookService : IWordbookService
{
    private readonly Container _container;
    private readonly ILogger<CosmosWordbookService> _logger;

    public CosmosWordbookService(CosmosClient cosmos, IConfiguration config, ILogger<CosmosWordbookService> logger)
    {
        var db = config["CosmosDb:DatabaseName"] ?? "volingo";
        _container = cosmos.GetContainer(db, "wordbook");
        _logger = logger;
    }

    public async Task<WordbookEntry> AddWordAsync(string deviceId, WordbookAddRequest request)
    {
        // Check for duplicate
        var query = _container.GetItemLinqQueryable<WordbookDocument>(
                requestOptions: new QueryRequestOptions { PartitionKey = new PartitionKey(deviceId) })
            .Where(w => w.DeviceId == deviceId && w.Word == request.Word)
            .ToFeedIterator();

        if (query.HasMoreResults)
        {
            var page = await query.ReadNextAsync();
            var existing = page.FirstOrDefault();
            if (existing is not null)
                return ToEntry(existing);
        }

        var doc = new WordbookDocument
        {
            Id = Guid.NewGuid().ToString(),
            DeviceId = deviceId,
            Word = request.Word,
            Phonetic = request.Phonetic,
            Definitions = request.Definitions,
            AddedAt = DateTime.UtcNow
        };

        await _container.CreateItemAsync(doc, new PartitionKey(deviceId));
        return ToEntry(doc);
    }

    public async Task<bool> DeleteWordAsync(string deviceId, string wordId)
    {
        try
        {
            await _container.DeleteItemAsync<WordbookDocument>(wordId, new PartitionKey(deviceId));
            return true;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return false;
        }
    }

    public async Task<WordbookListResponse> GetWordbookAsync(string deviceId)
    {
        var query = _container.GetItemLinqQueryable<WordbookDocument>(
                requestOptions: new QueryRequestOptions { PartitionKey = new PartitionKey(deviceId) })
            .Where(w => w.DeviceId == deviceId)
            .OrderByDescending(w => w.AddedAt)
            .ToFeedIterator();

        var entries = new List<WordbookEntry>();
        while (query.HasMoreResults)
        {
            var page = await query.ReadNextAsync();
            entries.AddRange(page.Select(ToEntry));
        }

        return new WordbookListResponse(entries.Count, entries);
    }

    private static WordbookEntry ToEntry(WordbookDocument doc) =>
        new(doc.Id, doc.Word, doc.Phonetic, doc.Definitions, doc.AddedAt.ToString("o"));
}
