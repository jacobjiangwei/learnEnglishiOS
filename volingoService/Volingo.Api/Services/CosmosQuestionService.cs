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
    private readonly Container _dailyPackagesContainer;

    private static readonly TimeZoneInfo ChinaTimeZone =
        TimeZoneInfo.FindSystemTimeZoneById("Asia/Shanghai");

    public CosmosQuestionService(CosmosClient cosmos, IConfiguration config)
    {
        var db = config["CosmosDb:DatabaseName"] ?? "volingo";
        _container = cosmos.GetContainer(db, "questions");
        _dailyPackagesContainer = cosmos.GetContainer(db, "dailyPackages");
    }

    /// <summary>China-time date string for "today".</summary>
    private static string TodayChinaDate() =>
        TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, ChinaTimeZone).ToString("yyyy-MM-dd");

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

    public async Task<TodayPackageResponse> GetTodayPackageAsync(string textbookCode)
    {
        var dateStr = TodayChinaDate();
        var pk = new PartitionKey(textbookCode);

        // 1. 尝试读取已有的每日包
        try
        {
            var existing = await _dailyPackagesContainer.ReadItemAsync<DailyPackageDocument>(
                dateStr, pk);
            return existing.Resource.ToResponse();
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            // 不存在 → 生成
        }

        // 2. 懒生成今日包（生成逻辑待实现，暂返回空包）
        var package = await GenerateDailyPackageAsync(textbookCode, dateStr);
        var doc = DailyPackageDocument.FromResponse(package);

        // 3. 写入 Cosmos（处理并发：如果另一个请求已经写入，读取它的结果）
        try
        {
            await _dailyPackagesContainer.CreateItemAsync(doc, pk);
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.Conflict)
        {
            // 并发竞争，另一个请求已写入 → 读取它的版本
            var existing = await _dailyPackagesContainer.ReadItemAsync<DailyPackageDocument>(
                dateStr, pk);
            return existing.Resource.ToResponse();
        }

        return package;
    }

    /// <summary>
    /// 生成每日统一赛题包（TODO: 接入 AI 出题 / 题库抽取）。
    /// 当前返回空包。
    /// </summary>
    private Task<TodayPackageResponse> GenerateDailyPackageAsync(string textbookCode, string date)
    {
        var package = new TodayPackageResponse(
            Date: date,
            TextbookCode: textbookCode,
            EstimatedMinutes: 0,
            Items: new List<PackageItem>());
        return Task.FromResult(package);
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
