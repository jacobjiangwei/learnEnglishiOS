//
//  DeviceIdManager.swift
//  海豹英语
//
//  Created by jacob on 2026/2/15.
//

import Foundation

/// 管理设备唯一标识（X-Device-Id）
///
/// 使用 UserDefaults 存储，删除 App 后自动清除。
/// 首次调用 `deviceId` 时自动生成 UUID 并写入 UserDefaults。
final class DeviceIdManager {
    static let shared = DeviceIdManager()

    private let key = "com.haibao-english.device-uuid"

    private init() {}

    /// 获取设备唯一 ID（懒加载，首次自动生成）
    var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let newId = UUID().uuidString.lowercased()
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }

    /// 仅用于调试：重置设备 ID（生成新的）
    #if DEBUG
    func resetDeviceId() {
        UserDefaults.standard.removeObject(forKey: key)
    }
    #endif
}
