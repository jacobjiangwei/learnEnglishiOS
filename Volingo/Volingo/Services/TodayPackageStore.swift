//
//  TodayPackageStore.swift
//  Volingo
//
//  今日推荐套餐本地缓存：当日只拉一次，本地追踪完成状态
//

import Foundation

// MARK: - 本地缓存模型

struct CachedTodayPackage: Codable {
    let date: String                        // "yyyy-MM-dd"
    let textbookCode: String
    let estimatedMinutes: Int
    let items: [CachedPackageItem]
}

struct CachedPackageItem: Codable, Identifiable {
    let id: String                          // UUID
    let questionType: String                // apiKey
    let displayName: String                 // 中文名
    let count: Int
    let weight: Double
    var isCompleted: Bool                   // 本地标记
    let rawQuestionsJSON: Data?             // 可选：该题型的原始题目 JSON（今日包 API 返回的）
}

// MARK: - 今日套餐本地管理器

@MainActor
class TodayPackageStore: ObservableObject {
    static let shared = TodayPackageStore()

    @Published private(set) var cached: CachedTodayPackage?

    private let fileURL: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = docs.appendingPathComponent("today_package_cache.json")
        load()
    }

    /// 今天的日期字符串
    private var todayString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    /// 是否有今天的缓存
    var hasTodayCache: Bool {
        cached?.date == todayString
    }

    /// 是否全部完成
    var allCompleted: Bool {
        guard let items = cached?.items, !items.isEmpty else { return false }
        return items.allSatisfy { $0.isCompleted }
    }

    /// 已完成数 / 总数
    var completionProgress: (completed: Int, total: Int) {
        guard let items = cached?.items else { return (0, 0) }
        return (items.filter { $0.isCompleted }.count, items.count)
    }

    /// 检查某题型是否已完成
    func isCompleted(questionType: String) -> Bool {
        cached?.items.first { $0.questionType == questionType }?.isCompleted ?? false
    }

    /// 获取某题型的缓存题目 JSON（QuestionsResponse 格式）
    func cachedQuestionsJSON(for questionType: String) -> Data? {
        cached?.items.first { $0.questionType == questionType }?.rawQuestionsJSON
    }

    // MARK: - 缓存写入

    /// 从 API 原始 JSON 缓存今日套餐（包含每个题型的实际题目）
    func cacheFromAPI(response: TodayPackageResponse, rawData: Data, textbookCode: String) {
        // 解析原始 JSON，提取每个 item 的 questions 数组
        var perItemQuestionsJSON: [String: Data] = [:]
        if let root = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any],
           let rawItems = root["items"] as? [[String: Any]] {
            for rawItem in rawItems {
                guard let type = rawItem["type"] as? String,
                      let questions = rawItem["questions"] else { continue }
                // 构造与单独获取题目接口相同的 JSON 结构：
                // { "questionType": "xxx", "textbookCode": "xxx", "remaining": 0, "questions": [...] }
                // 阅读理解特殊处理：字段名是 passages
                let wrapperKey = (type == "reading") ? "passages" : "questions"
                let wrapper: [String: Any] = [
                    "questionType": type,
                    "textbookCode": textbookCode,
                    "remaining": 0,
                    wrapperKey: questions
                ]
                if let data = try? JSONSerialization.data(withJSONObject: wrapper) {
                    perItemQuestionsJSON[type] = data
                }
            }
        }

        let items = response.items.compactMap { item -> CachedPackageItem? in
            guard QuestionType.from(apiKey: item.type) != nil else { return nil }
            let displayName = QuestionType.from(apiKey: item.type)?.rawValue ?? item.type
            return CachedPackageItem(
                id: UUID().uuidString,
                questionType: item.type,
                displayName: displayName,
                count: item.count,
                weight: item.weight,
                isCompleted: false,
                rawQuestionsJSON: perItemQuestionsJSON[item.type]
            )
        }
        cached = CachedTodayPackage(
            date: todayString,
            textbookCode: textbookCode,
            estimatedMinutes: response.estimatedMinutes,
            items: items
        )
        save()
    }

    /// 标记某题型已完成
    func markCompleted(questionType: String) {
        guard let pkg = cached else { return }
        var items = pkg.items
        if let idx = items.firstIndex(where: { $0.questionType == questionType }) {
            items[idx] = CachedPackageItem(
                id: items[idx].id,
                questionType: items[idx].questionType,
                displayName: items[idx].displayName,
                count: items[idx].count,
                weight: items[idx].weight,
                isCompleted: true,
                rawQuestionsJSON: items[idx].rawQuestionsJSON
            )
            cached = CachedTodayPackage(
                date: pkg.date,
                textbookCode: pkg.textbookCode,
                estimatedMinutes: pkg.estimatedMinutes,
                items: items
            )
            save()
        }
    }

    // MARK: - 持久化

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let pkg = try JSONDecoder().decode(CachedTodayPackage.self, from: data)
            // 只保留今天的缓存，过期的丢弃
            if pkg.date == todayString {
                cached = pkg
            } else {
                cached = nil
                try? FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            print("[TodayPkg] 加载失败: \(error)")
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(cached)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[TodayPkg] 保存失败: \(error)")
        }
    }
}
