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
    /// No user interaction needed.
    func autoSignIn() async {
        isLoading = true
        defer { isLoading = false }
        
        // 1. Have a valid access token?
        if tokenStore.accessToken != nil && !tokenStore.isAccessTokenExpired() {
            isAuthenticated = true
            
            // Proactively refresh if access token expires within 7 days
            // (refresh token rotation: old revoked, new issued — effectively never expires)
            if let remaining = tokenStore.accessTokenRemainingDays(), remaining < 7 {
                print("[Auth] Access token expires in \(remaining) days, refreshing proactively")
                try? await refreshToken()
            }
            
            await fetchCurrentUser()
            return
        }
        
        // 2. Access token expired but have a refresh token (valid 1 year)? Refresh it.
        if tokenStore.refreshToken != nil {
            do {
                try await refreshToken()
                return
            } catch {
                print("[Auth] Refresh failed, will re-register device: \(error)")
                tokenStore.clearAll()
            }
        }
        
        // 3. No tokens — register/login with device ID
        do {
            try await deviceSignIn()
        } catch {
            print("[Auth] ❌ Device sign-in failed: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Device Sign-In
    
    private func deviceSignIn() async throws {
        let deviceId = DeviceIdManager.shared.deviceId
        let response = try await APIService.shared.deviceSignIn(deviceId: deviceId)
        
        tokenStore.saveTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
        currentUser = response.user
        isAuthenticated = true
        
        print("[Auth] ✅ Device sign-in successful: \(response.user.id)")
    }
    
    // MARK: - Token Lifecycle
    
    func refreshToken() async throws {
        guard let refreshToken = tokenStore.refreshToken else {
            throw AuthError.noRefreshToken
        }
        let response = try await APIService.shared.refreshAuthToken(refreshToken: refreshToken)
        tokenStore.saveTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
        isAuthenticated = true
        currentUser = response.user
    }
    
    func signOut() async {
        if tokenStore.accessToken != nil {
            try? await APIService.shared.logout()
        }
        tokenStore.clearAll()
        isAuthenticated = false
        currentUser = nil
    }
    
    // MARK: - Private
    
    private func fetchCurrentUser() async {
        do {
            let profile = try await APIService.shared.fetchCurrentUser()
            currentUser = profile
        } catch {
            print("[Auth] ⚠️ Failed to fetch user profile: \(error)")
        }
    }
}
