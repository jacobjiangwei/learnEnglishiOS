using Microsoft.Azure.Cosmos;
using Microsoft.Azure.Cosmos.Linq;
using Volingo.Api.Models;

namespace Volingo.Api.Services;

/// <summary>
/// Orchestrates device authentication, JWT issuance, refresh token rotation, and revocation.
/// Uses Cosmos DB for user and refresh token persistence.
/// </summary>
public class AuthService : IAuthService
{
    private readonly Container _usersContainer;
    private readonly Container _refreshTokensContainer;
    private readonly IJwtTokenService _jwtTokenService;
    private readonly IConfiguration _configuration;
    private readonly ILogger<AuthService> _logger;

    public AuthService(
        CosmosClient cosmosClient,
        IJwtTokenService jwtTokenService,
        IConfiguration configuration,
        ILogger<AuthService> logger)
    {
        var databaseName = configuration["CosmosDb:DatabaseName"] ?? "volingo";
        _usersContainer = cosmosClient.GetContainer(databaseName, "users");
        _refreshTokensContainer = cosmosClient.GetContainer(databaseName, "refreshTokens");
        _jwtTokenService = jwtTokenService;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<AuthResponse> SignInWithDeviceAsync(DeviceSignInRequest request)
    {
        // Find existing user by device ID
        var user = await FindUserByDeviceIdAsync(request.DeviceId);

        if (user is null)
        {
            // New device → create anonymous user
            user = new UserDocument
            {
                Id = $"user_{Guid.NewGuid():N}",
                DeviceIds = [request.DeviceId],
                CreatedAt = DateTime.UtcNow,
                LastLoginAt = DateTime.UtcNow
            };
            await _usersContainer.CreateItemAsync(user, new PartitionKey(user.Id));
            _logger.LogInformation("Created new device user {UserId} for device {DeviceId}", user.Id, request.DeviceId);
        }
        else
        {
            user.LastLoginAt = DateTime.UtcNow;
            await _usersContainer.UpsertItemAsync(user, new PartitionKey(user.Id));
            _logger.LogInformation("Device user {UserId} signed in again", user.Id);
        }

        return await IssueTokensAsync(user, request.DeviceId, request.DeviceInfo);
    }

    public async Task<AuthResponse> RefreshTokenAsync(string refreshToken)
    {
        // 1. Hash the incoming token and find it in DB
        var tokenHash = _jwtTokenService.HashToken(refreshToken);
        var doc = await FindRefreshTokenByHashAsync(tokenHash);

        if (doc is null || doc.IsRevoked || doc.ExpiresAt < DateTime.UtcNow)
        {
            throw new UnauthorizedAccessException("Invalid or expired refresh token.");
        }

        // 2. Revoke the old refresh token (rotation)
        doc.IsRevoked = true;
        doc.RevokedAt = DateTime.UtcNow;
        await _refreshTokensContainer.UpsertItemAsync(doc, new PartitionKey(doc.UserId));

        // 3. Get user
        var user = await GetUserByIdAsync(doc.UserId)
            ?? throw new UnauthorizedAccessException("User not found.");

        // 4. Issue new token pair
        return await IssueTokensAsync(user, doc.DeviceId, doc.DeviceInfo);
    }

    public async Task RevokeRefreshTokenAsync(string userId, string? tokenId = null)
    {
        if (tokenId is not null)
        {
            // Revoke specific token
            try
            {
                var doc = await _refreshTokensContainer.ReadItemAsync<RefreshTokenDocument>(
                    tokenId, new PartitionKey(userId));

                doc.Resource.IsRevoked = true;
                doc.Resource.RevokedAt = DateTime.UtcNow;
                await _refreshTokensContainer.UpsertItemAsync(doc.Resource, new PartitionKey(userId));
            }
            catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
            {
                // Token already gone — idempotent
            }
        }
        else
        {
            // Revoke all tokens for this user
            var query = _refreshTokensContainer.GetItemLinqQueryable<RefreshTokenDocument>(
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
                    await _refreshTokensContainer.UpsertItemAsync(doc, new PartitionKey(userId));
                }
            }
        }

        _logger.LogInformation("Revoked refresh token(s) for user {UserId}, tokenId={TokenId}", userId, tokenId ?? "all");
    }

    public async Task<UserProfile?> GetUserProfileAsync(string userId)
    {
        var user = await GetUserByIdAsync(userId);
        return user is null ? null : new UserProfile(user.Id, user.DisplayName, user.Email);
    }

    // ── Private helpers ──

    private async Task<AuthResponse> IssueTokensAsync(UserDocument user, string? deviceId, string? deviceInfo)
    {
        var accessToken = _jwtTokenService.GenerateAccessToken(user.Id, deviceId);
        var refreshToken = _jwtTokenService.GenerateRefreshToken();

        var refreshTokenExpiryDays = int.TryParse(
            _configuration["Jwt:RefreshTokenExpiryDays"], out var d) ? d : 365;
        var accessTokenExpiryDays = int.TryParse(
            _configuration["Jwt:AccessTokenExpiryDays"], out var a) ? a : 30;

        // Store refresh token hash
        var rtDoc = new RefreshTokenDocument
        {
            Id = $"rt_{Guid.NewGuid():N}",
            UserId = user.Id,
            TokenHash = _jwtTokenService.HashToken(refreshToken),
            DeviceId = deviceId,
            DeviceInfo = deviceInfo,
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(refreshTokenExpiryDays),
            IsRevoked = false
        };
        await _refreshTokensContainer.CreateItemAsync(rtDoc, new PartitionKey(user.Id));

        var profile = new UserProfile(user.Id, user.DisplayName, user.Email);
        return new AuthResponse(accessToken, refreshToken, accessTokenExpiryDays * 86400, profile);
    }

    private async Task<UserDocument?> FindUserByDeviceIdAsync(string deviceId)
    {
        // Cross-partition query: find user whose DeviceIds array contains deviceId.
        var query = new QueryDefinition(
            "SELECT * FROM c WHERE ARRAY_CONTAINS(c.deviceIds, @deviceId)")
            .WithParameter("@deviceId", deviceId);

        using var iterator = _usersContainer.GetItemQueryIterator<UserDocument>(query);
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            var user = response.FirstOrDefault();
            if (user is not null) return user;
        }

        return null;
    }

    private async Task<UserDocument?> GetUserByIdAsync(string userId)
    {
        try
        {
            var response = await _usersContainer.ReadItemAsync<UserDocument>(
                userId, new PartitionKey(userId));
            return response.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
    }

    private async Task<RefreshTokenDocument?> FindRefreshTokenByHashAsync(string tokenHash)
    {
        // Cross-partition query on tokenHash. Infrequent (only on refresh).
        var query = new QueryDefinition(
            "SELECT * FROM c WHERE c.tokenHash = @tokenHash AND c.isRevoked = false")
            .WithParameter("@tokenHash", tokenHash);

        using var iterator = _refreshTokensContainer.GetItemQueryIterator<RefreshTokenDocument>(query);
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            var doc = response.FirstOrDefault();
            if (doc is not null) return doc;
        }

        return null;
    }
}
