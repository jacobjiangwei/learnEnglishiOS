using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Persists user reports about incorrect questions.
/// </summary>
public interface IReportService
{
    Task<string> ReportAsync(string deviceId, ReportRequest request);
}
