using Volingo.Api.Models;
using Volingo.Api.Services;

namespace Volingo.Api.Extensions;

/// <summary>
/// Maps all Volingo API endpoints (8 endpoints total).
/// All use X-Device-Id header for user identification.
/// </summary>
public static class ApiEndpoints
{
    public static WebApplication MapVolingoEndpoints(this WebApplication app)
    {

        // ── 3.1 获取练习题组 ──
        app.MapGet("/api/v1/practice/questions", async (HttpContext ctx,
            IQuestionService questions, ISubmitResultService submits,
            string questionType, string textbookCode, int? count) =>
        {
            var deviceId = GetDeviceId(ctx);
            if (deviceId is null) return MissingDeviceIdResult();

            var completedIds = await submits.GetCompletedIdsAsync(deviceId);
            var (questionList, remaining) = await questions.GetQuestionsAsync(
                textbookCode, questionType, count ?? 5, completedIds);

            if (questionType == "reading")
                return Results.Ok(new ReadingQuestionsResponse(questionType, textbookCode, remaining, questionList));

            return Results.Ok(new QuestionsResponse(questionType, textbookCode, remaining, questionList));
        })
        .WithName("GetQuestions")
        .WithTags("Practice");

        // ── 3.2 今日推荐套餐（全等级统一，懒生成，中国时间） ──
        app.MapGet("/api/v1/practice/today-package", async (
            IQuestionService questions, string textbookCode) =>
        {
            var package = await questions.GetTodayPackageAsync(textbookCode);
            return Results.Ok(package);
        })
        .WithName("GetTodayPackage")
        .WithTags("Practice");

        // ── 3.3 学习统计 ──
        app.MapGet("/api/v1/user/stats", async (HttpContext ctx, ISubmitResultService submitService, int? days) =>
        {
            var deviceId = GetDeviceId(ctx);
            if (deviceId is null) return MissingDeviceIdResult();

            var stats = await submitService.GetStatsAsync(deviceId, days ?? 365);
            return Results.Ok(stats);
        })
        .WithName("GetUserStats")
        .WithTags("User");

        // ── 4.1 提交答案（批量） ──
        app.MapPost("/api/v1/practice/submit", async (HttpContext ctx,
            ISubmitResultService submitService, SubmitRequest request) =>
        {
            var deviceId = GetDeviceId(ctx);
            if (deviceId is null) return MissingDeviceIdResult();

            await submitService.SubmitAsync(deviceId, request);
            return Results.NoContent();
        })
        .WithName("SubmitAnswer")
        .WithTags("Practice");

        // ── 4.2 投诉错误题目 ──
        app.MapPost("/api/v1/practice/report", async (HttpContext ctx, IReportService reports, ReportRequest request) =>
        {
            var deviceId = GetDeviceId(ctx);
            if (deviceId is null) return MissingDeviceIdResult();

            var reportId = await reports.ReportAsync(deviceId, request);
            return Results.Ok(new ReportResponse(reportId));
        })
        .WithName("ReportQuestion")
        .WithTags("Practice");

        // ── 5.1 添加生词 ──
        app.MapPost("/api/v1/wordbook/add", async (HttpContext ctx, IWordbookService wordbook, WordbookAddRequest request) =>
        {
            var deviceId = GetDeviceId(ctx);
            if (deviceId is null) return MissingDeviceIdResult();

            var entry = await wordbook.AddWordAsync(deviceId, request);
            return Results.Ok(entry);
        })
        .WithName("AddWord")
        .WithTags("Wordbook");

        // ── 5.2 删除生词 ──
        app.MapDelete("/api/v1/wordbook/{wordId}", async (HttpContext ctx, IWordbookService wordbook, string wordId) =>
        {
            var deviceId = GetDeviceId(ctx);
            if (deviceId is null) return MissingDeviceIdResult();

            var deleted = await wordbook.DeleteWordAsync(deviceId, wordId);
            if (!deleted) return Results.Problem(detail: "Word not found.", statusCode: 404, title: "Not Found");

            return Results.NoContent();
        })
        .WithName("DeleteWord")
        .WithTags("Wordbook");

        // ── 5.3 获取生词列表（全量） ──
        app.MapGet("/api/v1/wordbook/list", async (HttpContext ctx, IWordbookService wordbook) =>
        {
            var deviceId = GetDeviceId(ctx);
            if (deviceId is null) return MissingDeviceIdResult();

            var list = await wordbook.GetWordbookAsync(deviceId);
            return Results.Ok(list);
        })
        .WithName("GetWordbook")
        .WithTags("Wordbook");

        // ── 6.1 词典查询 ──
        app.MapGet("/api/v1/dictionary/{word}", async (IDictionaryService dictionary, string word) =>
        {
            try
            {
                var entry = await dictionary.LookupAsync(word);
                return Results.Ok(entry);
            }
            catch (WordNotFoundException)
            {
                return Results.Problem(detail: $"'{word}' is not a recognized English word.", statusCode: 404, title: "Word Not Found");
            }
            catch (ArgumentException)
            {
                return Results.Problem(detail: "Word parameter is invalid.", statusCode: 400, title: "Bad Request");
            }
        })
        .WithName("LookupWord")
        .WithTags("Dictionary");

        return app;
    }

    private static string? GetDeviceId(HttpContext ctx)
    {
        return ctx.Request.Headers.TryGetValue("X-Device-Id", out var value) ? value.ToString() : null;
    }

    /// <summary>
    /// Return RFC 7807 Problem Details for missing X-Device-Id.
    /// Uses Results.Problem() for standardized error format.
    /// </summary>
    private static IResult MissingDeviceIdResult() =>
        Results.Problem(
            detail: "X-Device-Id header is required.",
            statusCode: 400,
            title: "Missing Device ID");
}
