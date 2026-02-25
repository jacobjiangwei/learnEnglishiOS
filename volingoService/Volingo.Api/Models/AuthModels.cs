namespace Volingo.Api.Models;

// ── Auth: Request / Response DTOs ──

public record DeviceSignInRequest(
    string DeviceId,
    string? DeviceInfo = null);

public record RefreshRequest(string RefreshToken);

public record AuthResponse(
    string AccessToken,
    string RefreshToken,
    int ExpiresIn,
    UserProfile User);

public record UserProfile(
    string Id,
    string? DisplayName,
    string? Email);

// ── Cosmos documents ──

/// <summary>
/// User document stored in "users" container, PK: /id.
/// </summary>
public class UserDocument
{
    public string Id { get; set; } = "";
    public string? Email { get; set; }
    public string? FullName { get; set; }
    public string? DisplayName { get; set; }
    public List<string> DeviceIds { get; set; } = [];
    public string? Level { get; set; }
    public string? System { get; set; }
    public string? TextbookCode { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime LastLoginAt { get; set; }
}

/// <summary>
/// Refresh token document stored in "refreshTokens" container, PK: /userId.
/// Stores SHA-256 hash of the token; plaintext lives only on client Keychain.
/// </summary>
public class RefreshTokenDocument
{
    public string Id { get; set; } = "";
    public string UserId { get; set; } = "";
    public string TokenHash { get; set; } = "";
    public string? DeviceId { get; set; }
    public string? DeviceInfo { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime ExpiresAt { get; set; }
    public bool IsRevoked { get; set; }
    public DateTime? RevokedAt { get; set; }
}
