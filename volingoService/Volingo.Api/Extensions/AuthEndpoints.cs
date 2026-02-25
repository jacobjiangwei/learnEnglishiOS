using System.Security.Claims;
using Volingo.Api.Models;
using Volingo.Api.Services;

namespace Volingo.Api.Extensions;

/// <summary>
/// Maps authentication endpoints: device login, token refresh, logout.
/// </summary>
public static class AuthEndpoints
{
    public static WebApplication MapAuthEndpoints(this WebApplication app)
    {
        var auth = app.MapGroup("/api/v1/auth").WithTags("Auth");

        // ── 1. Device ID 自动登录 — 零摩擦，无需用户交互 ──
        auth.MapPost("/device", async (IAuthService authService, DeviceSignInRequest request) =>
        {
            var response = await authService.SignInWithDeviceAsync(request);
            return Results.Ok(response);
        })
        .AllowAnonymous()
        .WithName("SignInWithDevice");

        // ── 2. 刷新 Token ──
        auth.MapPost("/refresh", async (IAuthService authService, RefreshRequest request) =>
        {
            try
            {
                var response = await authService.RefreshTokenAsync(request.RefreshToken);
                return Results.Ok(response);
            }
            catch (UnauthorizedAccessException ex)
            {
                return Results.Problem(
                    detail: ex.Message,
                    statusCode: 401,
                    title: "Token Refresh Failed");
            }
        })
        .AllowAnonymous()
        .WithName("RefreshToken");

        // ── 3. 登出（吊销 Refresh Token） ──
        auth.MapPost("/logout", async (HttpContext ctx, IAuthService authService) =>
        {
            var userId = ctx.User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Results.Problem(detail: "User identity not found.", statusCode: 401, title: "Unauthorized");

            await authService.RevokeRefreshTokenAsync(userId);
            return Results.NoContent();
        })
        .RequireAuthorization()
        .WithName("Logout");

        // ── 4. 获取当前用户信息 ──
        auth.MapGet("/me", async (HttpContext ctx, IAuthService authService) =>
        {
            var userId = ctx.User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Results.Problem(detail: "User identity not found.", statusCode: 401, title: "Unauthorized");

            var profile = await authService.GetUserProfileAsync(userId);
            if (profile is null)
                return Results.Problem(detail: "User not found.", statusCode: 404, title: "Not Found");

            return Results.Ok(profile);
        })
        .RequireAuthorization()
        .WithName("GetCurrentUser");

        return app;
    }
}

