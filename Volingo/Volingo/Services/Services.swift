//
//  Services.swift
//  Volingo
//
//  Created by jacob on 2025/8/10.
//

import Foundation

// MARK: - 网络服务
class NetworkService {
    static let shared = NetworkService()
    private init() {}
    
    // TODO: 实现网络请求逻辑
    func analyzeWriting(_ text: String) async throws -> [WritingFeedback] {
        // 发送写作文本到后台分析
        return []
    }
    
    func uploadAudio(_ audioData: Data) async throws -> AudioAnalysisResult {
        // 上传音频进行语音评分
        return AudioAnalysisResult(score: 0, feedback: "")
    }
    
    func syncUserData(_ userProfile: UserProfile) async throws {
        // 同步用户数据到云端
    }
}

struct AudioAnalysisResult {
    let score: Double
    let feedback: String
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
