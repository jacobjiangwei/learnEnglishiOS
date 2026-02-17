//
//  PracticeHistoryStore.swift
//  Volingo
//
//  本地练习历史存储：保存原始 API JSON，支持回放
//

import Foundation

// MARK: - 历史会话模型

struct HistorySession: Codable, Identifiable {
    let id: String                  // UUID
    let questionType: String        // apiKey，如 "multipleChoice"
    let displayName: String         // 中文名，如 "选择题"
    let questionCount: Int          // 题目数量
    let timestamp: Date             // 完成时间
    let rawJSON: Data               // 原始 API 响应 JSON
}

// MARK: - 历史存储管理器

@MainActor
class PracticeHistoryStore: ObservableObject {
    static let shared = PracticeHistoryStore()

    @Published private(set) var sessions: [HistorySession] = []

    private let fileURL: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = docs.appendingPathComponent("practice_history.json")
        load()
    }

    // MARK: - 公开方法

    /// 追加一条历史记录
    func append(questionType: String, displayName: String, questionCount: Int, rawJSON: Data) {
        let session = HistorySession(
            id: UUID().uuidString,
            questionType: questionType,
            displayName: displayName,
            questionCount: questionCount,
            timestamp: Date(),
            rawJSON: rawJSON
        )
        sessions.insert(session, at: 0) // 最新的在前
        save()
    }

    /// 删除单条记录
    func delete(id: String) {
        sessions.removeAll { $0.id == id }
        save()
    }

    /// 清空全部历史
    func clearAll() {
        sessions.removeAll()
        save()
    }

    // MARK: - 持久化

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            sessions = try decoder.decode([HistorySession].self, from: data)
        } catch {
            print("[History] 加载历史失败: \(error)")
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(sessions)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[History] 保存历史失败: \(error)")
        }
    }
}
