//
//  Models.swift
//  Volingo
//
//  Created by jacob on 2025/8/10.
//

import Foundation
import SwiftUI

// MARK: - 词典相关模型
struct Word: Codable, Identifiable {
    var id: String { word } // 使用单词本身作为ID
    let word: String
    let lemma: String
    let isDerived: Bool
    let phonetic: String?
    let senses: [WordSense]
    let exchange: WordExchange
    let synonyms: [String]
    let antonyms: [String]
    
    // 词汇级别标记 (从数据库单独获取，不在JSON中)
    var levels: WordLevels = WordLevels()
    
    enum CodingKeys: String, CodingKey {
        case word, lemma, phonetic, senses, exchange, synonyms, antonyms
        case isDerived = "is_derived"
        // levels 不包含在JSON编码中
    }
    
    // 自定义初始化器
    init(word: String, lemma: String, isDerived: Bool, phonetic: String?, 
         senses: [WordSense], exchange: WordExchange, synonyms: [String], 
         antonyms: [String], levels: WordLevels = WordLevels()) {
        self.word = word
        self.lemma = lemma
        self.isDerived = isDerived
        self.phonetic = phonetic
        self.senses = senses
        self.exchange = exchange
        self.synonyms = synonyms
        self.antonyms = antonyms
        self.levels = levels
    }
}

struct WordSense: Codable, Identifiable {
    var id = UUID()
    let pos: String // 词性 (part of speech)
    let definitions: [String]
    let translations: [String]
    let examples: [WordExample]
    
    private enum CodingKeys: String, CodingKey {
        case pos, definitions, translations, examples
    }
}

struct WordExample: Codable, Identifiable {
    var id = UUID()
    let en: String
    let zh: String
    
    private enum CodingKeys: String, CodingKey {
        case en, zh
    }
}

struct WordExchange: Codable {
    let plural: String?
    let thirdPersonSingular: String?
    let pastTense: String?
    let pastParticiple: String?
    let presentParticiple: String?
    let comparative: String?
    let superlative: String?
    
    enum CodingKeys: String, CodingKey {
        case plural
        case thirdPersonSingular = "third_person_singular"
        case pastTense = "past_tense"
        case pastParticiple = "past_participle"
        case presentParticiple = "present_participle"
        case comparative, superlative
    }
}

struct WordLevels: Codable {
    let a1: Bool
    let a2: Bool
    let b1: Bool
    let b2: Bool
    let c1: Bool
    let middleSchool: Bool
    let highSchool: Bool
    let cet4: Bool
    let cet6: Bool
    let graduateExam: Bool
    let toefl: Bool
    let sat: Bool
    
    // 默认初始化器
    init(a1: Bool = false, a2: Bool = false, b1: Bool = false, b2: Bool = false,
         c1: Bool = false, middleSchool: Bool = false, highSchool: Bool = false,
         cet4: Bool = false, cet6: Bool = false, graduateExam: Bool = false,
         toefl: Bool = false, sat: Bool = false) {
        self.a1 = a1
        self.a2 = a2
        self.b1 = b1
        self.b2 = b2
        self.c1 = c1
        self.middleSchool = middleSchool
        self.highSchool = highSchool
        self.cet4 = cet4
        self.cet6 = cet6
        self.graduateExam = graduateExam
        self.toefl = toefl
        self.sat = sat
    }
    
    enum CodingKeys: String, CodingKey {
        case a1 = "A1"
        case a2 = "A2"
        case b1 = "B1"
        case b2 = "B2"
        case c1 = "C1"
        case middleSchool = "Middle_School"
        case highSchool = "High_School"
        case cet4 = "CET4"
        case cet6 = "CET6"
        case graduateExam = "Graduate_Exam"
        case toefl = "TOEFL"
        case sat = "SAT"
    }
    
    // 获取所有激活的级别
    var activeLevels: [String] {
        var levels: [String] = []
        if a1 { levels.append("A1") }
        if a2 { levels.append("A2") }
        if b1 { levels.append("B1") }
        if b2 { levels.append("B2") }
        if c1 { levels.append("C1") }
        if middleSchool { levels.append("中学") }
        if highSchool { levels.append("高中") }
        if cet4 { levels.append("CET4") }
        if cet6 { levels.append("CET6") }
        if graduateExam { levels.append("考研") }
        if toefl { levels.append("TOEFL") }
        if sat { levels.append("SAT") }
        return levels
    }
}

// 用于数据库查询的原始结构
struct WordDatabaseRecord {
    let word: String
    let jsonData: String
    let levels: WordLevels
}

// MARK: - 查询相关模型
struct WordSearchResult {
    let words: [Word]
    let totalCount: Int
    let searchTerm: String
}

enum WordSearchError: Error, LocalizedError {
    case databaseNotFound
    case invalidQuery
    case decodingError(String)
    case databaseError(String)
    
    var errorDescription: String? {
        switch self {
        case .databaseNotFound:
            return "词典数据库文件未找到"
        case .invalidQuery:
            return "无效的查询条件"
        case .decodingError(let message):
            return "数据解析错误: \(message)"
        case .databaseError(let message):
            return "数据库查询错误: \(message)"
        }
    }
}

