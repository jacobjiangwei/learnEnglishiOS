using Microsoft.Azure.Cosmos;

namespace Volingo.Api.Extensions;

public static class CosmosDbExtensions
{
    /// <summary>
    /// Ensure database and all containers exist on startup, then seed question bank.
    /// </summary>
    public static async Task<WebApplication> InitializeCosmosDbAsync(this WebApplication app, string databaseName)
    {
        var logger = app.Services.GetRequiredService<ILogger<CosmosClient>>();
        var cosmos = app.Services.GetRequiredService<CosmosClient>();

        logger.LogInformation("Initializing Cosmos DB database '{Database}'...", databaseName);

        var db = (await cosmos.CreateDatabaseIfNotExistsAsync(databaseName)).Database;

        // Create containers
        await db.CreateContainerIfNotExistsAsync(new ContainerProperties("questions", "/textbookCode"));
        await db.CreateContainerIfNotExistsAsync(new ContainerProperties("completions", "/userId"));
        await db.CreateContainerIfNotExistsAsync(new ContainerProperties("wordbook", "/userId"));
        await db.CreateContainerIfNotExistsAsync(new ContainerProperties("reports", "/id"));
        await db.CreateContainerIfNotExistsAsync(new ContainerProperties("dailyPackages", "/textbookCode"));
        await db.CreateContainerIfNotExistsAsync(new ContainerProperties("textbook", "/textbook"));
        await db.CreateContainerIfNotExistsAsync(new ContainerProperties("dictionary", "/word"));

        // Auth containers
        await db.CreateContainerIfNotExistsAsync(new ContainerProperties("users", "/id"));
        await db.CreateContainerIfNotExistsAsync(new ContainerProperties("userProfiles", "/id"));
        await db.CreateContainerIfNotExistsAsync(new ContainerProperties("identities", "/id"));
        await db.CreateContainerIfNotExistsAsync(new ContainerProperties("refreshTokens", "/userId"));
        await db.CreateContainerIfNotExistsAsync(new ContainerProperties("emailVerifications", "/userId")
        {
            DefaultTimeToLive = 600 // 10 minutes auto-expiry
        });

        logger.LogInformation("✅ Cosmos DB database ready.");
        return app;
    }
}
