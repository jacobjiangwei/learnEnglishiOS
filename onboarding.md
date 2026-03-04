下面是整理后的完整、可直接使用的架构设计 Markdown 文档。
已统一模型、修正状态机逻辑、删除多余字段，并明确最佳实践与约束。

⸻

English Learning App

Architecture Design Document (v1.0)

⸻

1. System Overview

1.1 Architecture
	•	Client: iOS Application
	•	Backend: C# (.NET Web API, Stateless)
	•	Auth Model: OAuth2-based token mechanism
	•	Account Types:
	•	Device-bound Anonymous Account
	•	Email-bound Account (upgraded from anonymous)

1.2 Design Goals
	1.	支持匿名直接使用
	2.	支持平滑升级为 Email 账号
	3.	支持跨设备数据恢复（Email 用户）
	4.	严格控制无意义请求
	5.	后端支持高并发扩展
	6.	明确数据归属与状态机模型

⸻

2. Domain Model

系统核心拆分为三层：
	•	User（主体）
	•	UserIdentity（登录身份）
	•	UserProfile（学习信息）

⸻

2.1 User (主体实体)

class User
{
    Guid UserId;
    DateTime CreatedAt;
}

说明：
	•	User 是唯一数据归属主体
	•	升级账号不会创建新的 User
	•	User 生命周期独立于登录方式

⸻

2.2 UserIdentity (登录身份)

class UserIdentity
{
    Guid UserIdentityId;
    Guid UserId;
    IdentityType Type;   // Anonymous | Email
    string Identifier;   // deviceId 或 email
    bool Verified;       // Email 是否验证
}

关键原则
	•	一个 User 可以有多个 Identity
	•	Identity 仅用于登录
	•	Identity 不等于 User

数据库约束

Unique Index:
(Type, Identifier)

尤其：

(Anonymous, deviceId) 必须唯一
(Email, email) 必须唯一


⸻

2.3 UserProfile (学习信息)

class UserProfile
{
    Guid UserId;
    int Grade;
    string Semester;
    int CurrentUnit;
    bool OnboardingCompleted;
    DateTime UpdatedAt;
}

说明：
	•	Profile 永远绑定 User
	•	不绑定 Identity
	•	OnboardingCompleted 决定是否再次触发 onboarding

⸻

3. Account Lifecycle

⸻

3.1 Anonymous Account Creation

流程

App Launch
    ↓
检查本地是否存在 DeviceID
    ↓
无 → 生成随机 DeviceID
    ↓
发送 DeviceID 到 Backend
    ↓
Backend 查 UserIdentity
    ↓
存在 → 返回对应 User
不存在 → 创建新 User + Anonymous Identity

结果

User A
 └── Identity: Anonymous (deviceId=XYZ)


⸻

3.2 Email Upgrade Flow（关键）

设计原则
	•	升级 = 增加 Identity
	•	不创建新 User
	•	不删除 Anonymous Identity
	•	不改变 UserId

⸻

升级流程

User A
 └── Anonymous Identity (deviceId=XYZ)

用户输入 Email
    ↓
发送验证码
    ↓
验证成功
    ↓
创建 Email Identity
    ↓
重新签发 Token

升级后：

User A
 ├── Anonymous Identity (deviceId=XYZ)
 └── Email Identity (abc@email.com)


⸻

3.3 Logout Flow

设计原则：
	•	一个设备只允许一个 active session
	•	Logout 只清除当前 session
	•	不删除 Identity

⸻

场景：Email Logout

Email Logout
    ↓
清除当前 access/refresh token
    ↓
App 再次使用 DeviceID 登录
    ↓
查 Identity 表
    ↓
返回 User A

结果：
	•	回到同一个 User
	•	不会创建新 User
	•	数据不会分叉

⸻

4. Token Strategy

Token Type	Validity
Access Token	30 days
Refresh Token	1 year

原则
	•	不主动频繁刷新
	•	仅在以下情况刷新：
	•	Access token 已过期
	•	Access token 剩余有效期 < 7 天

⸻

App 启动行为

App Launch
    ↓
检查本地 Token
    ↓
如果有效 → 不请求后台
如果过期 → 使用 Refresh Token 更新

禁止行为：
	•	每次启动主动 renew
	•	周期性后台刷新
	•	心跳请求

目标：减少服务器负担

⸻

5. Onboarding System

⸻

5.1 触发条件

if (UserProfile.OnboardingCompleted == false)
    TriggerOnboarding();


⸻

5.2 完成流程

用户填写：
- Grade
- Semester
- CurrentUnit
    ↓
本地保存
    ↓
上传到云端
    ↓
OnboardingCompleted = true


⸻

5.3 App 再次启动行为

规则：
	•	如果本地 OnboardingCompleted == true
	•	假设当时已成功同步到云端
	•	不再请求后台确认

绝对不做：

每次启动 → 请求后台 → 检查是否完成

这是无意义请求。

⸻

6. Data Authority Model

用户类型	数据权威来源
Anonymous	Local First
Email	Cloud Source of Truth


⸻

Anonymous 用户
	•	Profile 上传仅作为备份
	•	不保证跨设备恢复

⸻

Email 用户
	•	云端为权威数据源
	•	新设备登录流程：

Email Login
    ↓
下载 Cloud Profile
    ↓
覆盖本地数据


⸻

7. DeviceID Strategy

生成方式
	•	首次安装生成随机 UUID
	•	本地持久化存储

安全注意
	•	不依赖系统硬件 ID
	•	不使用可变 Identifier
	•	允许卸载后生成新 DeviceID

⸻

8. State Machine Summary

⸻

状态 1：Anonymous Only

User A
 └── Anonymous Identity


⸻

状态 2：Upgraded

User A
 ├── Anonymous Identity
 └── Email Identity


⸻

状态 3：Email Active Session

Active Identity = Email


⸻

状态 4：Logout

Active Identity cleared
DeviceID login
→ Same User A


⸻

9. Backend Requirements

9.1 必须保证
	1.	Identity 唯一索引
	2.	查 Identity 优先于创建 User
	3.	升级不生成新 UserId
	4.	Logout 不删除 Identity

⸻

9.2 扩展性设计
	•	Stateless API
	•	Token-based auth
	•	Horizontal scaling ready
	•	低写入频率（Profile 变更极少）

⸻

10. Non-Goals
	•	不做频繁心跳
	•	不做实时 profile 校验
	•	不做多 active user per device
	•	不做复杂 merge 逻辑

⸻

11. Edge Cases

场景	行为
卸载 App	新 DeviceID → 新匿名用户
Email 重复注册	Unique constraint 阻止
同 Email 多设备登录	允许
Anonymous 升级后 Logout	回到同一 User


⸻

12. Final Design Principles
	1.	User 是唯一主体
	2.	Identity 只是登录方式
	3.	升级 = 增加 Identity
	4.	不创建新 User
	5.	不删除 Device Identity
	6.	Onboarding 一次完成后不再验证
	7.	减少无意义请求

⸻

Architecture Conclusion

本系统采用：
	•	多 Identity 单 User 模型
	•	OAuth2 token 管理
	•	本地优先 + 云端权威分离
	•	严格控制请求频率
	•	状态机自洽闭环设计

该设计：
	•	无数据分叉风险
	•	无 device reclaim 循环问题
	•	支持未来扩展（第三方登录、家长账号等）
	•	支持大规模并发

⸻

如果你愿意，下一步我可以：
	•	给你补一版数据库 DDL
	•	或输出 API Contract 设计
	•	或帮你画成系统架构图
	•	或设计未来的家庭账号扩展模型