namespace Volingo.Api.Models;

// ── Auth error with machine-readable code ──

public class AuthException : Exception
{
    public string Code { get; }
    public int StatusCode { get; }

    public AuthException(string code, string message, int statusCode = 400) : base(message)
    {
        Code = code;
        StatusCode = statusCode;
    }
}

public static class AuthErrorCodes
{
    public const string InvalidRefreshToken = "invalid_refresh_token";
    public const string UserNotFound = "user_not_found";
    public const string EmailAlreadyBound = "email_already_bound";
    public const string NoPendingVerification = "no_pending_verification";
    public const string CodeExpired = "code_expired";
    public const string InvalidCode = "invalid_code";
    public const string InvalidLoginCode = "invalid_login_code";
    public const string NotEmailUser = "not_email_user";
}

// ── Request / Response DTOs ──

public record DeviceSignInRequest(
    string DeviceId,
    string? DeviceInfo = null);

public record RefreshRequest(string RefreshToken);

public record BindEmailRequest(string Email);

public record VerifyEmailRequest(string Code);

public record SendLoginCodeRequest(string Email, string? DeviceId = null);

public record VerifyLoginCodeRequest(string Email, string Code, string? DeviceId = null);

public record AuthResponse(
    string AccessToken,
    string RefreshToken,
    int ExpiresIn,
    UserProfile User);

public record UserProfile(
    string Id,
    string? DisplayName,
    string? Email,
    bool HasEmailIdentity,
    string? Level = null,
    string? TextbookCode = null,
    string? Semester = null);

public record UpdateProfileRequest(
    string? Level = null,
    string? TextbookCode = null,
    string? Semester = null,
    string? DisplayName = null);

// ── Domain entities (stored in Cosmos DB) ──

/// <summary>
/// Auth core — minimal user record for authentication.
/// Container: users, PK: /id
/// </summary>
public class HBUser
{
    public string Id { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public DateTime LastLoginAt { get; set; }
}

/// <summary>
/// User profile — display name, email, learning settings.
/// Container: userProfiles, PK: /id
/// Id = userId.
/// </summary>
public class HBUserProfile
{
    public string Id { get; set; } = "";
    public string? DisplayName { get; set; }
    public string? Email { get; set; }
    public bool HasEmailIdentity { get; set; }
    public string? Level { get; set; }
    public string? TextbookCode { get; set; }
    public string? Semester { get; set; }
}

// ── Identity entities ──

/// <summary>
/// Base login identity. Container: identities, PK: /id
/// Id format: "device:{deviceId}" or "email:{normalizedEmail}"
/// </summary>
public class HBUserIdentity
{
    public string Id { get; set; } = "";
    public string UserId { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public DateTime LastUsedAt { get; set; }
}

/// <summary>Device login identity.</summary>
public class DeviceIdentity : HBUserIdentity
{
    public string DeviceId { get; set; } = "";
    public string? DeviceInfo { get; set; }
}

/// <summary>Email login identity.</summary>
public class EmailIdentity : HBUserIdentity
{
    public string Email { get; set; } = "";
}

/// <summary>
/// Email verification code. Container: emailVerifications, PK: /userId, TTL: 600s
/// </summary>
public class EmailVerification
{
    public string Id { get; set; } = "";
    public string UserId { get; set; } = "";
    public string Email { get; set; } = "";
    public string Code { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public DateTime ExpiresAt { get; set; }
    public int Ttl { get; set; } = 600;
}

/// <summary>
/// Refresh token (hashed). Container: refreshTokens, PK: /userId
/// </summary>
public class RefreshToken
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
