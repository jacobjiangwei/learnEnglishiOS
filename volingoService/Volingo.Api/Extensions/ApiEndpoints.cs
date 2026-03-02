using System.Security.Claims;
using Volingo.Api.Models;
using Volingo.Api.Services;

namespace Volingo.Api.Extensions;

/// <summary>
/// Maps all 海豹英语 API endpoints (8 endpoints total).
/// All authenticated endpoints extract userId from JWT claims.
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
            var userId = GetUserId(ctx);
            if (userId is null) return UnauthorizedResult();

            var completedIds = await submits.GetCompletedIdsAsync(userId);
            var (questionList, remaining) = await questions.GetQuestionsAsync(
                textbookCode, questionType, count ?? 5, completedIds);

            if (questionType == "reading")
                return Results.Ok(new ReadingQuestionsResponse(questionType, textbookCode, remaining, questionList));

            return Results.Ok(new QuestionsResponse(questionType, textbookCode, remaining, questionList));
        })
        .RequireAuthorization()
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
            var userId = GetUserId(ctx);
            if (userId is null) return UnauthorizedResult();

            var stats = await submitService.GetStatsAsync(userId, days ?? 365);
            return Results.Ok(stats);
        })
        .RequireAuthorization()
        .WithName("GetUserStats")
        .WithTags("User");

        // ── 4.1 提交答案（批量） ──
        app.MapPost("/api/v1/practice/submit", async (HttpContext ctx,
            ISubmitResultService submitService, SubmitRequest request) =>
        {
            var userId = GetUserId(ctx);
            if (userId is null) return UnauthorizedResult();

            await submitService.SubmitAsync(userId, request);
            return Results.NoContent();
        })
        .RequireAuthorization()
        .WithName("SubmitAnswer")
        .WithTags("Practice");

        // ── 4.2 投诉错误题目 ──
        app.MapPost("/api/v1/practice/report", async (IReportService reports, ReportRequest request) =>
        {
            var doc = await reports.ReportAsync(request);
            return Results.Ok(new ReportResponse(doc.Id, doc.ReportCount));
        })
        .WithName("ReportQuestion")
        .WithTags("Practice");

        // ── 5.1 添加生词 ──
        app.MapPost("/api/v1/wordbook/add", async (HttpContext ctx, IWordbookService wordbook, WordbookAddRequest request) =>
        {
            var userId = GetUserId(ctx);
            if (userId is null) return UnauthorizedResult();

            var entry = await wordbook.AddWordAsync(userId, request);
            return Results.Ok(entry);
        })
        .RequireAuthorization()
        .WithName("AddWord")
        .WithTags("Wordbook");

        // ── 5.2 删除生词 ──
        app.MapDelete("/api/v1/wordbook/{wordId}", async (HttpContext ctx, IWordbookService wordbook, string wordId) =>
        {
            var userId = GetUserId(ctx);
            if (userId is null) return UnauthorizedResult();

            var deleted = await wordbook.DeleteWordAsync(userId, wordId);
            if (!deleted) return Results.Problem(detail: "Word not found.", statusCode: 404, title: "Not Found");

            return Results.NoContent();
        })
        .RequireAuthorization()
        .WithName("DeleteWord")
        .WithTags("Wordbook");

        // ── 5.3 获取生词列表（全量） ──
        app.MapGet("/api/v1/wordbook/list", async (HttpContext ctx, IWordbookService wordbook) =>
        {
            var userId = GetUserId(ctx);
            if (userId is null) return UnauthorizedResult();

            var list = await wordbook.GetWordbookAsync(userId);
            return Results.Ok(list);
        })
        .RequireAuthorization()
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

    /// <summary>
    /// Extract userId from JWT ClaimTypes.NameIdentifier.
    /// </summary>
    private static string? GetUserId(HttpContext ctx)
        => ctx.User.FindFirstValue(ClaimTypes.NameIdentifier);

    private static IResult UnauthorizedResult() =>
        Results.Problem(
            detail: "Authentication required.",
            statusCode: 401,
            title: "Unauthorized");
}
