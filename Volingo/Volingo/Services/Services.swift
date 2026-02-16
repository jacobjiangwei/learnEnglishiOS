//
//  Services.swift
//  Volingo
//
//  Created by jacob on 2025/8/10.
//

import Foundation

// MARK: - 网络服务（已迁移到 APIService.swift）
// NetworkService 保留为兼容层，新的 API 调用请使用 APIService.shared
class NetworkService {
    static let shared = NetworkService()
    private let session: URLSession

    #if DEBUG
    private let baseURL = "http://localhost:5174"
    #else
    private let baseURL = "https://api.volingo.app"
    #endif

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    /// 构建带 X-Device-Id 公共 Header 的 URLRequest
    func makeRequest(path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = method
        request.setValue(DeviceIdManager.shared.deviceId, forHTTPHeaderField: "X-Device-Id")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body = body {
            request.httpBody = body
        }
        return request
    }
}

// MARK: - 存储服务
class StorageService {
    static let shared = StorageService()
    private init() {}
    
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    func saveToFile<T: Codable>(_ object: T, filename: String) throws {
        let url = documentsDirectory.appendingPathComponent(filename)
        let data = try JSONEncoder().encode(object)
        try data.write(to: url)
    }
    
    func loadFromFile<T: Codable>(_ type: T.Type, filename: String) throws -> T {
        let url = documentsDirectory.appendingPathComponent(filename)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }
    
    func deleteFile(_ filename: String) throws {
        let url = documentsDirectory.appendingPathComponent(filename)
        try FileManager.default.removeItem(at: url)
    }
    
    func fileExists(_ filename: String) -> Bool {
        let url = documentsDirectory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path)
    }
}

enum StorageError: Error, LocalizedError {
    case fileNotFound
    case encodingFailed
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "文件未找到"
        case .encodingFailed:
            return "数据编码失败"
        case .decodingFailed:
            return "数据解码失败"
        }
    }
}

// MARK: - 服务管理器
class ServiceManager {
    static let shared = ServiceManager()
    
    private init() {}
    
    // 快捷访问方法
    var dictionary: DictionaryService { DictionaryService.shared }
    var wordbook: WordbookService { WordbookService.shared }
    var network: NetworkService { NetworkService.shared }
    var storage: StorageService { StorageService.shared }
    var audio: AudioService { AudioService.shared }
}
