using Microsoft.Azure.Cosmos;
using Microsoft.Azure.Cosmos.Linq;
using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Auth service: three-container architecture (users + userProfiles + identities).
/// users = auth core, userProfiles = display/settings, identities = login methods.
/// </summary>
public class AuthService : IAuthService
{
    private readonly Container _users;
    private readonly Container _userProfiles;
    private readonly Container _identities;
    private readonly Container _refreshTokens;
    private readonly Container _emailVerifications;
    private readonly IJwtTokenService _jwt;
    private readonly IEmailSender _emailSender;
    private readonly IConfiguration _config;
    private readonly ILogger<AuthService> _log;

    public AuthService(
        CosmosClient cosmosClient,
        IJwtTokenService jwtTokenService,
        IEmailSender emailSender,
        IConfiguration configuration,
        ILogger<AuthService> logger)
    {
        var db = configuration["CosmosDb:DatabaseName"] ?? "volingo";
        _users = cosmosClient.GetContainer(db, "users");
        _userProfiles = cosmosClient.GetContainer(db, "userProfiles");
        _identities = cosmosClient.GetContainer(db, "identities");
        _refreshTokens = cosmosClient.GetContainer(db, "refreshTokens");
        _emailVerifications = cosmosClient.GetContainer(db, "emailVerifications");
        _jwt = jwtTokenService;
        _emailSender = emailSender;
        _config = configuration;
        _log = logger;
    }

    // ── Device sign-in ──

    public async Task<AuthResponse> SignInWithDeviceAsync(DeviceSignInRequest request)
    {
        var identityId = $"device:{request.DeviceId}";
        var identity = await GetIdentityAsync<DeviceIdentity>(identityId);

        HBUserProfile profile;
        if (identity is not null)
        {
            // Existing device → update timestamps
            var user = await GetUserByIdAsync(identity.UserId)
                ?? throw new AuthException(AuthErrorCodes.UserNotFound, "User not found.", 401);
            user.LastLoginAt = DateTime.UtcNow;
            await _users.UpsertItemAsync(user, new PartitionKey(user.Id));

            identity.LastUsedAt = DateTime.UtcNow;
            await _identities.UpsertItemAsync(identity, new PartitionKey(identity.Id));

            profile = await GetProfileAsync(identity.UserId)
                ?? throw new AuthException(AuthErrorCodes.UserNotFound, "Profile not found.", 401);

            _log.LogInformation("Device sign-in: user {UserId}", user.Id);
        }
        else
        {
            // New device → create user + profile + device identity
            var userId = Guid.NewGuid().ToString("N");

            var user = new HBUser { Id = userId, CreatedAt = DateTime.UtcNow, LastLoginAt = DateTime.UtcNow };
            await _users.CreateItemAsync(user, new PartitionKey(userId));

            profile = new HBUserProfile { Id = userId };
            await _userProfiles.CreateItemAsync(profile, new PartitionKey(userId));

            var deviceIdentity = new DeviceIdentity
            {
                Id = identityId, UserId = userId, DeviceId = request.DeviceId,
                DeviceInfo = request.DeviceInfo, CreatedAt = DateTime.UtcNow, LastUsedAt = DateTime.UtcNow
            };
            await _identities.CreateItemAsync(deviceIdentity, new PartitionKey(deviceIdentity.Id));

            _log.LogInformation("New device user {UserId} for device {DeviceId}", userId, request.DeviceId);
        }

        return await IssueTokensAsync(profile, request.DeviceId, request.DeviceInfo);
    }

    // ── Token refresh ──

