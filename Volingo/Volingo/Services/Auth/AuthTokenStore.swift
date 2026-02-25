//
//  AuthTokenStore.swift
//  海豹英语
//
//  Keychain-backed storage for access token and refresh token.
//  Survives app reinstall. Uses kSecAttrAccessibleAfterFirstUnlock
//  so tokens are available in background refresh scenarios.
//

import Foundation
import Security

final class AuthTokenStore {
    static let shared = AuthTokenStore()
    
    private let service = "com.haibao-english.auth"
    private let accessTokenAccount = "access-token"
    private let refreshTokenAccount = "refresh-token"
    
    private init() {}
    
    // MARK: - Access Token
    
    var accessToken: String? {
        get { read(account: accessTokenAccount) }
        set {
            if let value = newValue {
                save(value, account: accessTokenAccount)
            } else {
                delete(account: accessTokenAccount)
            }
        }
    }
    
    // MARK: - Refresh Token
    
    var refreshToken: String? {
        get { read(account: refreshTokenAccount) }
        set {
            if let value = newValue {
                save(value, account: refreshTokenAccount)
            } else {
                delete(account: refreshTokenAccount)
            }
        }
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
    
    // MARK: - JWT exp extraction
    
    /// Decode the JWT payload and extract the `exp` claim.
    private func extractExp(from jwt: String) -> Date? {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else { return nil }
        
        var base64 = String(parts[1])
        // Pad to multiple of 4
        while base64.count % 4 != 0 { base64.append("=") }
        // URL-safe base64 → standard base64
        base64 = base64.replacingOccurrences(of: "-", with: "+")
                       .replacingOccurrences(of: "_", with: "/")
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return nil
        }
        
        return Date(timeIntervalSince1970: exp)
    }
    
    // MARK: - Keychain operations
    
    private func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }
    
    private func save(_ value: String, account: String) {
        delete(account: account)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: value.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