// 保留原来的 Definition 结构用于向后兼容
struct Definition {
    let partOfSpeech: String  // 词性
    let meaning: String       // 释义
}

// MARK: - 艾宾浩斯遗忘曲线复习间隔
/// 基于艾宾浩斯遗忘曲线的复习间隔序列
struct ReviewIntervals {
    static let intervals: [TimeInterval] = [
        0,              // Level 0: 立即复习 (新增加的词)
        10 * 60,        // Level 1: 10分钟
        1 * 3600,       // Level 2: 1小时
        8 * 3600,       // Level 3: 8小时
        1 * 86400,      // Level 4: 1天
        3 * 86400,      // Level 5: 3天
        7 * 86400,      // Level 6: 1周
        14 * 86400,     // Level 7: 2周
        30 * 86400,     // Level 8: 1个月
        90 * 86400,     // Level 9: 3个月
        180 * 86400     // Level 10: 6个月
    ]
    
    /// 获取人类可读的间隔描述
    static func description(for level: Int) -> String {
        let descriptions = [
            "立即复习", "10分钟后", "1小时后", "8小时后", "1天后", "3天后",
            "1周后", "2周后", "1个月后", "3个月后", "6个月后"
        ]
        return descriptions[safe: level] ?? "未知"
    }
    
    /// 获取间隔的紧急程度（用于排序，数值越大越紧急）
    static func urgency(for level: Int) -> Int {
        return max(0, intervals.count - level)
    }
    
    /// 获取指定level的时间间隔
    static func timeInterval(for level: Int) -> TimeInterval {
        return intervals[safe: level] ?? 0
    }
}

// MARK: - 简化的生词本模型
struct SavedWord: Codable, Identifiable {
    let id: String
    let word: Word                      // 使用原有的Word结构
    
    // 核心数据 - 只存储基础统计
    let addedDate: Date                 // 添加时间 (固定不变)
    var correctCount: Int = 0           // 答对次数
    var wrongCount: Int = 0             // 答错次数
    
    /// 熟悉程度等级 (0-10) - 基于答对答错次数差值的只读属性
    var level: Int {
        let diff = correctCount - wrongCount
        return max(0, min(diff, ReviewIntervals.intervals.count - 1))
    }
    
    /// 计算下次复习时间 = 添加时间 + 当前level对应的时间间隔
    var nextReviewDate: Date {
        let interval = ReviewIntervals.timeInterval(for: level)
        return addedDate.addingTimeInterval(interval)
    }
    
    /// 是否需要复习 = 当前时间 >= 下次复习时间
    var needsReview: Bool {
        return Date() >= nextReviewDate
    }
    
    /// 当前复习间隔的描述
    var currentIntervalDescription: String {
        return ReviewIntervals.description(for: level)
    }
    
    /// 距离下次复习的时间描述
    var timeUntilNextReview: String {
        let reviewTime = nextReviewDate
        let timeInterval = reviewTime.timeIntervalSinceNow
        
        if timeInterval <= 0 {
            return "需要复习"
        }
        
        let hours = Int(timeInterval / 3600)
        let days = hours / 24
        
        if days > 0 {
            return "\(days)天后"
        } else if hours > 0 {
            return "\(hours)小时后"
        } else {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)分钟后"
        }
    }
    
    /// 复习紧急程度（用于排序，逾期时间越长越紧急）
    var reviewUrgency: Int {
        let overdue = Date().timeIntervalSince(nextReviewDate)
        if overdue <= 0 {
            return 0 // 未到复习时间
        }
        
        // 基础紧急程度 + 逾期小时数
        let baseUrgency = ReviewIntervals.urgency(for: level)
        let overdueHours = min(Int(overdue / 3600), 100) // 最多加100分
        return baseUrgency * 10 + overdueHours
    }
    
    /// 掌握程度描述（基于当前level）
    var masteryDescription: String {
        switch level {
        case 0: return "新词"           // Level 0: 立即复习
        case 1...2: return "初学"       // Level 1-2: 10分钟-1小时
        case 3...4: return "学习中"     // Level 3-4: 8小时-1天
        case 5...6: return "熟悉"       // Level 5-6: 3天-1周
        case 7...8: return "掌握"       // Level 7-8: 2周-1月
        case 9...10: return "精通"      // Level 9-10: 3月-6月
        default: return "未知"
        }
    }
    
    /// 掌握程度对应的颜色
    var masteryColor: Color {
        switch level {
        case 0: return .gray            // 新词
        case 1...2: return .red         // 初学
        case 3...4: return .orange      // 学习中
        case 5...6: return .blue        // 熟悉
        case 7...8: return .green       // 掌握
        case 9...10: return .purple     // 精通
        default: return .gray
        }
    }
    
    /// 总复习次数
    var totalReviews: Int {
        return correctCount + wrongCount
    }
    
    // 从Word创建SavedWord的便利初始化器
    init(from word: Word) {
        self.id = UUID().uuidString
        self.word = word
        self.addedDate = Date()         // 记录添加时间
        self.correctCount = 0           // 新词从0开始
        self.wrongCount = 0             // 新词从0开始
    }
    
    // 完整初始化器（用于从存储恢复）
    init(id: String, word: Word, correctCount: Int = 0, wrongCount: Int = 0, addedDate: Date = Date()) {
        self.id = id
        self.word = word
        self.correctCount = correctCount
        self.wrongCount = wrongCount
        self.addedDate = addedDate
    }
    
    /// 记录答对 - 核心函数
    mutating func recordCorrect() {
        correctCount += 1
        // level 会自动重新计算
    }
    
    /// 记录答错 - 核心函数
    mutating func recordWrong() {
        wrongCount += 1
        // level 会自动重新计算
    }
    
    /// 更新复习结果 - 便利函数
    mutating func updateReviewResult(isCorrect: Bool) {
        if isCorrect {
            recordCorrect()
        } else {
            recordWrong()
        }
    }
    
    /// 手动重置复习进度
    mutating func resetProgress() {
        correctCount = 0
        wrongCount = 0
        // level 自动重置为0
    }
    
    // 自定义编码 - 只需要存储基础数据，level会自动计算
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(addedDate, forKey: .addedDate)
        try container.encode(correctCount, forKey: .correctCount)
        try container.encode(wrongCount, forKey: .wrongCount)
        
        // 手动编码 word 和 levels
        try container.encode(word, forKey: .word)
        try container.encode(word.levels, forKey: .wordLevels)
    }
    
    // 自定义解码
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        addedDate = try container.decode(Date.self, forKey: .addedDate)
        correctCount = try container.decode(Int.self, forKey: .correctCount)
        wrongCount = try container.decode(Int.self, forKey: .wrongCount)
        
        // 手动解码 word 和 levels
        var decodedWord = try container.decode(Word.self, forKey: .word)
        let levels = try container.decode(WordLevels.self, forKey: .wordLevels)
        decodedWord.levels = levels
        word = decodedWord
    }
    
    enum CodingKeys: String, CodingKey {
        case id, addedDate, correctCount, wrongCount
        case word, wordLevels
    }
    
    // 便利访问器
    var wordText: String { word.word }
    var definition: String { word.senses.first?.definitions.first ?? "" }
    var pronunciation: String? { word.phonetic }
    var exampleSentence: String? { word.senses.first?.examples.first?.en }
}

