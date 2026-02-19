using Azure;
using Azure.AI.DocumentIntelligence;
using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Azure Document Intelligence implementation — uses prebuilt-layout model
/// to extract Markdown from uploaded PDFs.
/// </summary>
public class AzureDocumentIntelligenceService(IConfiguration config, ILogger<AzureDocumentIntelligenceService> logger)
    : IDocumentIntelligenceService
{
    private DocumentIntelligenceClient? _client;

    private DocumentIntelligenceClient GetClient()
    {
        if (_client is not null) return _client;

        var endpoint = config["DocumentIntelligence:Endpoint"]
            ?? throw new InvalidOperationException("DocumentIntelligence:Endpoint not configured.");
        var key = config["DocumentIntelligence:Key"]
            ?? throw new InvalidOperationException("DocumentIntelligence:Key not configured.");

        _client = new DocumentIntelligenceClient(new Uri(endpoint), new AzureKeyCredential(key));
        return _client;
    }

    public async Task<ExtractResult> ExtractPdfAsync(Stream pdfStream, string filename)
    {
        var client = GetClient();
        var sizeMb = pdfStream.Length / (1024.0 * 1024.0);
        logger.LogInformation("Extracting PDF: {Filename} ({Size:F1} MB)", filename, sizeMb);

        // Read stream to BinaryData
        using var ms = new MemoryStream();
        await pdfStream.CopyToAsync(ms);
        var binaryData = BinaryData.FromBytes(ms.ToArray());

        // Use the AnalyzeDocumentOptions overload for markdown output
        var options = new AnalyzeDocumentOptions("prebuilt-layout", binaryData)
        {
            OutputContentFormat = DocumentContentFormat.Markdown,
        };

        var operation = await client.AnalyzeDocumentAsync(WaitUntil.Completed, options);
        var result = operation.Value;

        var totalPages = result.Pages?.Count ?? 0;
        var extractedContent = result.Content ?? "";

        logger.LogInformation("Extracted: {Pages} pages, {Chars} chars from {Filename}",
            totalPages, extractedContent.Length, filename);

        return new ExtractResult(extractedContent, totalPages, extractedContent.Length, filename);
    }
}