    public async Task<AuthResponse> RefreshTokenAsync(string refreshToken)
    {
        var tokenHash = _jwt.HashToken(refreshToken);
        var doc = await FindRefreshTokenByHashAsync(tokenHash);

        if (doc is null || doc.IsRevoked || doc.ExpiresAt < DateTime.UtcNow)
            throw new AuthException(AuthErrorCodes.InvalidRefreshToken, "Invalid or expired refresh token.", 401);

        // Rotate: revoke old, issue new
        doc.IsRevoked = true;
        doc.RevokedAt = DateTime.UtcNow;
        await _refreshTokens.UpsertItemAsync(doc, new PartitionKey(doc.UserId));

        var profile = await GetProfileAsync(doc.UserId)
            ?? throw new AuthException(AuthErrorCodes.UserNotFound, "User not found.", 401);

        return await IssueTokensAsync(profile, doc.DeviceId, doc.DeviceInfo);
    }

    // ── Token revocation ──

    public async Task RevokeRefreshTokenAsync(string userId, string? tokenId = null)
    {
        if (tokenId is not null)
        {
            try
            {
                var doc = await _refreshTokens.ReadItemAsync<RefreshToken>(tokenId, new PartitionKey(userId));
                doc.Resource.IsRevoked = true;
                doc.Resource.RevokedAt = DateTime.UtcNow;
                await _refreshTokens.UpsertItemAsync(doc.Resource, new PartitionKey(userId));
            }
            catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound) { }
        }
        else
        {
            var query = _refreshTokens.GetItemLinqQueryable<RefreshToken>(
                    requestOptions: new QueryRequestOptions { PartitionKey = new PartitionKey(userId) })
                .Where(t => t.UserId == userId && !t.IsRevoked)
                .ToFeedIterator();

            while (query.HasMoreResults)
            {
                var batch = await query.ReadNextAsync();
                foreach (var doc in batch)
                {
                    doc.IsRevoked = true;
                    doc.RevokedAt = DateTime.UtcNow;
                    await _refreshTokens.UpsertItemAsync(doc, new PartitionKey(userId));
                }
            }
        }

