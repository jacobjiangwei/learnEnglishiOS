using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Orchestrates device authentication, token issuance, refresh, and revocation.
/// </summary>
public interface IAuthService
{
    /// <summary>
    /// Authenticate via device ID. Creates user if new, returns access + refresh tokens.
    /// Zero-friction auto-login — no user interaction required.
    /// </summary>
    Task<AuthResponse> SignInWithDeviceAsync(DeviceSignInRequest request);

    /// <summary>
    /// Refresh an expired access token using a valid refresh token.
    /// Implements token rotation: old refresh token is revoked, new one issued.
    /// </summary>
    Task<AuthResponse> RefreshTokenAsync(string refreshToken);

    /// <summary>
    /// Revoke refresh tokens for a user. If tokenId is null, revokes all tokens (full logout).
    /// </summary>
    Task RevokeRefreshTokenAsync(string userId, string? tokenId = null);

    /// <summary>
    /// Get user profile by user ID.
    /// </summary>
    Task<UserProfile?> GetUserProfileAsync(string userId);
}
