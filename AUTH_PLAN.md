# Auth 方案规划：Apple 登录 + 自签 JWT

> 全球统一 Apple Sign-In，自建 JWT Token 管理，标准 ASP.NET JwtBearer 校验（Aspire 原生支持）

---

## 1. 整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        iOS 客户端                                │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐   │
│  │ Sign in with │    │  TokenStore  │    │   APIService     │   │
│  │    Apple      │    │  (Keychain)  │    │ Bearer + Refresh │   │
│  └──────┬───────┘    └──────────────┘    └────────┬─────────┘   │
│         │                                          │             │
└─────────┼──────────────────────────────────────────┼─────────────┘
          │ identityToken                            │ Authorization: Bearer xxx
          ▼                                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Volingo.Api (ASP.NET)                        │
│                                                                 │
│  ┌────────────────────┐   ┌────────────────────────────────┐    │
│  │  POST /auth/apple  │   │  AddAuthentication()           │    │
│  │  POST /auth/refresh│   │    .AddJwtBearer()             │    │
│  │  POST /auth/logout │   │  标准 ASP.NET middleware       │    │
│  └────────┬───────────┘   └────────────────────────────────┘    │
│           │                                                      │
│  ┌────────▼───────────────────────────────────────────────────┐  │
│  │              AuthService (自签 JWT)                         │  │
│  │  - 验证 Apple identityToken (Apple JWKS)                   │  │
│  │  - 签发 Access Token (JWT RS256, 30d)                       │  │
│  │  - 签发 Refresh Token (opaque, 1yr)                        │  │
│  │  - 刷新 / 吊销 Token                                       │  │
│  └────────┬───────────────────────────────────────────────────┘  │
│           │                                                      │
│  ┌────────▼──────────┐  ┌──────────────────┐                    │
│  │  Cosmos: users    │  │ Cosmos: tokens   │                    │
│  │  PK: /id          │  │ PK: /userId      │                    │
│  └───────────────────┘  └──────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. 认证流程

### 2.1 首次登录 / 注册（Sign in with Apple）

```
iOS                         Backend                          Apple
 │                            │                                │
 │ 1. ASAuthorizationAppleIDRequest                            │
 │───────────────────────────────────────────────────────────►  │
 │                            │                                │
 │ 2. identityToken + user + authorizationCode                 │
 │◄────────────────────────────────────────────────────────────│
 │                            │                                │
 │ 3. POST /api/v1/auth/apple │                                │
 │   { identityToken, fullName?, email? }                      │
 │──────────────────────────► │                                │
 │                            │ 4. Fetch Apple JWKS            │
 │                            │───────────────────────────────►│
 │                            │◄───────────────────────────────│
 │                            │                                │
 │                            │ 5. Validate identityToken      │
 │                            │    - 验证签名 (RS256)           │
 │                            │    - 验证 iss = appleid.apple.com
 │                            │    - 验证 aud = your Bundle ID  │
 │                            │    - 验证 exp 未过期             │
 │                            │                                │
 │                            │ 6. 提取 sub (Apple User ID)     │
 │                            │    查询/创建 users 文档         │
 │                            │    关联 deviceId → userId       │
 │                            │                                │
 │ 7. { accessToken, refreshToken, expiresIn, user }           │
 │◄─────────────────────────── │                                │
 │                            │                                │
 │ 8. 存储 tokens 到 Keychain  │                                │
```

### 2.2 Token 刷新

```
iOS                         Backend
 │                            │
 │ Access Token 过期（客户端检测 exp 或收到 401）
 │                            │
 │ POST /api/v1/auth/refresh  │
 │ { refreshToken }           │
 │──────────────────────────► │
 │                            │ 验证 refreshToken 存在且未过期
 │                            │ 签发新 accessToken
 │                            │ (可选) 轮换 refreshToken
 │                            │
 │ { accessToken, refreshToken?, expiresIn }
 │◄─────────────────────────── │
```

