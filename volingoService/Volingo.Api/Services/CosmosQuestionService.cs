using System.Text.Json;
using Microsoft.Azure.Cosmos;
using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Cosmos DB implementation of <see cref="IQuestionService"/>.
/// Container: questions, partition key: /textbookCode
///
/// Questions have dynamic schemas per questionType, so we read them as raw JSON
/// (not a strongly-typed C# model) to avoid losing fields through serialization.
/// </summary>
public class CosmosQuestionService : IQuestionService
{
    private readonly Container _container;

    public CosmosQuestionService(CosmosClient cosmos, IConfiguration config)
    {
        var db = config["CosmosDb:DatabaseName"] ?? "volingo";
        _container = cosmos.GetContainer(db, "questions");
    }

    public async Task<(List<object> Questions, int Remaining)> GetQuestionsAsync(
        string textbookCode, string questionType, int count, IReadOnlySet<string> completedIds)
    {
        var sql = new QueryDefinition(
            "SELECT * FROM c WHERE c.textbookCode = @tb AND c.questionType = @qt")
            .WithParameter("@tb", textbookCode)
            .WithParameter("@qt", questionType);

        var all = new List<JsonElement>();
        using var iterator = _container.GetItemQueryStreamIterator(sql,
            requestOptions: new QueryRequestOptions { PartitionKey = new PartitionKey(textbookCode) });

        while (iterator.HasMoreResults)
        {
            using var response = await iterator.ReadNextAsync();
            using var doc = await JsonDocument.ParseAsync(response.Content);
            if (doc.RootElement.TryGetProperty("Documents", out var docs))
            {
                foreach (var item in docs.EnumerateArray())
                    all.Add(item.Clone());
            }
        }

        var available = all
            .Where(j => !completedIds.Contains(GetId(j)))
            .ToList();

        var selected = available
            .OrderBy(_ => Random.Shared.Next())
            .Take(count)
            .ToList();

        var remaining = available.Count - selected.Count;

        var result = selected.Select(j => (object)StripCosmosMetadata(j)).ToList();

        return (result, remaining);
    }

    public async Task<TodayPackageResponse> GetTodayPackageAsync(
        string textbookCode, IReadOnlySet<string> completedIds)
    {
        var types = new (string Type, int Count, double Weight)[]
        {
            ("multipleChoice", 10, 0.35),
            ("cloze", 5, 0.20),
            ("reading", 3, 0.20),
            ("listening", 3, 0.15),
            ("vocabulary", 5, 0.10)
        };

        var items = new List<PackageItem>();
        foreach (var (type, count, weight) in types)
        {
            var (questions, _) = await GetQuestionsAsync(textbookCode, type, count, completedIds);
            if (questions.Count > 0)
                items.Add(new PackageItem(type, questions.Count, weight, questions));
        }

        return new TodayPackageResponse(
            Date: DateTime.UtcNow.ToString("yyyy-MM-dd"),
            TextbookCode: textbookCode,
            EstimatedMinutes: 15,
            Items: items);
    }

    private static string GetId(JsonElement j) =>
        j.TryGetProperty("id", out var id) ? id.GetString() ?? "" : "";

    /// <summary>
    /// Remove Cosmos internal properties (_rid, _self, _etag, _ts, _attachments).
    /// </summary>
    private static Dictionary<string, JsonElement> StripCosmosMetadata(JsonElement j)
    {
        var dict = new Dictionary<string, JsonElement>();
        foreach (var prop in j.EnumerateObject())
        {
            if (!prop.Name.StartsWith('_'))
                dict[prop.Name] = prop.Value.Clone();
        }
        return dict;
    }
}