// 扩展：为Array添加安全索引访问
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// 学习会话
struct LearningSession {
    let id: String
    let words: [SavedWord]
    let startTime: Date
    var currentIndex: Int
    var results: [String: LearningResult] = [:]
    
    var isCompleted: Bool {
        return currentIndex >= words.count
    }
    
    var currentWord: SavedWord? {
        guard currentIndex < words.count else { return nil }
        return words[currentIndex]
    }
}

// 学习结果
struct LearningResult {
    let type: LearningResultType
    let responseTime: TimeInterval
    let timestamp: Date
}

enum LearningResultType {
    case correct    // 答对
    case incorrect  // 答错
    case skipped    // 跳过
}

// 用户学习模式分析
struct LearningPattern {
    let averageDelay: TimeInterval      // 平均延迟时间
    let onTimeReviewRate: Double        // 按时复习率
    let totalWords: Int                 // 总词数
    let activeWords: Int                // 活跃学习词数
}

// 学习会话推荐
struct StudySessionRecommendation {
    let recommendedWords: [SavedWord]   // 推荐学习的词
    let estimatedMinutes: Int           // 预估学习时间
    let urgentWords: Int                // 紧急需要复习的词数
}

// 生词本统计
struct WordbookStats {
    let totalWords: Int
    let needReviewCount: Int
    let newWords: Int
    let learningWords: Int
    let reviewingWords: Int
    let masteredWords: Int
}

// 单词分类辅助结构
struct WordCategories {
    let newWords: [SavedWord]
    let overdueWords: [SavedWord]
    let todayWords: [SavedWord]
    let learningWords: [SavedWord]
}

// MARK: - 情景对话相关模型
struct Scenario {
    let id: String
    let title: String
    let category: ScenarioCategory
    let dialogues: [Dialogue]
}

enum ScenarioCategory: String, CaseIterable {
    case airport = "机场"
    case restaurant = "餐厅"
    case business = "商务"
    case daily = "日常"
}

struct Dialogue {
    let id: String
    let speaker: String
    let text: String
    let audioURL: String?
}

// MARK: - 写作相关模型
struct WritingExercise {
    let id: String
    let prompt: String
    let userText: String
    let feedback: [WritingFeedback]
}

struct WritingFeedback {
    let type: FeedbackType
    let position: Range<String.Index>
    let suggestion: String
}

enum FeedbackType {
    case grammar
    case vocabulary
    case style
}

// MARK: - 用户相关模型
struct UserProfile {
    let id: String
    let name: String
    let email: String?
    let learningGoal: LearningGoal
    let studyStreak: Int
}

enum LearningGoal: String, CaseIterable {
    case ket = "KET"
    case pet = "PET"
    case ielts = "雅思"
    case toefl = "托福"
    case cet4 = "四级"
    case cet6 = "六级"
    case daily = "日常交流"
    case business = "商务英语"
}
