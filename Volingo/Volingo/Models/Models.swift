//
//  Models.swift
//  Volingo
//
//  Created by jacob on 2025/8/10.
//

import Foundation

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

// MARK: - 生词本相关模型
struct SavedWord {
    let id: String
    let word: Word
    let savedDate: Date
    let reviewCount: Int
    let masteryLevel: MasteryLevel
}

enum MasteryLevel: String, CaseIterable {
    case new = "新词"
    case learning = "学习中"
    case reviewing = "复习中"
    case mastered = "已掌握"
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
