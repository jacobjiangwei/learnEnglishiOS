using Microsoft.Azure.Cosmos;
using Microsoft.Azure.Cosmos.Linq;
using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Cosmos DB backed implementation of ISubmitResultService.
/// Container: completions, partition key: /deviceId
/// </summary>
public class CosmosSubmitResultService : ISubmitResultService
{
    private readonly Container _container;
    private readonly ILogger<CosmosSubmitResultService> _logger;

    public CosmosSubmitResultService(CosmosClient cosmos, IConfiguration config, ILogger<CosmosSubmitResultService> logger)
    {
        var databaseName = config["CosmosDb:DatabaseName"] ?? "volingo";
        _container = cosmos.GetContainer(databaseName, "completions");
        _logger = logger;
    }

    public async Task SubmitAsync(string deviceId, SubmitRequest request)
    {
        foreach (var item in request.Results)
        {
            var doc = new CompletionDocument
            {
                Id = $"{deviceId}_{item.QuestionId}",
                DeviceId = deviceId,
                QuestionId = item.QuestionId,
                QuestionType = item.QuestionType,
                IsCorrect = item.IsCorrect,
                CompletedAt = DateTime.UtcNow
            };

            try
            {
                await _container.UpsertItemAsync(doc, new PartitionKey(deviceId));
            }
            catch (CosmosException ex)
            {
                _logger.LogWarning(ex, "Failed to upsert completion {QuestionId} for device {DeviceId}",
                    item.QuestionId, deviceId);
            }
        }
    }

    public async Task<StatsResponse> GetStatsAsync(string deviceId, int days)
    {
        var cutoff = DateTime.UtcNow.Date.AddDays(-days);

        var query = _container.GetItemLinqQueryable<CompletionDocument>(
                requestOptions: new QueryRequestOptions { PartitionKey = new PartitionKey(deviceId) })
            .Where(c => c.DeviceId == deviceId)
            .ToFeedIterator();

        var allRecords = new List<CompletionDocument>();
        while (query.HasMoreResults)
        {
            var response = await query.ReadNextAsync();
            allRecords.AddRange(response);
        }

        var totalCompleted = allRecords.Count;
        var totalCorrect = allRecords.Count(r => r.IsCorrect);

        var dailyGroups = allRecords
            .Where(r => r.CompletedAt >= cutoff)
            .GroupBy(r => r.CompletedAt.ToString("yyyy-MM-dd"))
            .ToDictionary(g => g.Key, g => (Count: g.Count(), Correct: g.Count(r => r.IsCorrect)));

        var dailyActivity = new List<DailyActivity>();
        for (var d = DateTime.UtcNow.Date; d >= cutoff; d = d.AddDays(-1))
        {
            var key = d.ToString("yyyy-MM-dd");
            dailyGroups.TryGetValue(key, out var val);
            dailyActivity.Add(new DailyActivity(key, val.Count, val.Correct));
        }

        var (current, longest) = CalculateStreaks(dailyActivity);

        var questionTypeStats = allRecords
            .Where(r => !string.IsNullOrEmpty(r.QuestionType))
            .GroupBy(r => r.QuestionType!)
            .Select(g => new QuestionTypeStats(g.Key, g.Count(), g.Count(r => r.IsCorrect)))
            .OrderByDescending(s => s.Total)
            .ToList();

        return new StatsResponse(totalCompleted, totalCorrect, current, longest, dailyActivity, questionTypeStats);
    }

    public async Task<HashSet<string>> GetCompletedIdsAsync(string deviceId)
    {
        // Project only questionId for efficiency
        var query = new QueryDefinition("SELECT c.questionId FROM c WHERE c.deviceId = @did")
            .WithParameter("@did", deviceId);

        using var iterator = _container.GetItemQueryIterator<CompletionDocument>(
            query,
            requestOptions: new QueryRequestOptions { PartitionKey = new PartitionKey(deviceId) });

        var ids = new HashSet<string>();
        while (iterator.HasMoreResults)
        {
            var page = await iterator.ReadNextAsync();
            foreach (var item in page)
                ids.Add(item.QuestionId);
        }
        return ids;
    }

    private static (int Current, int Longest) CalculateStreaks(List<DailyActivity> daily)
    {
        int current = 0, longest = 0, streak = 0;
        bool countingCurrent = true;

        foreach (var d in daily)
        {
            if (d.Count > 0)
            {
                streak++;
                if (countingCurrent) current = streak;
                longest = Math.Max(longest, streak);
            }
            else
            {
                countingCurrent = false;
                streak = 0;
            }
        }
        return (current, longest);
    }
}
