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
            catch (AuthException ex)
            {
                return Results.Problem(
                    detail: ex.Message,
                    statusCode: ex.StatusCode,
                    title: "Token Refresh Failed",
                    extensions: new Dictionary<string, object?> { ["code"] = ex.Code });
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

        // ── 5. 绑定邮箱（发送验证码） ──
        auth.MapPost("/bind-email", async (HttpContext ctx, IAuthService authService, BindEmailRequest request) =>
        {
            var userId = ctx.User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Results.Problem(detail: "User identity not found.", statusCode: 401, title: "Unauthorized");

            try
            {
                await authService.BindEmailAsync(userId, request);
                return Results.Ok(new { message = "Verification code sent. Check your email." });
            }
            catch (AuthException ex)
            {
                return Results.Problem(
                    detail: ex.Message,
                    statusCode: ex.StatusCode,
                    title: "Bind Email Failed",
                    extensions: new Dictionary<string, object?> { ["code"] = ex.Code });
            }
        })
        .RequireAuthorization()
        .WithName("BindEmail");

        // ── 6. 验证邮箱（输入验证码） ──
        auth.MapPost("/verify-email", async (HttpContext ctx, IAuthService authService, VerifyEmailRequest request) =>
        {
            var userId = ctx.User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Results.Problem(detail: "User identity not found.", statusCode: 401, title: "Unauthorized");

            try
            {
                var response = await authService.VerifyEmailAsync(userId, request);
                return Results.Ok(response);
            }
            catch (AuthException ex)
            {
                return Results.Problem(
                    detail: ex.Message,
                    statusCode: ex.StatusCode,
                    title: "Verify Email Failed",
                    extensions: new Dictionary<string, object?> { ["code"] = ex.Code });
            }
        })
        .RequireAuthorization()
        .WithName("VerifyEmail");

        // ── 7. 发送登录验证码（免密登录/注册） ──
        auth.MapPost("/send-login-code", async (IAuthService authService, SendLoginCodeRequest request) =>
        {
            try
            {
                await authService.SendLoginCodeAsync(request);
                return Results.Ok(new { message = "Login code sent. Check your email." });
            }
            catch (AuthException ex)
            {
                return Results.Problem(
                    detail: ex.Message,
                    statusCode: ex.StatusCode,
                    title: "Send Code Failed",
                    extensions: new Dictionary<string, object?> { ["code"] = ex.Code });
            }
        })
        .AllowAnonymous()
        .WithName("SendLoginCode");

        // ── 8. 验证登录验证码（免密登录/注册） ──
        auth.MapPost("/verify-login-code", async (IAuthService authService, VerifyLoginCodeRequest request) =>
        {
            try
            {
                var response = await authService.VerifyLoginCodeAsync(request);
                return Results.Ok(response);
            }
            catch (AuthException ex)
            {
                return Results.Problem(
                    detail: ex.Message,
                    statusCode: ex.StatusCode,
                    title: "Login Failed",
                    extensions: new Dictionary<string, object?> { ["code"] = ex.Code });
            }
        })
        .AllowAnonymous()
        .WithName("VerifyLoginCode");

        // ── 9. 邮箱登出（回退到设备匿名用户） ──
        auth.MapPost("/email-logout", async (HttpContext ctx, IAuthService authService) =>
        {
            var userId = ctx.User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Results.Problem(detail: "User identity not found.", statusCode: 401, title: "Unauthorized");

            try
            {
                await authService.EmailLogoutAsync(userId);
                return Results.NoContent();
            }
            catch (AuthException ex)
            {
                return Results.Problem(
                    detail: ex.Message,
                    statusCode: ex.StatusCode,
                    title: "Email Logout Failed",
                    extensions: new Dictionary<string, object?> { ["code"] = ex.Code });
            }
        })
        .RequireAuthorization()
        .WithName("EmailLogout");

        // ── 10. 更新用户资料（学习级别、教材等） ──
        auth.MapPatch("/profile", async (HttpContext ctx, IAuthService authService, UpdateProfileRequest request) =>
        {
            var userId = ctx.User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Results.Problem(detail: "User identity not found.", statusCode: 401, title: "Unauthorized");

            try
            {
                var profile = await authService.UpdateProfileAsync(userId, request);
                return Results.Ok(profile);
            }
            catch (AuthException ex)
            {
                return Results.Problem(
                    detail: ex.Message,
                    statusCode: ex.StatusCode,
                    title: "Update Profile Failed",
                    extensions: new Dictionary<string, object?> { ["code"] = ex.Code });
            }
        })
        .RequireAuthorization()
        .WithName("UpdateProfile");

        return app;
    }
}

