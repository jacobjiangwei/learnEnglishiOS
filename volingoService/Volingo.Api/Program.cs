using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Azure.Cosmos;
using Scalar.AspNetCore;
using Volingo.Api.Extensions;
using Volingo.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// Aspire service defaults (health checks, telemetry, resilience)
builder.AddServiceDefaults();

// Cosmos DB — required (no mock fallback)
var cosmosConnectionString = builder.Configuration.GetConnectionString("cosmos")
    ?? throw new InvalidOperationException(
        "Missing ConnectionStrings:cosmos. Set it via environment variable or appsettings.");
var databaseName = builder.Configuration["CosmosDb:DatabaseName"] ?? "volingo";

// Cosmos SDK uses Newtonsoft.Json internally with camelCase —
// must stay in sync with ASP.NET's STJ camelCase policy above.
var isLocal = cosmosConnectionString.Contains("localhost");
builder.Services.AddSingleton(_ => new CosmosClient(cosmosConnectionString, new CosmosClientOptions
{
    SerializerOptions = new CosmosSerializationOptions
    {
        PropertyNamingPolicy = CosmosPropertyNamingPolicy.CamelCase
    },
    ConnectionMode = isLocal ? ConnectionMode.Gateway : ConnectionMode.Direct
}));

// Service registrations (interface → Cosmos implementation)
builder.Services.AddScoped<IQuestionService, CosmosQuestionService>();
builder.Services.AddScoped<ISubmitResultService, CosmosSubmitResultService>();
builder.Services.AddScoped<IWordbookService, CosmosWordbookService>();
builder.Services.AddScoped<IReportService, CosmosReportService>();
builder.Services.AddScoped<IDictionaryService, DictionaryService>();

// Admin services for textbook import & AI analysis
builder.Services.AddScoped<ITextbookService, CosmosTextbookService>();
builder.Services.AddSingleton<IDocumentIntelligenceService, AzureDocumentIntelligenceService>();
builder.Services.AddSingleton<ITextbookAnalyzerService, OpenAITextbookAnalyzerService>();
builder.Services.AddSingleton<OpenAIQuestionGeneratorService>();
builder.Services.AddSingleton<IQuestionGeneratorService>(sp => sp.GetRequiredService<OpenAIQuestionGeneratorService>());

// Background job service for full-book generation
builder.Services.AddSingleton<FullBookJobService>();
builder.Services.AddHostedService(sp => sp.GetRequiredService<FullBookJobService>());

// JSON serialization — HttpJsonOptions defaults to JsonSerializerDefaults.Web
// (camelCase + case-insensitive read). We add further customizations:
builder.Services.ConfigureHttpJsonOptions(options =>
{
    // PropertyNamingPolicy already CamelCase via Web defaults
    options.SerializerOptions.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
    options.SerializerOptions.Converters.Add(new JsonStringEnumConverter(JsonNamingPolicy.CamelCase));
});

builder.Services.AddOpenApi();

var app = builder.Build();
app.MapDefaultEndpoints();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference(options =>
    {
        options.WithTitle("Volingo API")
               .WithDefaultHttpClient(ScalarTarget.CSharp, ScalarClient.HttpClient);
    });
}

// Initialize Cosmos DB: create database & containers
await app.InitializeCosmosDbAsync(databaseName);

// ── Root ──
app.MapGet("/", () => Results.Ok(new { service = "Volingo API", version = "1.0.0", status = "running" }));

// ── Volingo API endpoints (8 endpoints) ──
app.MapVolingoEndpoints();

// ── Admin endpoints for textbook import & management ──
app.UseStaticFiles();
app.MapAdminEndpoints();

// ── Cosmos DB status ──
app.MapGet("/api/v1/db/status", async (CosmosClient cosmos) =>
{
    try
    {
        var db = cosmos.GetDatabase(databaseName);
        await db.ReadAsync();

        var containers = new List<string>();
        using var iterator = db.GetContainerQueryIterator<ContainerProperties>();
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            containers.AddRange(response.Select(c => c.Id));
        }

        return Results.Ok(new
        {
            status = "connected",
            database = databaseName,
            endpoint = cosmos.Endpoint.ToString(),
            containers
        });
    }
    catch (Exception ex)
    {
        return Results.Json(new { status = "error", message = ex.Message }, statusCode: 500);
    }
});

app.Run();
