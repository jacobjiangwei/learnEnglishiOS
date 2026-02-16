using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Azure.Cosmos;
using Scalar.AspNetCore;
using Volingo.Api.Extensions;
using Volingo.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// Aspire service defaults (health checks, telemetry, resilience)
builder.AddServiceDefaults();

// Mock data service (in-memory, singleton)
builder.Services.AddSingleton<MockDataService>();

// Cosmos DB — manual registration (emulator uses Gateway mode)
var cosmosConnectionString = builder.Configuration.GetConnectionString("cosmos");
var databaseName = builder.Configuration["CosmosDb:DatabaseName"] ?? "volingo";

if (!string.IsNullOrEmpty(cosmosConnectionString))
{
    var isLocal = cosmosConnectionString.Contains("localhost");
    builder.Services.AddSingleton(_ => new CosmosClient(cosmosConnectionString, new CosmosClientOptions
    {
        SerializerOptions = new CosmosSerializationOptions
        {
            PropertyNamingPolicy = CosmosPropertyNamingPolicy.CamelCase
        },
        ConnectionMode = isLocal ? ConnectionMode.Gateway : ConnectionMode.Direct
    }));
}

// JSON serialization
builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
    options.SerializerOptions.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
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

// Initialize Cosmos DB: create database & containers if not exist
if (!string.IsNullOrEmpty(cosmosConnectionString))
{
    await app.InitializeCosmosDbAsync(databaseName);
}

// ── Root ──
app.MapGet("/", () => Results.Ok(new { service = "Volingo API", version = "1.0.0", status = "running" }));

// ── Volingo API endpoints (8 endpoints) ──
app.MapVolingoEndpoints();

// ── Cosmos DB status (only if Cosmos is configured) ──
if (!string.IsNullOrEmpty(cosmosConnectionString))
{
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
}

app.Run();
