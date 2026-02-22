using System.Text;
using System.Text.Json;
using Microsoft.Azure.Cosmos;
using Volingo.Api.Models;
using Volingo.Api.Services;

namespace Volingo.Api.Extensions;

/// <summary>
/// Maps all Admin API endpoints for textbook import, parsing, and management.
/// Endpoints: /api/v1/admin/...
/// </summary>
public static class AdminEndpoints
{
    public static WebApplication MapAdminEndpoints(this WebApplication app)
    {
        // ── Catalog: list textbook series ──
        app.MapGet("/api/v1/admin/textbooks", () =>
        {
            var result = TextbookCatalog.TextbookOptions.Select(kv => new TextbookSeriesInfo(
                kv.Key, kv.Value, TextbookCatalog.GradeSyncSeries.Contains(kv.Key)
            )).ToList();
            return Results.Ok(result);
        })
        .WithName("AdminListTextbooks")
        .WithTags("Admin");

        // ── Catalog: list volumes for a series ──
        app.MapGet("/api/v1/admin/textbooks/{seriesCode}/volumes", (string seriesCode) =>
        {
            if (!TextbookCatalog.TextbookOptions.ContainsKey(seriesCode))
                return Results.NotFound(new { detail = $"Unknown series: {seriesCode}" });
            return Results.Ok(TextbookCatalog.GetAllVolumes(seriesCode));
        })
        .WithName("AdminListVolumes")
        .WithTags("Admin");

        // ── Documents: list imported documents ──
        app.MapGet("/api/v1/admin/documents", async (ITextbookService textbooks) =>
        {
            var docs = await textbooks.ListDocumentsAsync();
            return Results.Ok(docs);
        })
        .WithName("AdminListDocuments")
        .WithTags("Admin");

        // ── Documents: get single document ──
        app.MapGet("/api/v1/admin/documents/{docId}", async (
            ITextbookService textbooks, string docId, string textbook) =>
        {
            var doc = await textbooks.GetDocumentAsync(docId, textbook);
            return doc is null ? Results.NotFound(new { detail = $"Document not found: {docId}" }) : Results.Ok(doc);
        })
        .WithName("AdminGetDocument")
        .WithTags("Admin");

        // ── Extract: upload PDF → Azure Doc Intelligence → Markdown preview ──
        app.MapPost("/api/v1/admin/extract", async (
            IDocumentIntelligenceService docIntel, HttpRequest request) =>
        {
            if (!request.HasFormContentType)
                return Results.BadRequest(new { detail = "Content-Type must be multipart/form-data." });

            var form = await request.ReadFormAsync();
            var file = form.Files.GetFile("file");
            if (file is null || !file.FileName.EndsWith(".pdf", StringComparison.OrdinalIgnoreCase))
                return Results.BadRequest(new { detail = "Please upload a PDF file." });

            try
            {
                using var stream = file.OpenReadStream();
                var result = await docIntel.ExtractPdfAsync(stream, file.FileName);
                return Results.Ok(result);
            }
            catch (Exception ex)
            {
                return Results.Problem(detail: $"Azure Doc Intelligence extraction failed: {ex.Message}", statusCode: 500);
            }
        })
        .WithName("AdminExtractPdf")
        .WithTags("Admin")
        .DisableAntiforgery();

        // ── Save: store extracted content to Cosmos DB ──
        app.MapPost("/api/v1/admin/save", async (ITextbookService textbooks, SaveTextbookRequest request) =>
        {
            try
            {
                var result = await textbooks.SaveDocumentAsync(request);
                return Results.Ok(result);
            }
            catch (ArgumentException ex)
            {
                return Results.BadRequest(new { detail = ex.Message });
            }
        })
        .WithName("AdminSaveTextbook")
        .WithTags("Admin");

        // ── Analyze: run GPT-4o analysis on an imported document ──
        app.MapPost("/api/v1/admin/analyze/{docId}", async (
            ITextbookService textbooks, ITextbookAnalyzerService analyzer,
            string docId, string textbook) =>
        {
            var doc = await textbooks.GetDocumentAsync(docId, textbook);
            if (doc is null)
                return Results.NotFound(new { detail = $"Document not found: {docId}" });
            if (string.IsNullOrEmpty(doc.RawContent))
                return Results.BadRequest(new { detail = "Document has no rawContent to analyze." });

            try
            {
                var analysis = await analyzer.AnalyzeAsync(doc.RawContent, doc.DisplayName);
                await textbooks.SaveAnalysisAsync(docId, textbook, analysis);

                return Results.Ok(new AnalyzeResult(true, docId, doc.DisplayName, analysis.Units.Count, analysis));
            }
            catch (Exception ex)
            {
                return Results.Problem(detail: $"AI analysis failed: {ex.Message}", statusCode: 500);
            }
        })
        .WithName("AdminAnalyzeDocument")
        .WithTags("Admin");

        // ── Get analysis result ──
        app.MapGet("/api/v1/admin/documents/{docId}/analysis", async (
            ITextbookService textbooks, string docId, string textbook) =>
        {
            var doc = await textbooks.GetDocumentAsync(docId, textbook);
            if (doc is null)
                return Results.NotFound(new { detail = $"Document not found: {docId}" });
            if (doc.Analysis is null)
                return Results.Ok(new { hasAnalysis = false, id = docId });

            return Results.Ok(new
            {
                hasAnalysis = true,
                id = docId,
                displayName = doc.DisplayName,
                analysisUpdatedAt = doc.AnalysisUpdatedAt,
                analysis = doc.Analysis,
            });
        })
        .WithName("AdminGetAnalysis")
        .WithTags("Admin");

        // ── Delete document ──
        app.MapDelete("/api/v1/admin/documents/{docId}", async (
            ITextbookService textbooks, string docId, string textbook) =>
        {
            var deleted = await textbooks.DeleteDocumentAsync(docId, textbook);
            return deleted
                ? Results.Ok(new { success = true, id = docId })
                : Results.NotFound(new { detail = $"Document not found: {docId}" });
        })
        .WithName("AdminDeleteDocument")
        .WithTags("Admin");

        // ── Serve Admin UI ──
        app.MapGet("/admin", (IWebHostEnvironment env) =>
        {
            // Try wwwroot in content root first, then base directory
            var contentRoot = Path.Combine(env.ContentRootPath, "wwwroot", "admin.html");
            var basePath = Path.Combine(AppContext.BaseDirectory, "wwwroot", "admin.html");
            var filePath = File.Exists(contentRoot) ? contentRoot : basePath;

            if (!File.Exists(filePath))
                return Results.NotFound(new { detail = "admin.html not found" });

            return Results.File(filePath, "text/html");
        })
        .WithName("AdminUI")
        .WithTags("Admin")
        .ExcludeFromDescription();

        // ── Generate questions for a unit + question type ──
        app.MapPost("/api/v1/admin/generate-questions", async (
            ITextbookService textbooks,
            IQuestionGeneratorService generator,
            GenerateQuestionsApiRequest request) =>
        {
            if (!QuestionTypes.IsValid(request.QuestionType))
                return Results.BadRequest(new { detail = $"未知题型: {request.QuestionType}" });

            // Load the document
            var doc = await textbooks.GetDocumentAsync(request.DocId, request.Textbook);
            if (doc?.Analysis is null)
                return Results.BadRequest(new { detail = "文档不存在或未完成分析" });

            var unit = doc.Analysis.Units.FirstOrDefault(u => u.UnitNumber == request.UnitNumber);
            if (unit is null)
                return Results.BadRequest(new { detail = $"单元 {request.UnitNumber} 不存在" });

            // Determine level from textbookCode
            var level = ResolveLevelFromTextbookCode(request.DocId);

            var genRequest = new GenerateQuestionsRequest(
                TextbookCode: request.DocId,
                DisplayName: doc.DisplayName,
                Level: level,
                UnitNumber: request.UnitNumber,
                Unit: unit,
                Glossary: doc.Analysis.VocabularyGlossary,
                QuestionType: request.QuestionType
            );

            try
            {
                var questions = await generator.GenerateQuestionsAsync(genRequest);
                return Results.Ok(new
                {
                    success = true,
                    textbookCode = request.DocId,
                    unitNumber = request.UnitNumber,
                    questionType = request.QuestionType,
                    count = questions.Count,
                    questions
                });
            }
            catch (Exception ex)
            {
                return Results.Problem(detail: $"出题失败: {ex.Message}", statusCode: 500);
            }
        })
        .WithName("AdminGenerateQuestions")
        .WithTags("Admin");

        // ── Eval: AI quality check on generated questions ──
        app.MapPost("/api/v1/admin/eval-questions", async (
            OpenAIQuestionGeneratorService evaluator,
            EvalQuestionsRequest request) =>
        {
            if (request.Questions is null || request.Questions.Count == 0)
                return Results.BadRequest(new { detail = "没有题目可以评审" });

            if (string.IsNullOrEmpty(request.QuestionType) || !QuestionTypes.IsValid(request.QuestionType))
                return Results.BadRequest(new { detail = $"请指定有效的题型" });

            try
            {
                var results = await evaluator.EvalQuestionsAsync(request.Questions, request.QuestionType);
                return Results.Ok(new
                {
                    success = true,
                    questionType = request.QuestionType,
                    total = request.Questions.Count,
                    passed = results.Count(r => r.Pass),
                    failed = results.Count(r => !r.Pass),
                    results
                });
            }
            catch (Exception ex)
            {
                return Results.Problem(detail: $"质检失败: {ex.Message}", statusCode: 500);
            }
        })
        .WithName("AdminEvalQuestions")
        .WithTags("Admin");

        // ── Commit generated questions to Cosmos DB ──
        app.MapPost("/api/v1/admin/commit-questions", async (
            CosmosClient cosmos,
            IConfiguration config,
            CommitQuestionsRequest request) =>
        {
            if (request.Questions is null || request.Questions.Count == 0)
                return Results.BadRequest(new { detail = "没有题目可以入库" });

            var dbName = config["CosmosDb:DatabaseName"] ?? "volingo";
            var container = cosmos.GetContainer(dbName, "questions");

            int committed = 0;
            var errors = new List<string>();

            foreach (var q in request.Questions)
            {
                try
                {
                    // Ensure id and textbookCode exist
                    if (!q.ContainsKey("id"))
                        q["id"] = Guid.NewGuid().ToString();
                    if (!q.TryGetValue("textbookCode", out var tbObj) || tbObj is null)
                    {
                        errors.Add("题目缺少 textbookCode");
                        continue;
                    }

                    var textbookCode = tbObj.ToString()!;

                    // Shuffle options so correct answer position is random
                    OpenAIQuestionGeneratorService.ShuffleOptions(q);

                    var json = JsonSerializer.Serialize(q);
                    using var stream = new MemoryStream(Encoding.UTF8.GetBytes(json));
                    await container.UpsertItemStreamAsync(stream, new PartitionKey(textbookCode));
                    committed++;
                }
                catch (Exception ex)
                {
                    errors.Add($"题目入库失败: {ex.Message}");
                }
            }

            return Results.Ok(new
            {
                success = true,
                committed,
                total = request.Questions.Count,
                errors = errors.Count > 0 ? errors : null
            });
        })
        .WithName("AdminCommitQuestions")
        .WithTags("Admin");

        return app;
    }

