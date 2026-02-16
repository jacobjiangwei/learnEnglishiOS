using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Abstraction for persisting practice results and computing stats.
/// Implementations: CosmosSubmitResultService (Cosmos DB) and InMemorySubmitResultService (fallback).
/// </summary>
public interface ISubmitResultService
{
    /// <summary>
    /// Persist a batch of submit results. Must be idempotent by questionId per device.
    /// </summary>
    Task SubmitAsync(string deviceId, SubmitRequest request);

    /// <summary>
    /// Calculate stats (totalCompleted, totalCorrect, streaks, dailyActivity) for a device.
    /// </summary>
    Task<StatsResponse> GetStatsAsync(string deviceId, int days);

    /// <summary>
    /// Return all completed question IDs for a device (used to filter out answered questions).
    /// </summary>
    Task<HashSet<string>> GetCompletedIdsAsync(string deviceId);
}
