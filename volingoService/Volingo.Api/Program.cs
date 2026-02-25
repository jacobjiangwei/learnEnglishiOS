using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Azure.Cosmos;
using Microsoft.IdentityModel.Tokens;
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

// ── Authentication: RS256 JWT ──
var rsaKey = RSA.Create();
var privateKeyPath = builder.Configuration["Jwt:PrivateKeyPath"];
if (!string.IsNullOrEmpty(privateKeyPath) && File.Exists(privateKeyPath))
{
    rsaKey.ImportFromPem(File.ReadAllText(privateKeyPath));
}
else
{
    // Fallback: generate ephemeral key for development (tokens won't survive restart)
    rsaKey = RSA.Create(2048);
    var logger = LoggerFactory.Create(b => b.AddConsole()).CreateLogger("Startup");
    logger.LogWarning("No RSA key file found at '{Path}'. Using ephemeral key — tokens will not survive restart.", privateKeyPath);
}
var signingKey = new RsaSecurityKey(rsaKey);
builder.Services.AddSingleton(signingKey);

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        var jwtConfig = builder.Configuration.GetSection("Jwt");
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwtConfig["Issuer"] ?? "volingo",
            ValidateAudience = true,
            ValidAudience = jwtConfig["Audience"] ?? "volingo-api",
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(1),
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = signingKey
        };
    });

builder.Services.AddAuthorization();

// ── Auth services ──
builder.Services.AddSingleton<IJwtTokenService, JwtTokenService>();
builder.Services.AddScoped<IAuthService, AuthService>();

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
        options.WithTitle("海豹英语 API")
               .WithDefaultHttpClient(ScalarTarget.CSharp, ScalarClient.HttpClient);
    });
}

// Initialize Cosmos DB: create database & containers
await app.InitializeCosmosDbAsync(databaseName);

app.UseAuthentication();
app.UseAuthorization();

// ── Root ──
app.MapGet("/", () => Results.Ok(new { service = "海豹英语 API", version = "1.0.0", status = "running" }));

// ── Auth endpoints ──
app.MapAuthEndpoints();

// ── 海豹英语 API endpoints (8 endpoints) ──
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