    /// <summary>
    /// Map textbookCode to UserLevel display name.
    /// e.g. "primaryPEP-3a" → "小学三年级", "juniorPEP-8b" → "初二"
    /// </summary>
    private static string ResolveLevelFromTextbookCode(string textbookCode)
    {
        // Non-grade-sync series
        var nonGradeMap = new Dictionary<string, string>
        {
            ["collegeCet4"] = "四级", ["collegeCet6"] = "六级",
            ["graduateExam"] = "考研", ["preschoolPhonics"] = "启蒙",
            ["cefr"] = "CEFR", ["cambridge"] = "剑桥",
            ["longman"] = "朗文", ["ielts"] = "IELTS", ["toefl"] = "TOEFL",
        };

        foreach (var (prefix, level) in nonGradeMap)
        {
            if (textbookCode == prefix) return level;
        }

        // Grade-sync series: extract grade number from "seriesCode-{grade}{a|b}"
        var dashIdx = textbookCode.LastIndexOf('-');
        if (dashIdx < 0) return textbookCode;

        var volPart = textbookCode[(dashIdx + 1)..];
        var gradeStr = new string(volPart.TakeWhile(char.IsDigit).ToArray());
        if (!int.TryParse(gradeStr, out var grade)) return textbookCode;

        return grade switch
        {
            >= 1 and <= 6 => $"小学{GradeChinese(grade)}年级",
            7 => "初一",
            8 => "初二",
            9 => "初三",
            10 => "高一",
            11 => "高二",
            12 => "高三",
            _ => $"{grade}年级"
        };
    }

    private static string GradeChinese(int n) => n switch
    {
        1 => "一", 2 => "二", 3 => "三",
        4 => "四", 5 => "五", 6 => "六",
        _ => n.ToString()
    };
}

// ── Request DTOs ──

public record GenerateQuestionsApiRequest(
    string DocId,
    string Textbook,
    int UnitNumber,
    string QuestionType
);

public record EvalQuestionsRequest(
    List<Dictionary<string, object>> Questions,
    string QuestionType
);

public record CommitQuestionsRequest(
    List<Dictionary<string, object>> Questions
);
