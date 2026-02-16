using Volingo.Api.Models;
using Volingo.Api.Services;

namespace Volingo.Api.Extensions;

/// <summary>
/// Maps all Volingo API endpoints (8 endpoints total).
/// All use X-Device-Id header for user identification.
/// </summary>
public static class ApiEndpoints
{
    private static readonly ErrorResponse MissingDeviceId = new("Missing X-Device-Id header");

    public static WebApplication MapVolingoEndpoints(this WebApplication app)
    {
        // ── 3.1 获取练习题组 ──
        app.MapGet("/api/v1/practice/questions", (HttpContext ctx, MockDataService mock,
            string questionType, string textbookCode, int? count) =>
        {
            var deviceId = GetDeviceId(ctx);
            if (deviceId is null) return Results.Json(MissingDeviceId, statusCode: 400);

            var (questions, remaining) = mock.GetQuestions(deviceId, textbookCode, questionType, count ?? 5);

            // 阅读理解用 passages 而非 questions（文档 §3.1）
            if (questionType == "reading")
                return Results.Ok(new ReadingQuestionsResponse(questionType, textbookCode, remaining, questions));

            return Results.Ok(new QuestionsResponse(questionType, textbookCode, remaining, questions));
        })
        .WithName("GetQuestions")
        .WithTags("Practice");

        // ── 3.2 今日推荐套餐 ──
        app.MapGet("/api/v1/practice/today-package", (HttpContext ctx, MockDataService mock,
            string textbookCode) =>
        {
            var deviceId = GetDeviceId(ctx);
            if (deviceId is null) return Results.Json(MissingDeviceId, statusCode: 400);

            var package = mock.GetTodayPackage(deviceId, textbookCode);

            return Results.Ok(package);
        })
        .WithName("GetTodayPackage")
        .WithTags("Practice");

        // ── 3.3 学习统计 ──
        app.MapGet("/api/v1/user/stats", (HttpContext ctx, MockDataService mock, int? days) =>
        {
            var deviceId = GetDeviceId(ctx);
            if (deviceId is null) return Results.Json(MissingDeviceId, statusCode: 400);

            var stats = mock.GetStats(deviceId, days ?? 365);

            return Results.Ok(stats);
        })
        .WithName("GetUserStats")
        .WithTags("User");

        // ── 4.1 提交答案（批量） ──
        app.MapPost("/api/v1/practice/submit", (HttpContext ctx, MockDataService mock, SubmitRequest request) =>
        {
            var deviceId = GetDeviceId(ctx);
            if (deviceId is null) return Results.Json(MissingDeviceId, statusCode: 400);

            mock.Submit(deviceId, request);

            return Results.NoContent();
        })
        .WithName("SubmitAnswer")
        .WithTags("Practice");

        // ── 4.2 投诉错误题目 ──
        app.MapPost("/api/v1/practice/report", (HttpContext ctx, MockDataService mock, ReportRequest request) =>
        {
            var deviceId = GetDeviceId(ctx);
            if (deviceId is null) return Results.Json(MissingDeviceId, statusCode: 400);

            var reportId = mock.Report(deviceId, request);

            return Results.Ok(new ReportResponse(reportId));
        })
        .WithName("ReportQuestion")
        .WithTags("Practice");

        // ── 5.1 添加生词 ──
        app.MapPost("/api/v1/wordbook/add", (HttpContext ctx, MockDataService mock, WordbookAddRequest request) =>
        {
            var deviceId = GetDeviceId(ctx);
            if (deviceId is null) return Results.Json(MissingDeviceId, statusCode: 400);

            var entry = mock.AddWord(deviceId, request);

            return Results.Ok(entry);
        })
        .WithName("AddWord")
        .WithTags("Wordbook");

        // ── 5.2 删除生词 ──
        app.MapDelete("/api/v1/wordbook/{wordId}", (HttpContext ctx, MockDataService mock, string wordId) =>
        {
            var deviceId = GetDeviceId(ctx);
            if (deviceId is null) return Results.Json(MissingDeviceId, statusCode: 400);

            var deleted = mock.DeleteWord(deviceId, wordId);
            if (!deleted) return Results.NotFound(new ErrorResponse("Word not found"));

            return Results.NoContent();
        })
        .WithName("DeleteWord")
        .WithTags("Wordbook");

        // ── 5.3 获取生词列表（全量） ──
        app.MapGet("/api/v1/wordbook/list", (HttpContext ctx, MockDataService mock) =>
        {
            var deviceId = GetDeviceId(ctx);
            if (deviceId is null) return Results.Json(MissingDeviceId, statusCode: 400);

            var list = mock.GetWordbook(deviceId);

            return Results.Ok(list);
        })
        .WithName("GetWordbook")
        .WithTags("Wordbook");

        return app;
    }

    private static string? GetDeviceId(HttpContext ctx)
    {
        return ctx.Request.Headers.TryGetValue("X-Device-Id", out var value) ? value.ToString() : null;
    }
}
