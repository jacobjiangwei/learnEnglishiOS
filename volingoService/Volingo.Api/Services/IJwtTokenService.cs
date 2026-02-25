using System.Security.Claims;

namespace Volingo.Api.Services;

/// <summary>
/// Signs and validates JWT access tokens (RS256).
/// </summary>
public interface IJwtTokenService
{
    /// <summary>
    /// Generate a signed JWT access token for the given user.
    /// </summary>
    string GenerateAccessToken(string userId, string? deviceId = null, string role = "user");

    /// <summary>
    /// Generate a cryptographically random opaque refresh token.
    /// </summary>
    string GenerateRefreshToken();

    /// <summary>
    /// Compute SHA-256 hash of a refresh token for database storage.
    /// </summary>
    string HashToken(string token);
}
