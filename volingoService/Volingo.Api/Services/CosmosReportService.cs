using Microsoft.Azure.Cosmos;
using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Cosmos DB implementation of <see cref="IReportService"/>.
/// Container: reports, partition key: /deviceId
/// </summary>
public class CosmosReportService : IReportService
{
    private readonly Container _container;

    public CosmosReportService(CosmosClient cosmos, IConfiguration config)
    {
        var db = config["CosmosDb:DatabaseName"] ?? "volingo";
        _container = cosmos.GetContainer(db, "reports");
    }

    public async Task<string> ReportAsync(string deviceId, ReportRequest request)
    {
        var doc = new ReportDocument
        {
            Id = Guid.NewGuid().ToString("N"),
            DeviceId = deviceId,
            QuestionId = request.QuestionId,
            Reason = request.Reason,
            Description = request.Description,
            CreatedAt = DateTime.UtcNow
        };

        await _container.CreateItemAsync(doc, new PartitionKey(deviceId));
        return doc.Id;
    }
}
