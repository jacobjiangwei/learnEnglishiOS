//
//  AuthManager.swift
//  海豹英语
//
//  Global authentication state manager.
//  Uses device ID auto-login — zero friction, no login screen.
//

import Foundation

// MARK: - Auth Error

enum AuthError: Error, LocalizedError {
    case noRefreshToken
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .noRefreshToken:             return "登录已过期，请重新登录"
        case .serverError(let msg):       return msg
        }
    }
}

// MARK: - Auth Response Models

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: AuthUserProfile
}

struct AuthUserProfile: Codable {
    let id: String
    let displayName: String?
    let email: String?
    let hasEmailIdentity: Bool
    let onboardingCompleted: Bool
    let grade: String?
    let publisher: String?
    let semester: String?
    let currentUnit: Int?
    
    var isEmailUser: Bool { hasEmailIdentity }
}

// MARK: - Auth Manager

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: AuthUserProfile?
    @Published private(set) var isLoading = true   // start true — prevents ContentView until signIn finishes
    @Published var errorMessage: String?
    
    private let tokenStore = AuthTokenStore.shared
    
    private init() {}
    
    // MARK: - 启动登录
    
    /// App 启动时调用。
    /// 有效 token → 直接认证；过期或 < 7天 → refresh；无 token → 自动创建设备用户。
    func signIn() async {
        isLoading = true
        defer { isLoading = false }
        
        // 1. AT 有效且剩余 > 7 天 → 直接登录，不浪费网络请求
        if tokenStore.accessToken != nil && !tokenStore.isAccessTokenExpired() {
            let remainingDays = tokenStore.accessTokenRemainingDays() ?? 0
            if remainingDays > 7 {
                isAuthenticated = true
                print("[Auth] ✅ Token 有效（剩余 \(remainingDays) 天），已登录")
                return
            }
            // AT valid but < 7 days → proactive refresh below
            print("[Auth] ⚠️ Token 有效但剩余仅 \(remainingDays) 天，主动刷新")
        }
        
        // 2. AT 过期/缺失/即将过期，有 RT → 刷新（返回值自带 user profile）
        if tokenStore.refreshToken != nil {
            do {
                try await refreshToken()
                return
            } catch {
                print("[Auth] ❌ Token 刷新失败: \(error)")
                tokenStore.clearAll()
            }
        }
        
        // 3. 无有效 token，邮箱用户 → 等待手动重新登录
        if tokenStore.wasEmailUser {
            print("[Auth] 🔒 邮箱用户 token 失效，等待重新登录")
            isAuthenticated = false
            return
        }
        
        // 4. 设备用户 / 首次启动 → 自动注册
        do {
            try await createDeviceUser()
        } catch {
            print("[Auth] ❌ 创建设备用户失败: \(error)")
        }
    }
    
    // MARK: - Device Sign-In (called after onboarding completes)
    
    func createDeviceUser() async throws {
        let deviceId = DeviceIdManager.shared.deviceId
        print("[Auth] 📱 createDeviceUser deviceId=\(deviceId)")
        let response = try await APIService.shared.deviceSignIn(deviceId: deviceId)
        
        tokenStore.saveTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
        currentUser = response.user
        isAuthenticated = true
        
        // If the device identity is linked to an email user, mark that
        tokenStore.wasEmailUser = response.user.hasEmailIdentity
        
        print("[Auth] ✅ 设备用户创建/恢复成功 userId=\(response.user.id), isEmailUser=\(response.user.hasEmailIdentity)")
    }
    
    // MARK: - Token Lifecycle
    
    func refreshToken() async throws {
        guard let refreshToken = tokenStore.refreshToken else {
            throw AuthError.noRefreshToken
        }
        print("[Auth] 🔄 refreshToken 请求中…")
        let response = try await APIService.shared.refreshAuthToken(refreshToken: refreshToken)
        tokenStore.saveTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
        isAuthenticated = true
        currentUser = response.user
        tokenStore.wasEmailUser = response.user.hasEmailIdentity
        print("[Auth] ✅ Token 已更新 userId=\(response.user.id)")
    }
    
    func signOut() async {
        print("[Auth] 🚪 signOut userId=\(currentUser?.id ?? "none")")
        if tokenStore.accessToken != nil {
            try? await APIService.shared.logout()
        }
        tokenStore.clearAll()
        tokenStore.clearEmailUserFlag()
        isAuthenticated = false
        currentUser = nil
        print("[Auth] ✅ 已退出登录")
    }

    // MARK: - Passwordless Login (code)

    func sendLoginCode(email: String) async throws {
        try await APIService.shared.sendLoginCode(email: email)
        print("[Auth] 📧 登录验证码已发送到 \(email)")
    }

    func verifyLoginCode(email: String, code: String) async throws {
        let response = try await APIService.shared.verifyLoginCode(email: email, code: code)
        tokenStore.saveTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
        currentUser = response.user
        isAuthenticated = true
        tokenStore.wasEmailUser = true
        print("[Auth] ✅ 邮箱验证码登录成功 userId=\(response.user.id)")
    }

    // MARK: - Bind Email (for existing anonymous users)

    func bindEmail(email: String) async throws {
        try await APIService.shared.bindEmail(email: email)
        print("[Auth] 📧 绑定验证码已发送到 \(email)")
    }

    func verifyEmailBinding(code: String) async throws {
        let response = try await APIService.shared.verifyEmail(code: code)
        tokenStore.saveTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
        currentUser = response.user
        isAuthenticated = true
        tokenStore.wasEmailUser = true
        print("[Auth] ✅ 邮箱绑定成功 userId=\(response.user.id)")
    }

    // MARK: - Email Logout (revert to anonymous)

    func emailLogout() async throws {
        try await APIService.shared.emailLogout()
        // Clear tokens + email flag → re-login as anonymous device user
        tokenStore.clearAll()
        tokenStore.clearEmailUserFlag()
        try await createDeviceUser()
        print("[Auth] ✅ 已退出邮箱登录，恢复匿名用户")
    }

    // MARK: - Update Profile

    func updateProfile(grade: String, publisher: String?, semester: String?, currentUnit: Int? = 1, onboardingCompleted: Bool? = nil) async throws {
        try await APIService.shared.updateProfile(grade: grade, publisher: publisher, semester: semester, currentUnit: currentUnit, onboardingCompleted: onboardingCompleted)
        await fetchCurrentUser()
        print("[Auth] ✅ 用户资料已更新")
    }

    // MARK: - Fetch Profile
    
    func fetchCurrentUser() async {
        do {
            let profile = try await APIService.shared.fetchCurrentUser()
            currentUser = profile
            tokenStore.wasEmailUser = profile.hasEmailIdentity
        } catch {
            print("[Auth] ⚠️ 获取用户信息失败: \(error)")
        }
    }
}
