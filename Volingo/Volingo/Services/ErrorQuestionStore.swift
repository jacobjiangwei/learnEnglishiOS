//
//  ErrorQuestionStore.swift
//  Volingo
//
//  错题本：使用 FSRS 间隔重复算法管理做错的题目
//  做错 → 加入错题本（FSRS .again）
//  错题复练中做对 → FSRS .good（推迟下次复习）
//  多次做对后间隔越来越长，最终"毕业"不再出现
//

import Foundation

// MARK: - 错题记录

struct ErrorQuestion: Codable, Identifiable, FSRSReviewable {
    let id: String              // 原始题目 ID
    let questionType: String    // apiKey，如 "multipleChoice"
    let rawQuestionJSON: Data   // 单道题的完整 JSON（题干、选项、答案等）
    let firstWrongDate: Date    // 首次答错时间

    // FSRS 记忆参数
    var memory: FSRSMemory

    // 统计
    var totalAttempts: Int      // 总作答次数
    var correctStreak: Int      // 连续做对次数

    // MARK: - FSRSReviewable
    var fsrsMemory: FSRSMemory { memory }

    /// 是否需要复习（到期或新错题）
    var needsReview: Bool {
        // 学习中 / 重新学习中的错题应立即可用，不受 FSRS 短间隔约束
        if memory.state == .new || memory.state == .learning || memory.state == .relearning {
            return true
        }
        guard let nextReview = memory.nextReviewDate else { return true }
        return nextReview <= Date()
    }

    /// 距离下次复习的时间描述
    var timeUntilNextReview: String {
        guard let nextReview = memory.nextReviewDate else { return "待复习" }
        let interval = nextReview.timeIntervalSinceNow
        if interval <= 0 { return "待复习" }
        let hours = Int(interval / 3600)
        let days = hours / 24
        if days > 0 { return "\(days)天后" }
        if hours > 0 { return "\(hours)小时后" }
        return "\(max(1, Int(interval / 60)))分钟后"
    }

    /// 是否已"毕业"（stability 足够高且连续做对多次）
    var isGraduated: Bool {
        memory.state == .review && memory.stability >= 30 && correctStreak >= 3
    }

    // MARK: - 初始化（首次答错）

    init(id: String, questionType: String, rawQuestionJSON: Data) {
        self.id = id
        self.questionType = questionType
        self.rawQuestionJSON = rawQuestionJSON
        self.firstWrongDate = Date()
        self.memory = FSRSEngine.schedule(memory: FSRSMemory(), rating: .again)
        self.totalAttempts = 1
        self.correctStreak = 0
    }

    // MARK: - 复习结果记录

    /// 在错题复练中做对 → FSRS good
    mutating func recordCorrect() {
        memory = FSRSEngine.schedule(memory: memory, rating: .good)
        totalAttempts += 1
        correctStreak += 1
    }

    /// 在错题复练中又做错 → FSRS again
    mutating func recordWrong() {
        memory = FSRSEngine.schedule(memory: memory, rating: .again)
        totalAttempts += 1
        correctStreak = 0
    }
}

// MARK: - 错题本管理器

@MainActor
class ErrorQuestionStore: ObservableObject {
    static let shared = ErrorQuestionStore()

    @Published private(set) var questions: [ErrorQuestion] = []

    private let fileURL: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = docs.appendingPathComponent("error_questions.json")
        load()
    }

    // MARK: - 待复习

    /// 当前待复习的错题数量（首页徽标用）
    var pendingReviewCount: Int {
        questions.filter { $0.needsReview && !$0.isGraduated }.count
    }

    /// 获取待复习的错题（按超期时间排序，最急迫的在前）
    func getQuestionsForReview(limit: Int = 10) -> [ErrorQuestion] {
        let now = Date()
        return questions
            .filter { $0.needsReview && !$0.isGraduated }
            .sorted { a, b in
                let aOverdue = overdueWeight(for: a, now: now)
                let bOverdue = overdueWeight(for: b, now: now)
                return aOverdue > bOverdue
            }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - 写入

    /// 答错一道题 → 加入或更新错题本
    /// - Parameters:
    ///   - questionId: 原始题目 ID
    ///   - questionType: 题型 apiKey
    ///   - rawQuestionJSON: 该题的完整 JSON 数据
    func addOrUpdateWrong(questionId: String, questionType: String, rawQuestionJSON: Data) {
        if let idx = questions.firstIndex(where: { $0.id == questionId }) {
            // 已在错题本中 → 重新标记为 again
            questions[idx].recordWrong()
            print("[ErrorQuestionStore] 更新错题: \(questionId), state=\(questions[idx].memory.state)")
        } else {
            // 新错题
            let eq = ErrorQuestion(id: questionId, questionType: questionType, rawQuestionJSON: rawQuestionJSON)
            questions.append(eq)
            print("[ErrorQuestionStore] 新增错题: \(questionId), rawJSON=\(rawQuestionJSON.count) bytes")
        }
        print("[ErrorQuestionStore] 当前错题数: \(questions.count), 待复习: \(pendingReviewCount)")
        save()
    }

    /// 错题复练中做对 → 更新 FSRS
    func recordCorrect(questionId: String) {
        guard let idx = questions.firstIndex(where: { $0.id == questionId }) else { return }
        questions[idx].recordCorrect()
        save()
    }

    /// 错题复练中又做错 → 更新 FSRS
    func recordWrong(questionId: String) {
        guard let idx = questions.firstIndex(where: { $0.id == questionId }) else { return }
        questions[idx].recordWrong()
        save()
    }

    /// 手动移除已毕业的错题（释放空间）
    func removeGraduated() {
        questions.removeAll { $0.isGraduated }
        save()
    }

    /// 清空全部错题
    func clearAll() {
        questions.removeAll()
        save()
    }

    // MARK: - 统计

    /// 各状态统计
    var stats: (pending: Int, learning: Int, graduated: Int) {
        let pending = questions.filter { $0.needsReview && !$0.isGraduated }.count
        let graduated = questions.filter { $0.isGraduated }.count
        let learning = questions.count - pending - graduated
        return (pending, learning, graduated)
    }

    // MARK: - 持久化

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            questions = try decoder.decode([ErrorQuestion].self, from: data)
        } catch {
            print("[ErrorQuestionStore] 加载失败: \(error)")
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(questions)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[ErrorQuestionStore] 保存失败: \(error)")
        }
    }

    // MARK: - 辅助

    private func overdueWeight(for q: ErrorQuestion, now: Date) -> Double {
        guard let nextReview = q.memory.nextReviewDate else { return 1000 }
        return now.timeIntervalSince(nextReview) / 86400.0
    }
}