### 2.3 已登录用户正常请求

```
iOS                         Backend
 │                            │
 │ GET /api/v1/practice/questions
 │ Authorization: Bearer <accessToken>
 │ X-Device-Id: <deviceId>   (过渡期保留)
 │──────────────────────────► │
 │                            │ JwtBearer middleware 自动校验
 │                            │ 提取 ClaimsPrincipal
 │                            │ 获取 userId from claims
 │                            │
 │ 200 { questions... }       │
 │◄─────────────────────────── │
```

---

## 3. 数据模型

### 3.1 users 容器 (PK: `/id`)

```json
{
  "id": "user_xxxx",
  "appleUserId": "001234.abcdef...",
  "email": "xxx@privaterelay.appleid.com",
  "fullName": "张三",
  "displayName": "张三",
  "deviceIds": ["d1-uuid", "d2-uuid"],
  "level": "高一",
  "system": "国内",
  "textbookCode": "renjiaoban-g10-1",
  "createdAt": "2026-02-23T00:00:00Z",
  "lastLoginAt": "2026-02-23T12:00:00Z"
}
```

> **注意**: Apple 只在首次授权时返回 email 和 fullName，必须在第一次请求时持久化。

### 3.2 refreshTokens 容器 (PK: `/userId`)

```json
{
  "id": "rt_xxxx",
  "userId": "user_xxxx",
  "tokenHash": "sha256-of-refresh-token",
  "deviceId": "d1-uuid",
  "deviceInfo": "iPhone 15 Pro, iOS 19.0",
  "createdAt": "2026-02-23T12:00:00Z",
  "expiresAt": "2027-02-23T12:00:00Z",
  "isRevoked": false,
  "revokedAt": null
}
```

> 存 SHA-256 hash 而非明文；客户端 Keychain 持有明文。校验时后端对传入 token 算 hash 再匹配。
> 按 userId 分区，支持"查看所有登录设备"和"踢出某设备"。

### 3.3 JWT Access Token Claims

```json
{
  "sub": "user_xxxx",
  "iss": "volingo",
  "aud": "volingo-api",
  "iat": 1740000000,
  "exp": 1740000900,
  "deviceId": "d1-uuid",
  "role": "user"
}
```

| Claim    | 用途                                       |
| -------- | ------------------------------------------ |
| `sub`    | 用户 ID，替代 deviceId 做数据隔离主键       |
| `iss`    | 签发方标识                                  |
| `aud`    | 受众(API)，JwtBearer 校验时 match           |
| `exp`    | 过期时间，30 天                               |
| `deviceId` | 当前设备 ID，用于多设备管理               |
| `role`   | 预留角色：`user` / `admin`                  |

---

## 4. 后端实现

### 4.1 NuGet 依赖

```xml
<!-- Volingo.Api.csproj 新增 -->
<PackageReference Include="Microsoft.AspNetCore.Authentication.JwtBearer" Version="10.0.0" />
```

> JwtBearer 已包含 `Microsoft.IdentityModel.Tokens` 和 `System.IdentityModel.Tokens.Jwt`，无需单独引用。

### 4.2 JWT 配置 (appsettings.json)

```jsonc
{
  "Jwt": {
    "Issuer": "volingo",
    "Audience": "volingo-api",
    "AccessTokenExpiryDays": 30,
    "RefreshTokenExpiryDays": 365
    // RSA Private Key 通过文件路径 / Azure Key Vault 注入
  },
  "Apple": {
    "BundleId": "com.haibao-english.volingo"
    // Apple JWKS URL: https://appleid.apple.com/auth/keys (SDK 自动获取)
  }
}
```

### 4.3 Program.cs 注册 (标准 Aspire 方式)

