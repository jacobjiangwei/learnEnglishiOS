# 海豹英语 — 用户认证与 Onboarding 设计文档

## 目录

1. [核心概念](#1-核心概念)
2. [用户类型](#2-用户类型)
3. [认证流程](#3-认证流程)
4. [API 清单（现状 vs 改动）](#4-api-清单)
5. [数据模型变更](#5-数据模型变更)
6. [Onboarding 流程](#6-onboarding-流程)
7. [数据合并策略](#7-数据合并策略)
8. [iOS 客户端变更](#8-ios-客户端变更)
9. [实施计划](#9-实施计划)

---

## 1. 核心概念

| 概念 | 说明 |
|------|------|
| **设备 ID** | 弱标识符。安装即生成，存于 Keychain。一台设备始终有一个 deviceId |
| **邮箱** | 强标识符。用户主动绑定/登录后获得，跨设备通用 |
| **无密码** | 所有邮箱操作都通过 6 位验证码完成，**不再使用密码** |
| **Token** | RS256 JWT access token + refresh token。用户身份切换时重新颁发 |

### 设计原则

- **零摩擦启动**：首次打开 App 无需注册/登录，先完成 onboarding（选级别+教材），onboarding 完成后才创建匿名用户
- **不浪费资源**：未完成 onboarding 的用户不会在服务端创建任何账号，避免产生大量垃圾数据
- **邮箱是主身份**：一旦绑定邮箱，该邮箱账号就是「真正的用户」
- **设备是弱关联**：DeviceId 只用于匿名访问和设备关联，email 用户在任何设备登录时会「接管」该设备
- **登出 ≠ 注销**：登出邮箱 = 回退到设备匿名用户，邮箱账号及其数据保留在云端

---

## 2. 用户类型

### 2.1 匿名用户（Anonymous / Device User）

- 自动创建，`type = "anonymous"`
- 通过 DeviceId 识别
- 数据仅在当前设备可用
- 可升级为邮箱用户（通过绑定邮箱）

### 2.2 邮箱用户（Email User）

- 拥有已验证邮箱，`type = "email"`
- 通过邮箱识别，跨设备可用
- 在新设备登录时自动关联该设备的 DeviceId
- 学习数据同步到云端

### 2.3 用户生命周期

```
┌─────────────────────────────────────────────────────────┐
│  安装 App                                                │
│  ├── 进入 onboarding（本地流程，无需网络）                │
│  │   ├── Welcome 页：可选择「开始学习」或「注册/登录」    │
│  │   ├── 选级别 + 选教材                                 │
│  │   └── 完成 onboarding → POST /device 创建 anonymous   │
│  │       user + PATCH /profile 保存级别教材               │
│  ├── 正常使用…                                           │
│  │                                                       │
│  ├── [绑定邮箱] → 发验证码 → 验证                         │
│  │   ├── 邮箱是新的 → 升级当前用户: type anonymous→email  │
│  │   └── 邮箱已存在 → 合并到邮箱账号 (见§7)               │
│  │                                                       │
│  ├── [登出邮箱] → 回退到 anonymous user                   │
│  │   ├── 找回该设备的 anonymous user (by deviceId)        │
│  │   └── 如果不存在 → 自动创建新的 anonymous user         │
│  │                                                       │
│  └── [重新登录] → 邮箱验证码 → 恢复邮箱账号               │
└─────────────────────────────────────────────────────────┘
```

### 2.4 一台设备上的用户关系

```
Device (deviceId = "abc123")
  │
  ├── anonymous user A  ← 安装时自动创建
  │     └── 后来绑定了 user@example.com → 合并到 email user B
  │
  ├── email user B (user@example.com)  ← 通过绑定/登录获得
  │     └── 登出 → 回到 anonymous user C
  │
  ├── anonymous user C  ← 登出后自动创建的新匿名用户
  │     └── 可以继续使用，或再绑定另一个邮箱
  │
  └── ...
```

> 一台设备可能有多个 UserDocument，但同一时刻只有一个活跃用户（持有 token 的那个）。

---

## 3. 认证流程

### 3.1 设备自动登录（App 启动）

```
App 启动
  ├── 有有效 access token? → GET /me → 进入主界面
  ├── access token 过期但有 refresh token? → POST /refresh → 拿到新 token
  └── 无任何 token?
      ├── 已完成 onboarding（本地有 level 数据）?
      │   └── POST /device { deviceId } → 创建/恢复 anonymous user
      └── 未完成 onboarding?
          └── 进入 onboarding 流程（不创建用户）
```

**关键变更**：首次安装时不再立即调用 `/device`。只有在 onboarding 完成后（或从 email-logout 回退时）才创建匿名用户。这避免了用户刚打开 App 就产生大量无意义的账号。

### 3.2 邮箱登录（注册/登录统一）

**目标**：用户输入邮箱 → 收验证码 → 输入验证码 → 完成。无密码。

```
用户输入邮箱
  │
  ├── POST /send-login-code { email, deviceId }
  │   └── 服务端发送验证码（不管邮箱是否已注册）
  │
  ├── 用户输入 6 位验证码
  │
  └── POST /verify-login-code { email, code, deviceId }
      ├── 邮箱已存在 → 登录该 email user，设置 deviceId
      └── 邮箱不存在 → 自动注册 email user (type="email")，设置 deviceId
```

**iOS 端**：
- EmailLoginView 简化为 2 步：输入邮箱 → 输入验证码
- 移除密码输入框和 `passwordLogin()` 方法

### 3.3 绑定邮箱（匿名用户升级）

**场景**：用户已经是 anonymous user，想绑定邮箱。

```
[已登录的 anonymous user]
  │
  ├── POST /bind-email { email }     ← 移除 password 参数
  │   └── 发送验证码到邮箱
  │
  ├── 用户输入 6 位验证码
  │
  └── POST /verify-email { code }
      ├── 邮箱是新的:
      │   └── 当前用户绑上邮箱，type: anonymous → email
      │
      └── 邮箱已属于另一个 email user:
          └── 合并：把当前设备 deviceId 写到 email user 上
              颁发 email user 的 token（身份切换）
              (学习数据合并见 §7)
```

**iOS 端**：
- BindEmailView 移除密码和确认密码输入框
- 只需要：邮箱输入 → 发验证码 → 输入验证码 → 完成

### 3.4 登出邮箱（回退到匿名用户）

**语义**："登出"不是注销账号，而是退出邮箱登录，回退到设备匿名用户。

```
[已登录的 email user]
  │
  └── POST /email-logout
      ├── 服务端：吊销当前 token
      ├── 服务端：不再关联该 deviceId 到 email user（可选）
      │
      └── 客户端：
          ├── 清除 Keychain 中的 token
          ├── POST /device { deviceId } → 获取/创建 anonymous user
          ├── 清除本地 onboarding 状态
          └── 进入 onboarding 流程（如果 anonymous user 无 level 数据）
```

**替代现有的**：`POST /unbind-email`（行为改变，见 §4）

### 3.5 Token 刷新

**不变**，现有逻辑保留。

---

## 4. API 清单

### 现有 API：保留不变

| # | 方法 | 路径 | Auth | 说明 | 改动 |
|---|------|------|------|------|------|
| 1 | POST | `/api/v1/auth/device` | ❌ | 设备自动登录 | ✅ 不变 |
| 2 | POST | `/api/v1/auth/refresh` | ❌ | 刷新 token | ✅ 不变 |
| 3 | POST | `/api/v1/auth/logout` | ✅ | 吊销 refresh token | ✅ 不变 |
| 4 | GET | `/api/v1/auth/me` | ✅ | 获取当前用户信息 | ✅ 不变 |
| 5 | PATCH | `/api/v1/auth/profile` | ✅ | 更新学习资料 | ✅ 不变 |

### 现有 API：需要修改

| # | 方法 | 路径 | Auth | 现状 | 改动 |
|---|------|------|------|------|------|
| 6 | POST | `/bind-email` | ✅ | `BindEmailRequest(Email, Password)` | **移除 Password** → `BindEmailRequest(Email)` |
| 7 | POST | `/verify-email` | ✅ | 绑定时存 PasswordHash | **不再存 PasswordHash**，merge 时不涉及密码 |
| 8 | POST | `/send-login-code` | ❌ | `SendLoginCodeRequest(Email)` | **加 DeviceId** → `SendLoginCodeRequest(Email, DeviceId?)` |
| 9 | POST | `/verify-login-code` | ❌ | 自动注册新用户 | **新用户 type="email"**，已有逻辑基本保留 |

### 现有 API：移除

| # | 方法 | 路径 | 说明 | 处置 |
|---|------|------|------|------|
| 10 | POST | `/unbind-email` | 解绑邮箱 | **删除** — 替换为 `/email-logout` |
| 11 | POST | `/email-login` | 邮箱+密码登录 | **删除** — 不再支持密码登录 |

### 新增 API

| # | 方法 | 路径 | Auth | 说明 |
|---|------|------|------|------|
| 12 | POST | `/api/v1/auth/email-logout` | ✅ | 登出邮箱，回退到设备匿名用户。吊销当前 token，客户端再调 `/device` 获取匿名用户 |

#### `POST /email-logout` 详细设计

**请求**：无 body（userId 从 JWT 获取）

**服务端逻辑**：
1. 吊销该 userId 的所有 refresh token
2. （可选）清除 email user 的 DeviceId 字段，防止设备登录时误匹配到 email user
3. 返回 204

**客户端逻辑**：
1. 调用 `POST /email-logout`
2. 清除本地 Keychain token
3. 调用 `POST /device { deviceId }` 创建/恢复匿名用户
4. 重新进入 onboarding（如果匿名用户无 level 数据） 或直接进入主界面

---

## 5. 数据模型变更

### 5.1 UserDocument（后端 Cosmos DB）

```diff
  public class UserDocument
  {
      public string Id { get; set; } = "";
+     public string Type { get; set; } = "anonymous";  // "anonymous" | "email"
      public string? DeviceId { get; set; }
      public string? Email { get; set; }
-     public string? PasswordHash { get; set; }         // 移除：不再需要密码
      public bool IsEmailVerified { get; set; }
      public DateTime? EmailVerifiedAt { get; set; }
      public string? FullName { get; set; }
      public string? DisplayName { get; set; }
      public string? Level { get; set; }
      public string? System { get; set; }
      public string? TextbookCode { get; set; }
      public string? Semester { get; set; }
      public DateTime CreatedAt { get; set; }
      public DateTime LastLoginAt { get; set; }
  }
```

> **注意**：现有数据库中的老用户 PasswordHash 可保留（向下兼容），但新代码不再写入或读取。Type 字段对已有文档默认视为 `"anonymous"`（Cosmos DB 读不到该字段时用默认值）。

### 5.2 EmailVerificationDocument

```diff
  public class EmailVerificationDocument
  {
      public string Id { get; set; } = "";
      public string UserId { get; set; } = "";
      public string Email { get; set; } = "";
      public string Code { get; set; } = "";
-     public string PasswordHash { get; set; } = "";    // 移除
      public DateTime CreatedAt { get; set; }
      public DateTime ExpiresAt { get; set; }
      public int Ttl { get; set; } = 600;
  }
```

### 5.3 DTO 变更

```diff
- public record BindEmailRequest(string Email, string Password);
+ public record BindEmailRequest(string Email);

- public record EmailLoginRequest(string Email, string Password, string? DeviceId = null);
  // 整个 record 删除 — 不再支持密码登录

- public record SendLoginCodeRequest(string Email);
+ public record SendLoginCodeRequest(string Email, string? DeviceId = null);

  // UserProfile 加上 Type
  public record UserProfile(
      string Id,
+     string Type,
      string? DisplayName,
      string? Email,
      bool IsEmailVerified,
      string? Level = null,
      string? TextbookCode = null,
      string? Semester = null);
```

### 5.4 ErrorCodes 变更

```diff
  public static class AuthErrorCodes
  {
      public const string InvalidRefreshToken = "invalid_refresh_token";
      public const string UserNotFound = "user_not_found";
      public const string EmailAlreadyVerified = "email_already_verified";
      public const string NoPendingVerification = "no_pending_verification";
      public const string CodeExpired = "code_expired";
      public const string InvalidCode = "invalid_code";
-     public const string InvalidCredentials = "invalid_credentials";  // 移除：不再有密码
      public const string InvalidLoginCode = "invalid_login_code";
      public const string NoEmailBound = "no_email_bound";
+     public const string NotEmailUser = "not_email_user";             // email-logout 时用户不是邮箱用户
  }
```

### 5.5 iOS AuthUserProfile

```diff
  struct AuthUserProfile: Codable {
      let id: String
+     let type: String?         // "anonymous" | "email"
      let displayName: String?
      let email: String?
      let isEmailVerified: Bool?
      let level: String?
      let textbookCode: String?
      let semester: String?
  }
```

---

## 6. Onboarding 流程

### 6.1 总览

onboarding 是纯客户端流程，在 **无登录状态** 下进行。目的是让用户选择学习级别和教材。
完成后才创建服务端用户。

```
App 首次启动（无 token，无本地 onboarding 数据）
  │
  └── 进入 onboarding 流程（此时无服务端用户，无 token）
      │
      ├── Step 1: Welcome（品牌页）
      │   ├── 🦭 海豹英语 品牌展示
      │   ├── CTA: "开始学习" → 进入 Step 2（继续无登录状态）
      │   └── CTA: "注册/登录" → 弹出 EmailLoginView
      │       └── 登录成功后：
      │           ├── 云端有 level 数据 → 恢复到本地，跳过 onboarding，直接进入主界面
      │           └── 云端无 level 数据 → 进入 Step 2（此时已有 token）
      │
      ├── Step 2: Level Select（选择学习级别）
      │   └── 用户选定一个 UserLevel
      │
      ├── Step 3: Textbook Select（多教材时选教材）
      │   └── 如果该级别只有一个教材选项，自动跳过
      │
      └── 完成:
          ├── 已有 token（通过 Step 1 登录了邮箱）?
          │   └── PATCH /profile 同步级别教材到云端
          └── 无 token（走的「开始学习」路径）?
              └── POST /device 创建 anonymous user
                  → PATCH /profile 保存级别教材
                  → 进入主界面
```

### 6.2 Onboarding 完成后同步

当 onboarding 完成时（不管是选完级别还是从云端恢复），都要调用：

```
PATCH /api/v1/auth/profile {
    "level": "junior1",
    "textbookCode": "juniorPEP",
    "semester": "first"
}
```

确保云端和本地一致。

### 6.3 登出后的 Onboarding

当用户从 email user 登出后：
- 客户端创建/恢复一个 anonymous user
- 该 anonymous user 可能没有 level 数据
- 如果没有 → 重新进入 onboarding
- 如果有（之前这台设备上用过的匿名账号）→ 直接进入主界面

---

## 7. 数据合并策略

### 7.1 触发场景

当 anonymous user 绑定邮箱，且该邮箱已属于另一个 email user 时，需要合并数据。

### 7.2 合并对象

| 数据 | Cosmos 容器 | Partition Key |
|------|-------------|---------------|
| 学习完成记录 | completions | /userId |
| 单词本 | wordbook | /userId |
| 错题本 | （如有） | /userId |
| 用户画像 | users | /id |

### 7.3 合并规则

**原则：取进度更多的一方**

```
对于每个数据维度:
  if count(anonymous_user_data) > count(email_user_data):
      把 anonymous_user_data 复制到 email_user_userId 下
  else:
      保留 email_user_data（不动）
```

**用户画像合并**：
- `Level`, `TextbookCode`, `Semester`：以 email user 为准（如果有值）
- `DisplayName`：以 email user 为准（如果有值）

### 7.4 合并时机

在 `VerifyEmailAsync` 中，当检测到邮箱属于另一个用户时执行合并。

### 7.5 MVP 简化方案

**第一阶段可以不做数据合并**，只做身份切换：
- anonymous user 的数据留在原 userId 下（变成孤儿数据）
- email user 保留自己的数据
- 用户体验：绑定后可能「丢失」匿名阶段的学习记录

**理由**：大多数用户在使用初期（数据很少时）就会绑定邮箱，合并的实际价值有限。

---

## 8. iOS 客户端变更

### 8.1 EmailLoginView → 简化为纯验证码

**现状**：3 步（邮箱 → 密码+发验证码 → 验证码）
**目标**：2 步（邮箱 → 验证码）

```
Step 1: 输入邮箱 → 点「继续」→ 自动发送验证码
Step 2: 输入 6 位验证码 → 自动登录/注册
```

**删除**：
- `password` 字段
- `passwordLogin()` 方法
- credentials step（密码+发验证码的中间页）
- EmailLoginRequest 的 password 参数

### 8.2 BindEmailView → 移除密码

**现状**：邮箱 + 密码 + 确认密码 → 发验证码 → 输入验证码
**目标**：邮箱 → 发验证码 → 输入验证码

**删除**：
- `password` 和 `confirmPassword` 字段
- `canSendCode` 中的密码校验
- 两个 SecureField

### 8.3 ProfileView → "登出" 替换 "解除绑定"

**现状**：BindEmailView 中有"解除绑定"按钮，调用 `unbindEmail()`
**目标**：按钮文案改为"退出邮箱登录"，行为变为：

1. 调 `POST /email-logout`
2. 清除 token
3. 调 `POST /device` 获取匿名用户
4. 根据匿名用户是否有 level 数据决定是否重新 onboarding

```swift
func emailLogout() async throws {
    // 1. Server-side: revoke tokens
    try await APIService.shared.emailLogout()
    // 2. Clear local tokens
    AuthTokenStore.shared.clearAll()
    // 3. Re-login as anonymous
    try await autoSignIn()  // will call /device
    // 4. Reset onboarding if needed
    // → RootView 会根据 userState.isOnboardingCompleted 自动处理
}
```

### 8.4 AuthManager 变更

```diff
  // 删除
- func emailLogin(email: String, password: String) async throws
- func bindEmail(email: String, password: String) async throws
- func unbindEmail() async throws

  // 修改
+ func bindEmail(email: String) async throws     // 无 password
+ func emailLogout() async throws                 // 替代 unbindEmail

  // 保留不变
  func sendLoginCode(email: String) async throws
  func verifyLoginCode(email: String, code: String) async throws
  func verifyEmailBinding(code: String) async throws
```

### 8.5 APIService 变更

```diff
  // 删除
- func emailLogin(email: String, password: String) async throws -> AuthResponse
- func unbindEmail() async throws

  // 修改
- func bindEmail(email: String, password: String) async throws
+ func bindEmail(email: String) async throws      // body 只有 email

  // 新增
+ func emailLogout() async throws                 // POST /email-logout

  // 保留不变
  func sendLoginCode(email: String) async throws
  func verifyLoginCode(email: String, code: String) async throws -> AuthResponse
```

### 8.6 Error Code 映射更新

```diff
  // 删除
- case "invalid_credentials": return "邮箱或密码错误"

  // 新增
+ case "not_email_user": return "当前不是邮箱账户，无法登出"
```

---

## 9. 实施计划

### Phase 1: 后端改造

1. **UserDocument 加 Type 字段**，默认 `"anonymous"`
2. **BindEmailRequest 移除 Password**，BindEmailAsync 不再 hash 密码
3. **EmailVerificationDocument 移除 PasswordHash**
4. **VerifyEmailAsync 不再写 PasswordHash**，绑定时设 `type = "email"`
5. **删除 SignInWithEmailAsync**（密码登录）
6. **删除 UnbindEmailAsync**
7. **新增 EmailLogoutAsync**：吊销 token + 清除 email user 的 DeviceId
8. **更新 AuthEndpoints**：删除 `/email-login`、`/unbind-email`，新增 `/email-logout`
9. **UserProfile 加 Type 字段**
10. **SendLoginCodeRequest 加 DeviceId**（已有? 确认）
11. **删除 PasswordHasher 依赖**（如不再使用可移除 DI 注册）

### Phase 2: iOS 改造

1. **EmailLoginView**：删除 credentials 步骤，emailInput → 自动发验证码 → 输入验证码
2. **BindEmailView**：删除密码相关字段和 UI
3. **BindEmailView**：将"解除绑定"改为"退出邮箱登录"，调用 emailLogout
4. **AuthManager**：删除 `emailLogin`、`unbindEmail`，新增 `emailLogout`
5. **APIService**：删除 `emailLogin()`、`unbindEmail()`，修改 `bindEmail()`，新增 `emailLogout()`
6. **AuthUserProfile**：加 `type` 字段
7. **Error code 映射**：移除 `invalid_credentials`，加 `not_email_user`
8. **Onboarding 完成时**：调用 PATCH /profile 同步云端

### Phase 3: 数据合并（可延后）

1. 实现 completions/wordbook 的 count 比较逻辑
2. 在 VerifyEmailAsync 的合并分支中执行跨容器数据迁移
3. 测试边界情况（两边都为空、两边数据量相同等）

---

## 附录：完整 API 对照表（改造后）

| # | 方法 | 路径 | Auth | 说明 |
|---|------|------|------|------|
| 1 | POST | `/api/v1/auth/device` | ❌ | 设备自动登录，创建/恢复 anonymous user |
| 2 | POST | `/api/v1/auth/refresh` | ❌ | 刷新 token（token rotation） |
| 3 | POST | `/api/v1/auth/logout` | ✅ | 吊销所有 refresh token |
| 4 | GET | `/api/v1/auth/me` | ✅ | 获取当前用户信息 |
| 5 | POST | `/api/v1/auth/bind-email` | ✅ | 绑定邮箱（发验证码），body: `{ email }` |
| 6 | POST | `/api/v1/auth/verify-email` | ✅ | 验证邮箱验证码，完成绑定或合并 |
| 7 | POST | `/api/v1/auth/send-login-code` | ❌ | 发送登录验证码（注册/登录通用） |
| 8 | POST | `/api/v1/auth/verify-login-code` | ❌ | 验证登录码，自动注册或登录 |
| 9 | POST | `/api/v1/auth/email-logout` | ✅ | 登出邮箱，回退到设备匿名用户 |
| 10 | PATCH | `/api/v1/auth/profile` | ✅ | 更新用户资料（level, textbook, semester） |

**删除的 API**：
- ~~POST `/api/v1/auth/email-login`~~ — 密码登录，**已移除**
- ~~POST `/api/v1/auth/unbind-email`~~ — 解绑邮箱，**替换为 `/email-logout`**
