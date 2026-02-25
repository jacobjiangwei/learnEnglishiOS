using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.IdentityModel.Tokens;

namespace Volingo.Api.Services;

/// <summary>
/// JWT token service using RS256 (RSA asymmetric signing).
/// Private key signs tokens; public key (embedded in RsaSecurityKey) verifies them.
/// </summary>
public class JwtTokenService : IJwtTokenService
{
    private readonly RsaSecurityKey _signingKey;
    private readonly string _issuer;
    private readonly string _audience;
    private readonly int _accessTokenExpiryDays;

    public JwtTokenService(RsaSecurityKey signingKey, IConfiguration configuration)
    {
        _signingKey = signingKey;
        _issuer = configuration["Jwt:Issuer"] ?? "volingo";
        _audience = configuration["Jwt:Audience"] ?? "volingo-api";
        _accessTokenExpiryDays = int.TryParse(configuration["Jwt:AccessTokenExpiryDays"], out var d) ? d : 30;
    }

    public string GenerateAccessToken(string userId, string? deviceId = null, string role = "user")
    {
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, userId),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new(ClaimTypes.Role, role)
        };

        if (deviceId is not null)
            claims.Add(new Claim("deviceId", deviceId));

        var credentials = new SigningCredentials(_signingKey, SecurityAlgorithms.RsaSha256);

        var token = new JwtSecurityToken(
            issuer: _issuer,
            audience: _audience,
            claims: claims,
            notBefore: DateTime.UtcNow,
            expires: DateTime.UtcNow.AddDays(_accessTokenExpiryDays),
            signingCredentials: credentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public string GenerateRefreshToken()
    {
        var bytes = RandomNumberGenerator.GetBytes(32);
        return $"rt_{Convert.ToBase64String(bytes).Replace("+", "-").Replace("/", "_").TrimEnd('=')}";
    }

    public string HashToken(string token)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(token));
        return Convert.ToHexStringLower(bytes);
    }
}