```csharp
// ── RSA Key 加载 ──
// 开发环境: 从文件加载; 生产环境: 从 Azure Key Vault 加载
var rsaKey = RSA.Create();
rsaKey.ImportFromPem(File.ReadAllText(
    builder.Configuration["Jwt:PrivateKeyPath"]
    ?? throw new InvalidOperationException("Missing Jwt:PrivateKeyPath")));
var signingKey = new RsaSecurityKey(rsaKey);

// 注册为单例，签发 token 时使用
builder.Services.AddSingleton(signingKey);

// ── Authentication (标准 JwtBearer + RS256 公钥校验) ──
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        var jwtConfig = builder.Configuration.GetSection("Jwt");
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwtConfig["Issuer"],          // "volingo"

            ValidateAudience = true,
            ValidAudience = jwtConfig["Audience"],      // "volingo-api"

            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(1),

            ValidateIssuerSigningKey = true,
            IssuerSigningKey = signingKey               // RSA 公钥校验
            // RsaSecurityKey 同时持有公钥+私钥，
            // JwtBearer 只用公钥部分做验证
        };
    });

builder.Services.AddAuthorization();

// ── Auth service ──
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddSingleton<IJwtTokenService, JwtTokenService>();
builder.Services.AddSingleton<IAppleTokenValidator, AppleTokenValidator>();

// ... existing services ...

var app = builder.Build();

app.UseAuthentication();    // ← 在 MapEndpoints 之前
app.UseAuthorization();
```

> **RS256 vs HS256**: RS256 用 RSA 非对称密钥。私钥签发 token，公钥校验 token。
> 好处：如果以后拆微服务，其他服务只需要公钥就能校验 token，不需要知道私钥。
> ASP.NET JwtBearer 对 RS256 是一等公民支持，`RsaSecurityKey` 直接传入即可。

### 4.4 核心接口

```csharp
// ── IJwtTokenService.cs ──
public interface IJwtTokenService
{
    string GenerateAccessToken(string userId, string deviceId, string role = "user");
    string GenerateRefreshToken();                    // 随机 opaque token
    ClaimsPrincipal? ValidateAccessToken(string token); // 用于需要手动校验的场景
}

// ── IAppleTokenValidator.cs ──
public interface IAppleTokenValidator
{
    /// 验证 Apple identityToken，返回 Apple User ID (sub claim)
    Task<AppleTokenPayload> ValidateAsync(string identityToken);
}

// ── IAuthService.cs ──
public interface IAuthService
{
    Task<AuthResponse> SignInWithAppleAsync(AppleSignInRequest request);
    Task<AuthResponse> RefreshTokenAsync(string refreshToken);
    Task RevokeRefreshTokenAsync(string userId, string? tokenId = null); // null = 全部吊销
}
```

### 4.5 Auth Endpoints

```csharp
// ── Extensions/AuthEndpoints.cs ──
public static class AuthEndpoints
{
    public static WebApplication MapAuthEndpoints(this WebApplication app)
    {
        var auth = app.MapGroup("/api/v1/auth").WithTags("Auth");

        // 1. Apple 登录
        auth.MapPost("/apple", async (IAuthService authService, AppleSignInRequest request) =>
        {
            var response = await authService.SignInWithAppleAsync(request);
            return Results.Ok(response);
        })
        .AllowAnonymous();

        // 2. 刷新 Token
        auth.MapPost("/refresh", async (IAuthService authService, RefreshRequest request) =>
        {
            var response = await authService.RefreshTokenAsync(request.RefreshToken);
            return Results.Ok(response);
        })
        .AllowAnonymous();

        // 3. 登出（吊销 Refresh Token）
        auth.MapPost("/logout", async (HttpContext ctx, IAuthService authService) =>
        {
            var userId = ctx.User.FindFirstValue(ClaimTypes.NameIdentifier);
            await authService.RevokeRefreshTokenAsync(userId!);
            return Results.NoContent();
        })
        .RequireAuthorization();

        return app;
    }
}
```

