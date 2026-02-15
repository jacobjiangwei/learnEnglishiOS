//
//  DeviceIdManager.swift
//  Volingo
//
//  Created by jacob on 2026/2/15.
//

import Foundation
import Security

/// 管理设备唯一标识（X-Device-Id）
///
/// 使用 Keychain 存储，卸载重装 App 后仍然保留。
/// 首次调用 `deviceId` 时自动生成 UUID 并写入 Keychain。
final class DeviceIdManager {
    static let shared = DeviceIdManager()
    
    private let service = "com.volingo.device-id"
    private let account = "device-uuid"
    
    private init() {}
    
    /// 获取设备唯一 ID（懒加载，首次自动生成）
    var deviceId: String {
        if let existing = readFromKeychain() {
            return existing
        }
        let newId = UUID().uuidString.lowercased()
        saveToKeychain(newId)
        return newId
    }
    
    // MARK: - Keychain 操作
    
    private func readFromKeychain() -> String? {
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
    
    private func saveToKeychain(_ value: String) {
        // 先删除旧值（如果存在）
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // 写入新值
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: value.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }
    
    /// 仅用于调试：重置设备 ID（生成新的）
    #if DEBUG
    func resetDeviceId() {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)
    }
    #endif
}
