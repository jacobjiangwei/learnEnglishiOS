namespace Volingo.Api.Services;

/// <summary>
/// Abstraction for sending emails. Production uses Azure Communication Services,
/// development uses console logging.
/// </summary>
public interface IEmailSender
{
    /// <summary>
    /// Send an email to one recipient.
    /// </summary>
    Task SendAsync(string to, string subject, string htmlBody);
}