### 4.6 已有 Endpoints 迁移

```csharp
// ── 改造前 ──
var deviceId = GetDeviceId(ctx);    // 从 X-Device-Id header 取

// ── 改造后 ──
var userId = ctx.User.FindFirstValue(ClaimTypes.NameIdentifier);   // 从 JWT claims 取
// deviceId 仍可从 JWT claims 或 header 获取（多设备场景）

// 所有需要用户身份的 endpoint 加 .RequireAuthorization()
app.MapGet("/api/v1/practice/questions", handler).RequireAuthorization();
app.MapPost("/api/v1/practice/submit", handler).RequireAuthorization();
app.MapGet("/api/v1/user/stats", handler).RequireAuthorization();
app.MapPost("/api/v1/wordbook/add", handler).RequireAuthorization();
// ...
```

---

## 5. iOS 客户端实现

### 5.1 新增文件结构

```
Services/
  Auth/
    AppleSignInService.swift     // ASAuthorizationController 封装
    AuthTokenStore.swift         // Keychain 存取 access/refresh token
    AuthManager.swift            // 登录状态管理、自动刷新
```

### 5.2 AppleSignInService 核心逻辑

```swift
import AuthenticationServices

class AppleSignInService: NSObject, ASAuthorizationControllerDelegate {
    func signIn() async throws -> AppleCredential {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        // ... perform request, return identityToken + user info
    }
}
```

### 5.3 AuthManager (状态管理 + 自动刷新)

```swift
@Observable
class AuthManager {
    private(set) var isAuthenticated = false
    private(set) var currentUser: User?
    
    private let tokenStore = AuthTokenStore()
    
    /// App 启动时检查
    func checkAuthState() async {
        guard let accessToken = tokenStore.accessToken else {
            isAuthenticated = false
            return
        }
        
        // 检查 JWT exp，过期则尝试 refresh
        if isTokenExpired(accessToken) {
            do {
                try await refreshToken()
            } catch {
                await signOut()
            }
        } else {
            isAuthenticated = true
        }
    }
    
    /// Apple 登录
    func signInWithApple() async throws {
        let credential = try await AppleSignInService().signIn()
        let response = try await APIService.shared.appleSignIn(
            identityToken: credential.identityToken,
            fullName: credential.fullName,
            email: credential.email
        )
        tokenStore.save(accessToken: response.accessToken,
                       refreshToken: response.refreshToken)
        currentUser = response.user
        isAuthenticated = true
    }
    
    /// Token 刷新
    func refreshToken() async throws {
        guard let refreshToken = tokenStore.refreshToken else { throw AuthError.noRefreshToken }
        let response = try await APIService.shared.refreshToken(refreshToken: refreshToken)
        tokenStore.save(accessToken: response.accessToken,
                       refreshToken: response.refreshToken ?? refreshToken)
    }
}
```

### 5.4 APIService 改造

```swift
// ── 改造 makeRequest ──
private func makeRequest(path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
    var request = URLRequest(url: URL(string: baseURL + path)!)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    // 新：附加 Bearer Token
    if let token = AuthManager.shared.tokenStore.accessToken {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    
    // 过渡期保留 device id
    request.setValue(DeviceIdManager.shared.deviceId, forHTTPHeaderField: "X-Device-Id")
    
    if let body { request.httpBody = body }
    return request
}

// ── 自动刷新：收到 401 时 ──
private func fetchWithAutoRefresh<T: Decodable>(_ type: T.Type, request: URLRequest) async throws -> T {
    do {
        return try await fetch(type, request: request)
    } catch APIServiceError.httpError(statusCode: 401, _) {
        // 尝试刷新 token
        try await AuthManager.shared.refreshToken()
        // 重建 request with new token
        var retryRequest = request
        if let token = AuthManager.shared.tokenStore.accessToken {
            retryRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return try await fetch(type, request: retryRequest)
    }
}
```

