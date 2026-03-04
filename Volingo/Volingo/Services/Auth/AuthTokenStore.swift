//
//  AuthTokenStore.swift
//  海豹英语
//
//  UserDefaults-backed storage for access token and refresh token.
//  Cleared when the app is deleted.
//

import Foundation

final class AuthTokenStore {
    static let shared = AuthTokenStore()

    private let defaults = UserDefaults.standard
    private let accessTokenKey = "com.haibao-english.auth.access-token"
    private let refreshTokenKey = "com.haibao-english.auth.refresh-token"
    private let wasEmailUserKey = "com.haibao-english.auth.was-email-user"

    private init() {}

    // MARK: - Access Token

    var accessToken: String? {
        get { defaults.string(forKey: accessTokenKey) }
        set { defaults.set(newValue, forKey: accessTokenKey) }
    }

    // MARK: - Refresh Token

    var refreshToken: String? {
        get { defaults.string(forKey: refreshTokenKey) }
        set { defaults.set(newValue, forKey: refreshTokenKey) }
    }

    // MARK: - Email User Flag (survives token clearing)

    /// Persists whether the last signed-in user was an email user.
    /// Stored separately so clearAll() does NOT erase it — only explicit reset does.
    var wasEmailUser: Bool {
        get { defaults.bool(forKey: wasEmailUserKey) }
        set { defaults.set(newValue, forKey: wasEmailUserKey) }
    }

    /// Clear the email user flag (called on explicit signOut / emailLogout).
    func clearEmailUserFlag() {
        defaults.removeObject(forKey: wasEmailUserKey)
    }

    // MARK: - Convenience

    /// Save both tokens at once (e.g., after login or refresh).
    func saveTokens(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    /// Clear all tokens (logout).
    func clearAll() {
        accessToken = nil
        refreshToken = nil
    }

    /// Check if the access token JWT is expired (with optional buffer).
    /// Returns true if expired or unparseable.
    func isAccessTokenExpired(bufferSeconds: TimeInterval = 60) -> Bool {
        guard let token = accessToken else { return true }
        guard let exp = extractExp(from: token) else { return true }
        return Date().addingTimeInterval(bufferSeconds) >= exp
    }

    /// Returns remaining days until access token expires. nil if no token or unparseable.
    func accessTokenRemainingDays() -> Int? {
        guard let token = accessToken,
              let exp = extractExp(from: token) else { return nil }
        let remaining = exp.timeIntervalSince(Date())
        return max(0, Int(remaining / 86400))
    }

    /// Returns remaining seconds until access token expires. nil if no token or unparseable.
    func accessTokenRemainingSeconds() -> Int? {
        guard let token = accessToken,
              let exp = extractExp(from: token) else { return nil }
        let remaining = exp.timeIntervalSince(Date())
        return max(0, Int(remaining))
    }

    // MARK: - JWT exp extraction

    /// Decode the JWT payload and extract the `exp` claim.
    private func extractExp(from jwt: String) -> Date? {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else { return nil }

        var base64 = String(parts[1])
        while base64.count % 4 != 0 { base64.append("=") }
        base64 = base64.replacingOccurrences(of: "-", with: "+")
                       .replacingOccurrences(of: "_", with: "/")

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return nil
        }

        return Date(timeIntervalSince1970: exp)
    }
}
