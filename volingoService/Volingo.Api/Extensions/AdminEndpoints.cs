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

        return app;
    }
}