---

## 6. RSA Key 管理

### 6.1 生成 RSA 密钥对

```bash
# 生成 2048-bit RSA 私钥 (PEM 格式)
openssl genpkey -algorithm RSA -out volingo-private.pem -pkeyopt rsa_keygen_bits:2048

# 导出公钥 (可选，用于其他服务独立校验)
openssl rsa -in volingo-private.pem -pubout -out volingo-public.pem
```

### 6.2 开发环境

```csharp
// AppHost.cs — 通过环境变量指定私钥文件路径
var api = builder.AddProject<Projects.Volingo_Api>("volingo-api")
    .WithEnvironment("Jwt__PrivateKeyPath", "./keys/volingo-private.pem")
    // ... existing config
```

> 开发用的 PEM 文件放在 `volingoService/keys/` 目录，已加入 `.gitignore`。

### 6.3 生产环境

| 方式 | 推荐度 | 说明 |
|------|--------|------|
| **Azure Key Vault** | ★★★ | 存 RSA 私钥为 Key Vault Key，Aspire 原生支持 |
| App Service 文件挂载 | ★★ | 把 PEM 文件挂载到容器，通过路径读取 |
| 环境变量 (Base64) | ★ | PEM 内容 base64 编码存环境变量 |

```csharp
// 生产：Azure Key Vault 集成
var keyVault = builder.AddAzureKeyVault("keyvault");
var api = builder.AddProject<Projects.Volingo_Api>("volingo-api")
    .WithReference(keyVault);
```

---

## 7. 安全策略

| 项目 | 策略 |
|------|------|
| Access Token 有效期 | **30 天** |
| Refresh Token 有效期 | **1 年 (365 天)** |
| 签名算法 | **RS256 (RSA 非对称)** — 私钥签发，公钥校验 |
| Refresh Token 存储 | SHA-256 hash 存 Cosmos，明文只在客户端 Keychain |
| Refresh Token 轮换 | 每次 refresh 签发新 refresh token，旧的立即失效 |
| Apple Token 校验 | 从 Apple JWKS endpoint 获取公钥验证（带缓存） |
| HTTPS | 生产环境强制 HTTPS |
| Rate Limiting | `/auth/*` 端点限流，防暴力刷 token |

---

## 8. 数据迁移策略 (deviceId → userId)

### 8.1 核心原则

- **不中断现有用户**：未登录用户仍可使用 deviceId 模式
- **登录后自动合并**：首次 Apple 登录时，把当前 deviceId 的数据迁移到 userId

### 8.2 迁移流程

```
1. 用户首次 Apple 登录
2. 后端创建 user 文档，记录 deviceIds: [当前deviceId]
3. 后端异步迁移该 deviceId 下的 completions/wordbook 数据
   - completions: 添加 userId 字段，保留 deviceId
   - wordbook: 添加 userId 字段，保留 deviceId
4. 新数据以 userId 为主键写入
5. 查询时优先按 userId，fallback 到 deviceId (过渡期)
```

### 8.3 容器 Partition Key 演进

| 容器 | 当前 PK | 过渡期 PK | 最终 PK |
|------|---------|-----------|---------|
| completions | `/deviceId` | `/deviceId` (不变，加 userId 字段) | 新容器 `/userId` |
| wordbook | `/deviceId` | `/deviceId` (不变，加 userId 字段) | 新容器 `/userId` |
| users | — | `/id` | `/id` |
| refreshTokens | — | `/userId` | `/userId` |

> Cosmos DB 不支持修改已有容器的 PK，最终需要创建新容器并迁移数据。过渡期通过添加 userId 字段 + 查询逻辑兼容。

---

## 9. 实施步骤 (分阶段)

### Phase 1：后端 Auth 基础设施 (1-2 天)

