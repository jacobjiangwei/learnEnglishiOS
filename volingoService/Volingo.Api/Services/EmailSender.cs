using Azure;
using Azure.Communication.Email;

namespace Volingo.Api.Services;

/// <summary>
/// Sends emails via Azure Communication Services.
/// </summary>
public class AcsEmailSender : IEmailSender
{
    private readonly EmailClient _client;
    private readonly string _senderAddress;
    private readonly string _senderDisplayName;
    private readonly ILogger<AcsEmailSender> _logger;

    public AcsEmailSender(IConfiguration configuration, ILogger<AcsEmailSender> logger)
    {
        var connectionString = configuration["Email:ConnectionString"]
            ?? throw new InvalidOperationException("Missing Email:ConnectionString configuration.");
        _senderAddress = configuration["Email:SenderAddress"]
            ?? throw new InvalidOperationException("Missing Email:SenderAddress configuration.");
        _senderDisplayName = configuration["Email:SenderDisplayName"] ?? "Volingo";
        _client = new EmailClient(connectionString);
        _logger = logger;
    }

    public async Task SendAsync(string to, string subject, string htmlBody)
    {
        var content = new EmailContent(subject) { Html = htmlBody };
        var recipients = new EmailRecipients([new EmailAddress(to)]);
        var message = new EmailMessage(_senderAddress, recipients, content)
        {
            Headers = { { "x-sender-display-name", _senderDisplayName } }
        };

        try
        {
            var operation = await _client.SendAsync(WaitUntil.Completed, message);
            _logger.LogInformation("Email sent to {To}, operationId={OperationId}, status={Status}",
                to, operation.Id, operation.Value.Status);
        }
        catch (RequestFailedException ex)
        {
            _logger.LogError(ex, "Failed to send email to {To}: {ErrorCode} {Message}",
                to, ex.ErrorCode, ex.Message);
            throw;
        }
    }
}

/// <summary>
/// Development fallback: logs email content to console instead of sending.
/// </summary>
public class ConsoleEmailSender : IEmailSender
{
    private readonly ILogger<ConsoleEmailSender> _logger;

    public ConsoleEmailSender(ILogger<ConsoleEmailSender> logger)
    {
        _logger = logger;
    }

    public Task SendAsync(string to, string subject, string htmlBody)
    {
        _logger.LogWarning(
            "📧 [DEV EMAIL] To: {To} | Subject: {Subject}\n{Body}",
            to, subject, htmlBody);
        return Task.CompletedTask;
    }
}
