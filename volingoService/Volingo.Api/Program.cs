using System.Text.Json;
using System.Text.Json.Serialization;
using Volingo.Api.Models;
using Volingo.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// Add Aspire service defaults (health checks, telemetry, resilience)
builder.AddServiceDefaults();

// Configure JSON serialization
builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
    options.SerializerOptions.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
});

builder.Services.AddOpenApi();
builder.Services.AddSingleton<QuestionService>();

var app = builder.Build();

// Aspire health/alive endpoints
app.MapDefaultEndpoints();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

// ── Middleware: Extract X-Device-Id ──
app.Use(async (context, next) =>
{
    var path = context.Request.Path.Value ?? "";
    if (path.StartsWith("/health") || path.StartsWith("/alive") || path.StartsWith("/openapi"))
    {
        await next();
        return;
    }

    if (path.StartsWith("/api/"))
    {
        var deviceId = context.Request.Headers["X-Device-Id"].FirstOrDefault();
        if (string.IsNullOrWhiteSpace(deviceId))
        {
            context.Response.StatusCode = 400;
            context.Response.ContentType = "application/json";
            await context.Response.WriteAsJsonAsync(ApiResponse.Error(400, "Missing X-Device-Id header"));
            return;
        }
        context.Items["DeviceId"] = deviceId;
    }

    await next();
});

// ── Root ──
app.MapGet("/", () => Results.Ok(new { service = "Volingo API", version = "1.0.0", status = "running" }));

// ── 3.1 Practice Questions ──
app.MapGet("/api/v1/practice/questions", (string type, string textbookCode, int? count, QuestionService svc) =>
{
    var n = count ?? 5;

    if (type == "reading")
    {
        var passages = svc.GetReadingQuestions(textbookCode, n);
        return Results.Ok(ApiResponse.Success(new
        {
            questionType = type,
            textbookCode,
            passages
        }));
    }

    var questions = svc.GetQuestionsByType(type, textbookCode, n);
    return Results.Ok(ApiResponse.Success(new
    {
        questionType = type,
        textbookCode,
        questions
    }));
});

// ── 3.2 Today Package ──
app.MapGet("/api/v1/practice/today-package", (string textbookCode, QuestionService svc) =>
{
    var package = svc.GetTodayPackage(textbookCode);
    return Results.Ok(ApiResponse.Success(package));
});

// ── 3.3 Home Progress ──
app.MapGet("/api/v1/user/home-progress", (HttpContext ctx, QuestionService svc) =>
{
    var deviceId = ctx.Items["DeviceId"]?.ToString() ?? "";
    var progress = svc.GetHomeProgress(deviceId);
    return Results.Ok(ApiResponse.Success(progress));
});

// ── 4.1 Submit Answer ──
app.MapPost("/api/v1/practice/submit", (SubmitAnswerRequest req) =>
{
    var response = new SubmitAnswerResponse
    {
        Correct = true,
        Score = 100,
        Feedback = "回答正确！",
        CorrectAnswer = new Dictionary<string, object> { ["selectedIndex"] = 1 }
    };
    return Results.Ok(ApiResponse.Success(response));
});

// ── 4.2 Report Question ──
app.MapPost("/api/v1/practice/report", (ReportRequest req) =>
{
    var response = new ReportResponse
    {
        ReportId = $"rpt-{Guid.NewGuid()}"
    };
    return Results.Ok(ApiResponse.Success(response));
});

// ── 0.2 Merge Device ──
app.MapPost("/api/v1/auth/merge-device", (MergeDeviceRequest req) =>
{
    var response = new MergeDeviceResponse
    {
        MergedRecords = 0,
        Message = "设备数据已合并到您的账号"
    };
    return Results.Ok(ApiResponse.Success(response));
});

app.Run();