- [ ] 添加 `Microsoft.AspNetCore.Authentication.JwtBearer` 依赖
- [ ] 实现 `JwtTokenService` (签发 / 校验 access token)
- [ ] 实现 `AppleTokenValidator` (验证 Apple identityToken)
- [ ] 实现 `AuthService` (注册/登录/刷新/吊销)
- [ ] 添加 `users` 和 `refreshTokens` Cosmos 容器
- [ ] 注册 Authentication + Authorization middleware
- [ ] 添加 `/api/v1/auth/*` endpoints
- [ ] 生成 RSA 密钥对 (openssl)，AppHost 注入 PrivateKeyPath

### Phase 2：iOS 客户端 (1-2 天)

- [ ] 实现 `AppleSignInService` (ASAuthorizationController 封装)
- [ ] 实现 `AuthTokenStore` (Keychain 存取 token)
- [ ] 实现 `AuthManager` (全局登录状态管理)
- [ ] 改造 `APIService`：附加 Bearer token + 401 自动刷新
- [ ] 添加登录/登出 UI (Onboarding flow 集成)
- [ ] Xcode 项目添加 Sign in with Apple capability

### Phase 3：渐进迁移 (1 天)

- [ ] 已有 endpoints 加 `.RequireAuthorization()`
- [ ] Handler 内 deviceId → userId 替换
- [ ] 数据迁移逻辑 (首次登录时合并 deviceId 数据)
- [ ] 保留 `X-Device-Id` header 兼容检查

### Phase 4：生产加固

- [ ] Azure Key Vault 管理 signing key
- [ ] Auth endpoints rate limiting
- [ ] Apple JWKS 缓存 (避免每次请求 Apple)
- [ ] Token refresh 日志 & 监控
- [ ] 删除 deviceId fallback 代码 (确认全量迁移完成后)

---

## 10. API 协议 (Request / Response)

### POST `/api/v1/auth/apple`

**Request:**
```json
{
  "identityToken": "eyJhbGciOi...",
  "fullName": "张三",
  "email": "xxx@privaterelay.appleid.com",
  "deviceId": "d1-uuid"
}
```

**Response (200):**
```json
{
  "accessToken": "eyJhbGciOi...",
  "refreshToken": "rt_xxxxxxxxxxxxxxxx",
  "expiresIn": 2592000,
  "user": {
    "id": "user_xxxx",
    "displayName": "张三",
    "email": "xxx@privaterelay.appleid.com"
  }
}
```

> `expiresIn`: 2592000 秒 = 30 天

### POST `/api/v1/auth/refresh`

**Request:**
```json
{
  "refreshToken": "rt_xxxxxxxxxxxxxxxx"
}
```

**Response (200):**
```json
{
  "accessToken": "eyJhbGciOi...",
  "refreshToken": "rt_yyyyyyyyyyyyyyyy",
  "expiresIn": 2592000
}
```

### POST `/api/v1/auth/logout`

**Headers:** `Authorization: Bearer <accessToken>`

**Response:** `204 No Content`

---

## 11. 为什么选 JwtBearer (而非其他方案)

| 方案 | 优点 | 缺点 | 适用场景 |
|------|------|------|----------|
| **ASP.NET JwtBearer** ✅ | Aspire 原生支持、标准化、无状态校验、社区成熟 | 需自己管理 signing key | **本项目** |
| IdentityServer / Duende | 功能全面 (OAuth2 全流程) | 重量级、License 费用 | 企业级多 Client |
| Azure AD B2C | 托管、免开发 | 配置复杂、Apple 登录需额外 OpenID 配置 | 不想自建 auth |
| Firebase Auth | 简单、Apple 登录开箱即用 | 依赖 Google、不走标准 JwtBearer | 已绑定 Firebase |

JwtBearer 是 ASP.NET 生态的标准认证方案，`AddAuthentication().AddJwtBearer()` 是 Aspire 文档推荐的方式，能直接与 `RequireAuthorization()` 配合，无需引入额外框架。
