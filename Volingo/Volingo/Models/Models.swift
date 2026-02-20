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
    let phonetic: String?
    let senses: [WordSense]
    let exchange: WordExchange?
    let synonyms: [String]
    let antonyms: [String]
    let relatedPhrases: [RelatedPhrase]
    let usageNotes: String?
    
    // 词汇级别标记 (不在后端 JSON 中，本地使用)
    var levels: WordLevels = WordLevels()
    
    enum CodingKeys: String, CodingKey {
        case word, phonetic, senses, exchange, synonyms, antonyms
        case relatedPhrases, usageNotes
        // levels 不包含在JSON编码中
    }
    
    // 自定义解码器：兼容旧缓存数据（缺失新字段时用默认值）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        word = try container.decode(String.self, forKey: .word)
        phonetic = try container.decodeIfPresent(String.self, forKey: .phonetic)
        senses = try container.decodeIfPresent([WordSense].self, forKey: .senses) ?? []
        exchange = try container.decodeIfPresent(WordExchange.self, forKey: .exchange)
        synonyms = try container.decodeIfPresent([String].self, forKey: .synonyms) ?? []
        antonyms = try container.decodeIfPresent([String].self, forKey: .antonyms) ?? []
        relatedPhrases = try container.decodeIfPresent([RelatedPhrase].self, forKey: .relatedPhrases) ?? []
        usageNotes = try container.decodeIfPresent(String.self, forKey: .usageNotes)
    }
    
    // 自定义初始化器
    init(word: String, phonetic: String?,
         senses: [WordSense], exchange: WordExchange?,
         synonyms: [String], antonyms: [String],
         relatedPhrases: [RelatedPhrase] = [], usageNotes: String? = nil,
         levels: WordLevels = WordLevels()) {
        self.word = word
        self.phonetic = phonetic
        self.senses = senses
        self.exchange = exchange
        self.synonyms = synonyms
        self.antonyms = antonyms
        self.relatedPhrases = relatedPhrases
        self.usageNotes = usageNotes
        self.levels = levels
    }
}

struct RelatedPhrase: Codable, Identifiable {
    var id = UUID()
    let phrase: String
    let meaning: String
    
    private enum CodingKeys: String, CodingKey {
        case phrase, meaning
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

// MARK: - 生词本模型 (FSRS)
struct SavedWord: Codable, Identifiable, FSRSReviewable {
    let id: String
    let word: Word
    let addedDate: Date
    
    // FSRS 记忆参数
    var memory: FSRSMemory = FSRSMemory()
    
    // 统计（向后兼容）
    var correctCount: Int = 0
    var wrongCount: Int = 0
    
    // MARK: - FSRSReviewable
    var fsrsMemory: FSRSMemory { memory }
    
    // MARK: - 便利属性
    
    var wordText: String { word.word }
    
    var definition: String {
        word.senses.first?.translations.first ?? word.senses.first?.definitions.first ?? ""
    }
    
    var pronunciation: String? { word.phonetic }
    
    var exampleSentence: String? { word.senses.first?.examples.first?.en }
    
    var totalReviews: Int { correctCount + wrongCount }
    
    /// 是否需要复习
    var needsReview: Bool {
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
    
    // MARK: - 初始化
    
    init(from word: Word) {
        self.id = UUID().uuidString
        self.word = word
        self.addedDate = Date()
    }
    
    init(id: String, word: Word, addedDate: Date = Date(), memory: FSRSMemory = FSRSMemory()) {
        self.id = id
        self.word = word
        self.addedDate = addedDate
        self.memory = memory
    }
    
    // MARK: - 复习结果记录
    
    /// 根据 FSRS 评分更新记忆状态
    mutating func recordReview(rating: FSRSRating) {
        memory = FSRSEngine.schedule(memory: memory, rating: rating)
        switch rating {
        case .again:
            wrongCount += 1
        case .hard, .good, .easy:
            correctCount += 1
        }
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, addedDate, correctCount, wrongCount
        case word, wordLevels, memory
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(addedDate, forKey: .addedDate)
        try container.encode(correctCount, forKey: .correctCount)
        try container.encode(wrongCount, forKey: .wrongCount)
        try container.encode(word, forKey: .word)
        try container.encode(word.levels, forKey: .wordLevels)
        try container.encode(memory, forKey: .memory)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        addedDate = try container.decode(Date.self, forKey: .addedDate)
        correctCount = try container.decodeIfPresent(Int.self, forKey: .correctCount) ?? 0
        wrongCount = try container.decodeIfPresent(Int.self, forKey: .wrongCount) ?? 0
        
        var decodedWord = try container.decode(Word.self, forKey: .word)
        if let levels = try container.decodeIfPresent(WordLevels.self, forKey: .wordLevels) {
            decodedWord.levels = levels
        }
        word = decodedWord
        
        // 兼容旧数据：没有 memory 字段时用默认值
        memory = try container.decodeIfPresent(FSRSMemory.self, forKey: .memory) ?? FSRSMemory()
    }
}

// 扩展：为Array添加安全索引访问
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// 生词本统计
struct WordbookStats {
    let totalWords: Int
    let needReviewCount: Int
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
