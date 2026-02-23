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
    let correctCount: Int           // 正确数
    let wrongCount: Int             // 错误数
    let wrongQuestionIds: [String]  // 答错的题目 ID 列表
    let timestamp: Date             // 完成时间
    let rawJSON: Data               // 原始 API 响应 JSON

    /// 正确率 (0-100)
    var accuracy: Int {
        questionCount > 0 ? Int(Double(correctCount) / Double(questionCount) * 100) : 0
    }
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
    func append(questionType: String, displayName: String, questionCount: Int,
                correctCount: Int = 0, wrongCount: Int = 0,
                wrongQuestionIds: [String] = [], rawJSON: Data) {
        let session = HistorySession(
            id: UUID().uuidString,
            questionType: questionType,
            displayName: displayName,
            questionCount: questionCount,
            correctCount: correctCount,
            wrongCount: wrongCount,
            wrongQuestionIds: wrongQuestionIds,
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

    // MARK: - 错题查询

    /// 今日错题总数（首页徽标用）
    var todayWrongCount: Int {
        todaySessions.reduce(0) { $0 + $1.wrongQuestionIds.count }
    }

    /// 获取今日所有答错的题目（从本地 rawJSON 中提取），返回 (questionType, rawJSON 只含错题)
    /// 支持多种题型混合
    func getTodayWrongQuestions() -> [(questionType: String, wrongIds: Set<String>, rawJSON: Data)] {
        var result: [(questionType: String, wrongIds: Set<String>, rawJSON: Data)] = []
        // 按题型合并同一天的错题
        var typeMap: [String: (wrongIds: Set<String>, sessions: [HistorySession])] = [:]
        for session in todaySessions where !session.wrongQuestionIds.isEmpty {
            var entry = typeMap[session.questionType] ?? (wrongIds: [], sessions: [])
            entry.wrongIds.formUnion(session.wrongQuestionIds)
            entry.sessions.append(session)
            typeMap[session.questionType] = entry
        }
        for (qType, entry) in typeMap {
            // 用最近一次该题型的 rawJSON（包含题目数据）
            if let latestSession = entry.sessions.first {
                result.append((questionType: qType, wrongIds: entry.wrongIds, rawJSON: latestSession.rawJSON))
            }
        }
        return result
    }

    /// 今日的练习会话
    private var todaySessions: [HistorySession] {
        let calendar = Calendar.current
        return sessions.filter { calendar.isDateInToday($0.timestamp) }
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
