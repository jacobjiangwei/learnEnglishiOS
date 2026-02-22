using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Tracks per-question report counts. Each report increments the counter.
/// </summary>
public interface IReportService
{
    /// <summary>Increment report count for a question (upsert).</summary>
    Task<ReportDocument> ReportAsync(ReportRequest request);

    /// <summary>List reports ordered by reportCount desc, with offset paging.</summary>
    Task<(List<ReportDocument> Items, int Total)> ListAsync(int offset = 0, int limit = 20);

    /// <summary>Delete a report document (after admin resolves it).</summary>
    Task<bool> DeleteAsync(string questionId);
}
