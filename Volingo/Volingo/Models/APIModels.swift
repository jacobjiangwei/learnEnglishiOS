//
//  APIModels.swift
//  Volingo
//
//  API 响应 / 请求的 Codable 模型，严格对齐 API_PROTOCOL.md
//

import Foundation

// MARK: - 通用错误

struct APIError: Codable {
    let error: String
}

// MARK: - 选择题 (multipleChoice)

struct APIMCQQuestion: Codable, Identifiable {
    let id: String
    let questionType: String
    let textbookCode: String
    let stem: String
    let translation: String
    let options: [String]
    let correctIndex: Int
    let explanation: String
    let explanationTranslation: String?
}

// MARK: - 填空题 (cloze)

struct APIClozeQuestion: Codable, Identifiable {
    let id: String
    let questionType: String
    let textbookCode: String
    let sentence: String
    let translation: String
    let correctAnswer: String
    let hints: [String]?
    let explanation: String
    let explanationTranslation: String?
}

// MARK: - 阅读理解 (reading)

struct APIReadingPassage: Codable, Identifiable {
    let id: String
    let questionType: String
    let textbookCode: String
    let title: String
    let content: String
    let translation: String
    let questions: [APIReadingSubQuestion]
}

struct APIReadingSubQuestion: Codable, Identifiable {
    let id: String
    let stem: String
    let translation: String
    let options: [String]
    let correctIndex: Int
    let explanation: String
}

// MARK: - 翻译题 (translation)

struct APITranslationQuestion: Codable, Identifiable {
    let id: String
    let questionType: String
    let textbookCode: String
    let sourceText: String
    let direction: String          // "enToZh" or "zhToEn"
    let referenceAnswer: String
    let keywords: [String]
    let explanation: String?
    let explanationTranslation: String?
}

// MARK: - 句型改写 (rewriting)

struct APIRewritingQuestion: Codable, Identifiable {
    let id: String
    let questionType: String
    let textbookCode: String
    let originalSentence: String
    let originalTranslation: String?
    let instruction: String
    let instructionTranslation: String?
    let referenceAnswer: String
    let referenceTranslation: String?
    let explanation: String?
    let explanationTranslation: String?
}

// MARK: - 纠错题 (errorCorrection)

struct APIErrorCorrectionQuestion: Codable, Identifiable {
    let id: String
    let questionType: String
    let textbookCode: String
    let sentence: String
    let translation: String
    let errorRange: String
    let correction: String
    let explanation: String?
    let explanationTranslation: String?
}

// MARK: - 排序题 (sentenceOrdering)

struct APIOrderingQuestion: Codable, Identifiable {
    let id: String
    let questionType: String
    let textbookCode: String
    let shuffledParts: [String]
    let correctOrder: [Int]
    let correctSentence: String?
    let translation: String
    let explanation: String?
    let explanationTranslation: String?
}

// MARK: - 听力题 (listening)

struct APIListeningQuestion: Codable, Identifiable {
    let id: String
    let questionType: String
    let textbookCode: String
    let audioURL: String?
    let transcript: String
    let transcriptTranslation: String?
    let stem: String
    let stemTranslation: String?
    let options: [String]
    let correctIndex: Int
    let explanation: String?
    let explanationTranslation: String?
}

// MARK: - 口语题 (speaking)

struct APISpeakingQuestion: Codable, Identifiable {
    let id: String
    let questionType: String
    let textbookCode: String
    let prompt: String
    let referenceText: String
    let translation: String
    let category: String
}

// MARK: - 写作题 (writing)

struct APIWritingQuestion: Codable, Identifiable {
    let id: String
    let questionType: String
    let textbookCode: String
    let prompt: String
    let promptTranslation: String
    let category: String
    let wordLimit: APIWordLimit
    let referenceAnswer: String
    let referenceTranslation: String
}

struct APIWordLimit: Codable {
    let min: Int
    let max: Int
}

// MARK: - 词汇题 (vocabulary)

struct APIVocabularyQuestion: Codable, Identifiable {
    let id: String
    let questionType: String
    let textbookCode: String
    let word: String
    let phonetic: String?
    let meaning: String?
    let stem: String
    let translation: String
    let options: [String]
    let correctIndex: Int
    let exampleSentence: String?
    let exampleTranslation: String?
    let explanation: String?
    let explanationTranslation: String?
    let category: String?
}

// MARK: - 语法题 (grammar)

struct APIGrammarQuestion: Codable, Identifiable {
    let id: String
    let questionType: String
    let textbookCode: String
    let stem: String
    let translation: String
    let options: [String]
    let correctIndex: Int
    let grammarPoint: String?
    let grammarPointTranslation: String?
    let explanation: String?
    let explanationTranslation: String?
}

// MARK: - 场景对话题 (scenario*)

struct APIScenarioQuestion: Codable, Identifiable {
    let id: String
    let questionType: String
    let textbookCode: String
    let scenarioTitle: String
    let context: String
    let dialogueLines: [APIDialogueLine]
    let userPrompt: String
    let options: [String]?
    let correctIndex: Int?
    let referenceResponse: String
    let referenceTranslation: String
}

struct APIDialogueLine: Codable {
    let speaker: String
    let text: String
    let translation: String?
}

// MARK: - 获取练习题组响应

struct QuestionsResponse<T: Codable>: Codable {
    let questionType: String
    let textbookCode: String
    let remaining: Int
    let questions: T
}

/// 阅读理解专用响应（passages 而非 questions）
struct ReadingQuestionsResponse: Codable {
    let questionType: String
    let textbookCode: String
    let remaining: Int?
    let passages: [APIReadingPassage]
}

// MARK: - 今日推荐套餐响应

struct TodayPackageResponse: Codable {
    let date: String
    let textbookCode: String
    let estimatedMinutes: Int
    let items: [TodayPackageItemResponse]
}

struct TodayPackageItemResponse: Codable {
    let type: String
    let count: Int
    let weight: Double
    // questions 和 passages 用 AnyCodable 或手动解码
}

// MARK: - 学习统计响应

struct StatsResponse: Codable {
    let totalCompleted: Int
    let totalCorrect: Int
    let currentStreak: Int
    let longestStreak: Int
    let dailyActivity: [DailyActivity]
}

struct DailyActivity: Codable {
    let date: String
    let count: Int
    let correctCount: Int
}

// MARK: - 提交答案请求

struct SubmitRequest: Codable {
    let results: [SubmitResultItem]
}

struct SubmitResultItem: Codable {
    let questionId: String
    let isCorrect: Bool
}

// MARK: - 题目投诉

struct ReportRequest: Codable {
    let questionId: String
    let reason: String
    let description: String?
}

struct ReportResponse: Codable {
    let reportId: String
}

// MARK: - 生词本

struct WordbookAddRequest: Codable {
    let word: String
    let phonetic: String?
    let definitions: [APIDefinition]
}

struct APIDefinition: Codable {
    let partOfSpeech: String
    let meaning: String
    let example: String?
    let exampleTranslation: String?
}

struct WordbookAddResponse: Codable, Identifiable {
    let id: String
    let word: String
    let addedAt: String
}

struct WordbookListResponse: Codable {
    let total: Int
    let words: [WordbookEntry]
}

struct WordbookEntry: Codable, Identifiable {
    let id: String
    let word: String
    let phonetic: String?
    let definitions: [APIDefinition]
    let addedAt: String
}