        _log.LogInformation("Revoked token(s) for user {UserId}, tokenId={TokenId}", userId, tokenId ?? "all");
    }

    // ── User profile ──

    public async Task<UserProfile?> GetUserProfileAsync(string userId)
    {
        var profile = await GetProfileAsync(userId);
        return profile is null ? null : ToProfile(profile);
    }

    public async Task<UserProfile> UpdateProfileAsync(string userId, UpdateProfileRequest request)
    {
        var profile = await GetProfileAsync(userId)
            ?? throw new AuthException(AuthErrorCodes.UserNotFound, "User not found.");

        if (request.Level is not null) profile.Level = request.Level;
        if (request.TextbookCode is not null) profile.TextbookCode = request.TextbookCode;
        if (request.Semester is not null) profile.Semester = request.Semester;
        if (request.DisplayName is not null) profile.DisplayName = request.DisplayName;

        await _userProfiles.UpsertItemAsync(profile, new PartitionKey(userId));
        _log.LogInformation("User {UserId} profile updated", userId);

        return ToProfile(profile);
    }

    // ── Bind email ──

    public async Task BindEmailAsync(string userId, BindEmailRequest request)
    {
        var profile = await GetProfileAsync(userId)
            ?? throw new AuthException(AuthErrorCodes.UserNotFound, "User not found.");

        if (profile.HasEmailIdentity)
            throw new AuthException(AuthErrorCodes.EmailAlreadyBound, "Email is already bound to this account.");

        var normalizedEmail = request.Email.Trim().ToLowerInvariant();
        var code = Random.Shared.Next(100000, 999999).ToString();

        var verification = new EmailVerification
        {
            Id = $"ev_{userId}", UserId = userId, Email = normalizedEmail,
            Code = code, CreatedAt = DateTime.UtcNow, ExpiresAt = DateTime.UtcNow.AddMinutes(10), Ttl = 600
        };
        await _emailVerifications.UpsertItemAsync(verification, new PartitionKey(userId));

        _ = SendEmailInBackground(request.Email, "海豹英语 — 邮箱验证码",
            BuildVerificationEmail(code, "验证你的邮箱", "你的验证码是："));

        _log.LogInformation("Bind-email code stored for {Email}, user {UserId}", normalizedEmail, userId);
    }

    // ── Verify email binding ──

    public async Task<AuthResponse> VerifyEmailAsync(string userId, VerifyEmailRequest request)
    {
        var verification = await GetEmailVerificationAsync(userId)
            ?? throw new AuthException(AuthErrorCodes.NoPendingVerification, "No pending verification.");

        if (verification.ExpiresAt < DateTime.UtcNow)
            throw new AuthException(AuthErrorCodes.CodeExpired, "Code expired.");
        if (verification.Code != request.Code)
            throw new AuthException(AuthErrorCodes.InvalidCode, "Invalid code.");

        var emailIdentityId = $"email:{verification.Email}";
        var existingEmailIdentity = await GetIdentityAsync<EmailIdentity>(emailIdentityId);

        HBUserProfile targetProfile;

        if (existingEmailIdentity is not null && existingEmailIdentity.UserId != userId)
        {
            // Email belongs to another user → merge: move device identities to that user
            targetProfile = await GetProfileAsync(existingEmailIdentity.UserId)
                ?? throw new AuthException(AuthErrorCodes.UserNotFound, "Email user not found.");

            await MoveDeviceIdentitiesAsync(userId, existingEmailIdentity.UserId);

            // Update target user LastLoginAt
            var targetUser = await GetUserByIdAsync(existingEmailIdentity.UserId);
            if (targetUser is not null)
            {
                targetUser.LastLoginAt = DateTime.UtcNow;
                await _users.UpsertItemAsync(targetUser, new PartitionKey(targetUser.Id));
            }

            // Clean up orphaned user + profile
            try { await _users.DeleteItemAsync<HBUser>(userId, new PartitionKey(userId)); } catch { }
            try { await _userProfiles.DeleteItemAsync<HBUserProfile>(userId, new PartitionKey(userId)); } catch { }

            _log.LogInformation("Merge: user {Old} → {Target} via {Email}",
                userId, existingEmailIdentity.UserId, verification.Email);
        }
        else
        {
            // Fresh email → create email identity for current user
            targetProfile = await GetProfileAsync(userId)
                ?? throw new AuthException(AuthErrorCodes.UserNotFound, "User not found.");
            targetProfile.Email = verification.Email;
            targetProfile.HasEmailIdentity = true;
            await _userProfiles.UpsertItemAsync(targetProfile, new PartitionKey(userId));

            var emailIdentity = new EmailIdentity
            {
                Id = emailIdentityId, UserId = userId, Email = verification.Email,
                CreatedAt = DateTime.UtcNow, LastUsedAt = DateTime.UtcNow
            };
            await _identities.UpsertItemAsync(emailIdentity, new PartitionKey(emailIdentity.Id));

            // Update LastLoginAt
            var user = await GetUserByIdAsync(userId);
            if (user is not null)
            {
                user.LastLoginAt = DateTime.UtcNow;
                await _users.UpsertItemAsync(user, new PartitionKey(user.Id));
            }

            _log.LogInformation("Email {Email} bound to user {UserId}", verification.Email, userId);
        }

        await CleanupVerificationAsync(userId);

        var deviceId = await GetFirstDeviceIdForUserAsync(targetProfile.Id);
        return await IssueTokensAsync(targetProfile, deviceId, null);
    }

    // ── Passwordless login: send code ──

    public async Task SendLoginCodeAsync(SendLoginCodeRequest request)
    {
        var normalizedEmail = request.Email.Trim().ToLowerInvariant();
        var emailIdentity = await GetIdentityAsync<EmailIdentity>($"email:{normalizedEmail}");

        var docOwner = emailIdentity?.UserId ?? $"pending_{normalizedEmail.GetHashCode():x8}";
        var code = Random.Shared.Next(100000, 999999).ToString();

        var verification = new EmailVerification
        {
            Id = $"ev_{docOwner}", UserId = docOwner, Email = normalizedEmail,
            Code = code, CreatedAt = DateTime.UtcNow, ExpiresAt = DateTime.UtcNow.AddMinutes(10), Ttl = 600
        };
        await _emailVerifications.UpsertItemAsync(verification, new PartitionKey(docOwner));

        _ = SendEmailInBackground(normalizedEmail, "海豹英语 — 登录验证码",
            BuildVerificationEmail(code, "登录验证码", "你的登录验证码是："));

        _log.LogInformation("Login code for {Email} (existing={Exists})", normalizedEmail, emailIdentity is not null);
    }

    // ── Passwordless login: verify code ──

    public async Task<AuthResponse> VerifyLoginCodeAsync(VerifyLoginCodeRequest request)
    {
        var normalizedEmail = request.Email.Trim().ToLowerInvariant();
        var emailIdentityId = $"email:{normalizedEmail}";
        var emailIdentity = await GetIdentityAsync<EmailIdentity>(emailIdentityId);

        var docOwner = emailIdentity?.UserId ?? $"pending_{normalizedEmail.GetHashCode():x8}";

        var verification = await GetEmailVerificationAsync(docOwner)
            ?? throw new AuthException(AuthErrorCodes.InvalidLoginCode, "Invalid email or code.", 401);

        if (verification.ExpiresAt < DateTime.UtcNow || verification.Code != request.Code)
            throw new AuthException(AuthErrorCodes.InvalidLoginCode, "Invalid email or code.", 401);

        await CleanupVerificationAsync(docOwner);

        HBUserProfile profile;
        if (emailIdentity is not null)
        {
            // Existing email user → sign in
            profile = await GetProfileAsync(emailIdentity.UserId)
                ?? throw new AuthException(AuthErrorCodes.UserNotFound, "User not found.", 401);

            var user = await GetUserByIdAsync(emailIdentity.UserId);
            if (user is not null)
            {
                user.LastLoginAt = DateTime.UtcNow;
                await _users.UpsertItemAsync(user, new PartitionKey(user.Id));
            }

            emailIdentity.LastUsedAt = DateTime.UtcNow;
            await _identities.UpsertItemAsync(emailIdentity, new PartitionKey(emailIdentity.Id));

            _log.LogInformation("Email login: user {UserId}", emailIdentity.UserId);
        }
        else
        {
            // New email user → create user + profile + email identity
            var userId = Guid.NewGuid().ToString("N");

            var user = new HBUser { Id = userId, CreatedAt = DateTime.UtcNow, LastLoginAt = DateTime.UtcNow };
            await _users.CreateItemAsync(user, new PartitionKey(userId));

            profile = new HBUserProfile
            {
                Id = userId, Email = normalizedEmail, HasEmailIdentity = true
            };
            await _userProfiles.CreateItemAsync(profile, new PartitionKey(userId));

            var newIdentity = new EmailIdentity
            {
                Id = emailIdentityId, UserId = userId, Email = normalizedEmail,
                CreatedAt = DateTime.UtcNow, LastUsedAt = DateTime.UtcNow
            };
            await _identities.CreateItemAsync(newIdentity, new PartitionKey(newIdentity.Id));

            _log.LogInformation("New email user {UserId} for {Email}", userId, normalizedEmail);
        }

        // Link device identity if provided
        if (!string.IsNullOrEmpty(request.DeviceId))
        {
            var deviceIdentityId = $"device:{request.DeviceId}";
            var deviceIdentity = await GetIdentityAsync<DeviceIdentity>(deviceIdentityId);
            if (deviceIdentity is null)
            {
                var newDevice = new DeviceIdentity
                {
                    Id = deviceIdentityId, UserId = profile.Id, DeviceId = request.DeviceId,
                    CreatedAt = DateTime.UtcNow, LastUsedAt = DateTime.UtcNow
                };
                await _identities.CreateItemAsync(newDevice, new PartitionKey(newDevice.Id));
            }
            else if (deviceIdentity.UserId != profile.Id)
            {
                deviceIdentity.UserId = profile.Id;
                deviceIdentity.LastUsedAt = DateTime.UtcNow;
                await _identities.UpsertItemAsync(deviceIdentity, new PartitionKey(deviceIdentity.Id));
            }
        }

        return await IssueTokensAsync(profile, request.DeviceId, null);
    }

    // ── Email logout ──

    public async Task EmailLogoutAsync(string userId)
    {
        var profile = await GetProfileAsync(userId)
            ?? throw new AuthException(AuthErrorCodes.UserNotFound, "User not found.");

        if (!profile.HasEmailIdentity)
            throw new AuthException(AuthErrorCodes.NotEmailUser, "No email identity on this account.");

        await RevokeRefreshTokenAsync(userId);

        _log.LogInformation("Email logout for user {UserId}", userId);
    }

    // ── Private helpers ──

    private async Task<AuthResponse> IssueTokensAsync(HBUserProfile profile, string? deviceId, string? deviceInfo)
    {
        var accessToken = _jwt.GenerateAccessToken(profile.Id, deviceId);
        var refreshToken = _jwt.GenerateRefreshToken();

        var rtExpiry = int.TryParse(_config["Jwt:RefreshTokenExpirySeconds"], out var r) ? r : 31536000;
        var atExpiry = int.TryParse(_config["Jwt:AccessTokenExpirySeconds"], out var a) ? a : 2592000;

        var rt = new RefreshToken
        {
            Id = $"rt_{Guid.NewGuid():N}", UserId = profile.Id,
            TokenHash = _jwt.HashToken(refreshToken), DeviceId = deviceId, DeviceInfo = deviceInfo,
            CreatedAt = DateTime.UtcNow, ExpiresAt = DateTime.UtcNow.AddSeconds(rtExpiry), IsRevoked = false
        };
        await _refreshTokens.CreateItemAsync(rt, new PartitionKey(profile.Id));

        return new AuthResponse(accessToken, refreshToken, atExpiry, ToProfile(profile));
    }

    private static UserProfile ToProfile(HBUserProfile p)
        => new(p.Id, p.DisplayName, p.Email, p.HasEmailIdentity,
               p.Level, p.TextbookCode, p.Semester);

    // ── Identity helpers ──

    private async Task<T?> GetIdentityAsync<T>(string identityId) where T : HBUserIdentity
    {
        try
        {
            var resp = await _identities.ReadItemAsync<T>(identityId, new PartitionKey(identityId));
            return resp.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
    }

    private async Task<string?> GetFirstDeviceIdForUserAsync(string userId)
    {
        var query = new QueryDefinition(
            "SELECT * FROM c WHERE c.userId = @userId AND STARTSWITH(c.id, 'device:') OFFSET 0 LIMIT 1")
            .WithParameter("@userId", userId);

        using var iterator = _identities.GetItemQueryIterator<DeviceIdentity>(query);
        if (iterator.HasMoreResults)
        {
            var resp = await iterator.ReadNextAsync();
            return resp.FirstOrDefault()?.DeviceId;
        }
        return null;
    }

    private async Task MoveDeviceIdentitiesAsync(string fromUserId, string toUserId)
    {
        var query = new QueryDefinition(
            "SELECT * FROM c WHERE c.userId = @userId AND STARTSWITH(c.id, 'device:')")
            .WithParameter("@userId", fromUserId);

        using var iterator = _identities.GetItemQueryIterator<DeviceIdentity>(query);
        while (iterator.HasMoreResults)
        {
            var batch = await iterator.ReadNextAsync();
            foreach (var identity in batch)
            {
                identity.UserId = toUserId;
                identity.LastUsedAt = DateTime.UtcNow;
                await _identities.UpsertItemAsync(identity, new PartitionKey(identity.Id));
            }
        }
    }

    // ── User helpers ──

    private async Task<HBUser?> GetUserByIdAsync(string userId)
    {
        try
        {
            var resp = await _users.ReadItemAsync<HBUser>(userId, new PartitionKey(userId));
            return resp.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
    }

    // ── Profile helpers ──

    private async Task<HBUserProfile?> GetProfileAsync(string userId)
    {
        try
        {
            var resp = await _userProfiles.ReadItemAsync<HBUserProfile>(userId, new PartitionKey(userId));
            return resp.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
    }

    // ── Email verification helpers ──

    private async Task<EmailVerification?> GetEmailVerificationAsync(string owner)
    {
        try
        {
            var resp = await _emailVerifications.ReadItemAsync<EmailVerification>(
                $"ev_{owner}", new PartitionKey(owner));
            return resp.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
    }

    private async Task CleanupVerificationAsync(string owner)
    {
        try
        {
            await _emailVerifications.DeleteItemAsync<EmailVerification>(
                $"ev_{owner}", new PartitionKey(owner));
        }
        catch (CosmosException) { /* TTL will clean it anyway */ }
    }

    // ── Refresh token helpers ──

    private async Task<RefreshToken?> FindRefreshTokenByHashAsync(string tokenHash)
    {
        var query = new QueryDefinition(
            "SELECT * FROM c WHERE c.tokenHash = @tokenHash AND c.isRevoked = false")
            .WithParameter("@tokenHash", tokenHash);

        using var iterator = _refreshTokens.GetItemQueryIterator<RefreshToken>(query);
        while (iterator.HasMoreResults)
        {
            var resp = await iterator.ReadNextAsync();
            var doc = resp.FirstOrDefault();
            if (doc is not null) return doc;
        }
        return null;
    }

    // ── Email sending ──

    private Task SendEmailInBackground(string to, string subject, string htmlBody)
    {
        return Task.Run(async () =>
        {
            try { await _emailSender.SendAsync(to, subject, htmlBody); }
            catch (Exception ex) { _log.LogError(ex, "Email to {Email} failed", to); }
        });
    }

    private static string BuildVerificationEmail(string code, string title, string subtitle)
    {
        return $"""
            <!DOCTYPE html>
            <html>
            <body style="margin:0;padding:0;background:#f9fafb;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif;">
              <div style="max-width:480px;margin:40px auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,0.06);">
                <div style="background:linear-gradient(135deg,#4F46E5,#7C3AED);padding:28px 32px;text-align:center;">
                  <span style="font-size:28px;">🦭</span>
                  <h1 style="color:#fff;font-size:22px;margin:8px 0 0;font-weight:700;">海豹英语</h1>
                  <p style="color:rgba(255,255,255,0.8);font-size:13px;margin:4px 0 0;">让英语学习更轻松</p>
                </div>
                <div style="padding:32px;">
                  <h2 style="color:#1a1a1a;font-size:18px;margin:0 0 8px;">{title}</h2>
                  <p style="color:#666;font-size:15px;margin:0 0 24px;">{subtitle}</p>
                  <div style="background:#f5f5f5;border-radius:12px;padding:24px;text-align:center;">
                    <span style="font-size:36px;font-weight:700;letter-spacing:8px;color:#4F46E5;">{code}</span>
                  </div>
                  <p style="color:#999;font-size:13px;margin:24px 0 0;">验证码将在 10 分钟后过期。如果你没有请求此验证码，请忽略此邮件。</p>
                </div>
                <div style="border-top:1px solid #f0f0f0;padding:20px 32px;text-align:center;">
                  <p style="color:#999;font-size:12px;margin:0 0 8px;">海豹英语 — 专为中国学生打造的英语学习 App</p>
                  <p style="color:#999;font-size:12px;margin:0;">
                    <a href="https://www.haibaoenglishlearning.com" style="color:#4F46E5;text-decoration:none;">访问官网</a>
                    &nbsp;·&nbsp;
                    <a href="mailto:support@haibaoenglishlearning.com" style="color:#4F46E5;text-decoration:none;">联系我们</a>
                  </p>
                  <p style="color:#ccc;font-size:11px;margin:12px 0 0;">© 2026 海豹英语. All rights reserved.</p>
                </div>
              </div>
            </body>
            </html>
            """;
    }
}
