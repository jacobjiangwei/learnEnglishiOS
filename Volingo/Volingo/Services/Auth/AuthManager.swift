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
    let level: String?
    let textbookCode: String?
    let semester: String?
    
    var isEmailUser: Bool { hasEmailIdentity }
}

// MARK: - Auth Manager

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: AuthUserProfile?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    
    private let tokenStore = AuthTokenStore.shared
    
    private init() {}
    
    // MARK: - Auto Sign-In (called on app launch)
    
    /// Checks existing tokens or auto-registers with device ID.
    /// If no tokens exist, does NOT auto-create a user — onboarding will handle that.
    func autoSignIn() async {
        isLoading = true
        defer { isLoading = false }
        
        let hasAccessToken = tokenStore.accessToken != nil
        let hasRefreshToken = tokenStore.refreshToken != nil
        let isExpired = tokenStore.isAccessTokenExpired()
        print("[Auth] 🔍 autoSignIn: hasAccessToken=\(hasAccessToken), hasRefreshToken=\(hasRefreshToken), isExpired=\(isExpired)")
        
        // 1. Have a valid access token?
        if hasAccessToken && !isExpired {
            await fetchCurrentUser()
            if currentUser != nil {
                isAuthenticated = true
                print("[Auth] ✅ 已登录 userId=\(currentUser?.id ?? "unknown")")
                
                // Proactively refresh if access token expires within 7 days
                if let remaining = tokenStore.accessTokenRemainingDays(), remaining < 7 {
                    print("[Auth] ⏳ Access token 剩余 \(remaining) 天，主动刷新")
                    try? await refreshToken()
                }
                return
            } else {
                // Token valid but user not found (DB wiped or server down) → re-login
                print("[Auth] ⚠️ Token 有效但用户不存在，清除旧 token 重新登录")
                tokenStore.clearAll()
            }
        }
        
        // 2. Access token expired but have a refresh token? Refresh it.
        if hasRefreshToken {
            print("[Auth] 🔄 Access token 已过期，尝试用 refresh token 换新…")
            do {
                try await refreshToken()
                print("[Auth] ✅ Token 刷新成功 userId=\(currentUser?.id ?? "unknown")")
                return
            } catch {
                print("[Auth] ❌ Token 刷新失败，清除登录态: \(error)")
                tokenStore.clearAll()
            }
        }
        
        // 3. No tokens — don't auto-create user.
        //    Let onboarding complete first, then call createDeviceUser().
        print("[Auth] 🆕 无 token，等待 onboarding 完成后创建用户")
    }
    
    // MARK: - Device Sign-In (called after onboarding completes)
    
    func createDeviceUser() async throws {
        let deviceId = DeviceIdManager.shared.deviceId
        print("[Auth] 📱 createDeviceUser deviceId=\(deviceId)")
        let response = try await APIService.shared.deviceSignIn(deviceId: deviceId)
        
        tokenStore.saveTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
        currentUser = response.user
        isAuthenticated = true
        
        print("[Auth] ✅ 设备用户创建成功 userId=\(response.user.id)")
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
        print("[Auth] ✅ Token 已更新 userId=\(response.user.id)")
    }
    
    func signOut() async {
        print("[Auth] 🚪 signOut userId=\(currentUser?.id ?? "none")")
        if tokenStore.accessToken != nil {
            try? await APIService.shared.logout()
        }
        tokenStore.clearAll()
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
        print("[Auth] ✅ 邮箱绑定成功 userId=\(response.user.id)")
    }

    // MARK: - Email Logout (revert to anonymous)

    func emailLogout() async throws {
        try await APIService.shared.emailLogout()
        // Clear current tokens & re-login as anonymous device user
        tokenStore.clearAll()
        try await createDeviceUser()
        print("[Auth] ✅ 已退出邮箱登录，恢复匿名用户")
    }

    // MARK: - Update Profile

    func updateProfile(level: String, textbookCode: String, semester: String?) async throws {
        try await APIService.shared.updateProfile(level: level, textbookCode: textbookCode, semester: semester)
        await fetchCurrentUser()
        print("[Auth] ✅ 用户资料已更新")
    }

    // MARK: - Private
    
    private func fetchCurrentUser() async {
        do {
            let profile = try await APIService.shared.fetchCurrentUser()
            currentUser = profile
        } catch {
            print("[Auth] ⚠️ 获取用户信息失败: \(error)")
        }
    }
}
