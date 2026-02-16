using Microsoft.Azure.Cosmos;
using Volingo.Api.Services;

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
        await db.CreateContainerIfNotExistsAsync(new ContainerProperties("completions", "/deviceId"));
        await db.CreateContainerIfNotExistsAsync(new ContainerProperties("wordbook", "/deviceId"));
        await db.CreateContainerIfNotExistsAsync(new ContainerProperties("reports", "/deviceId"));

        // Seed question bank in background (don't block app.Run())
        var questionsContainer = db.GetContainer("questions");
        _ = Task.Run(async () =>
        {
            try
            {
                await QuestionSeeder.SeedAsync(questionsContainer, logger);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Question seeding failed.");
            }
        });

        logger.LogInformation("✅ Cosmos DB database ready.");
        return app;
    }
}
