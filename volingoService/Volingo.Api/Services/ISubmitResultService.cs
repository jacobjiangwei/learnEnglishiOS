using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Abstraction for persisting practice results and computing stats.
/// Implementations: CosmosSubmitResultService (Cosmos DB).
/// </summary>
public interface ISubmitResultService
{
    /// <summary>
    /// Persist a batch of submit results. Must be idempotent by questionId per user.
    /// </summary>
    Task SubmitAsync(string userId, SubmitRequest request);

    /// <summary>
    /// Calculate stats (totalCompleted, totalCorrect, streaks, dailyActivity) for a user.
    /// </summary>
    Task<StatsResponse> GetStatsAsync(string userId, int days);

    /// <summary>
    /// Return all completed question IDs for a user (used to filter out answered questions).
    /// </summary>
    Task<HashSet<string>> GetCompletedIdsAsync(string userId);
}
