using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Auth service: identity management, token issuance, user profile.
/// </summary>
public interface IAuthService
{
    /// <summary>
    /// Sign in via device ID. Creates User + device Identity if new.
    /// </summary>
    Task<AuthResponse> SignInWithDeviceAsync(DeviceSignInRequest request);

    /// <summary>
    /// Refresh an expired access token (token rotation).
    /// </summary>
    Task<AuthResponse> RefreshTokenAsync(string refreshToken);

    /// <summary>
    /// Revoke refresh tokens. If tokenId is null, revokes all (full logout).
    /// </summary>
    Task RevokeRefreshTokenAsync(string userId, string? tokenId = null);

    /// <summary>
    /// Get user profile by ID.
    /// </summary>
    Task<UserProfile?> GetUserProfileAsync(string userId);

    /// <summary>
    /// Bind an email identity to an existing user. Sends verification code.
    /// </summary>
    Task BindEmailAsync(string userId, BindEmailRequest request);

    /// <summary>
    /// Verify email code. Creates email Identity for current user.
    /// Rejects if email is already bound to another user (no merge).
    /// </summary>
    Task<AuthResponse> VerifyEmailAsync(string userId, VerifyEmailRequest request);

    /// <summary>
    /// Send a passwordless login code to an email address.
    /// </summary>
    Task SendLoginCodeAsync(SendLoginCodeRequest request);

    /// <summary>
    /// Verify login code. Creates User + email Identity if new email.
    /// </summary>
    Task<AuthResponse> VerifyLoginCodeAsync(VerifyLoginCodeRequest request);

    /// <summary>
    /// Disconnect from email account. Revokes all tokens.
    /// Client should call SignInWithDeviceAsync to get a fresh anonymous user.
    /// </summary>
    Task EmailLogoutAsync(string userId);

    /// <summary>
    /// Update user profile fields (level, textbookCode, semester, displayName).
    /// </summary>
    Task<UserProfile> UpdateProfileAsync(string userId, UpdateProfileRequest request);
}
