using Microsoft.Azure.Cosmos;

namespace Volingo.Api.Extensions;

public static class CosmosDbExtensions
{
    /// <summary>
    /// Ensure database exists on startup.
    /// </summary>
    public static async Task<WebApplication> InitializeCosmosDbAsync(this WebApplication app, string databaseName)
    {
        var logger = app.Services.GetRequiredService<ILogger<CosmosClient>>();
        var cosmos = app.Services.GetRequiredService<CosmosClient>();

        logger.LogInformation("Initializing Cosmos DB database '{Database}'...", databaseName);

        await cosmos.CreateDatabaseIfNotExistsAsync(databaseName);

        logger.LogInformation("✅ Cosmos DB database ready.");
        return app;
    }
}
