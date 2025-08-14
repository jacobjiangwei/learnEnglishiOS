//
//  Models.swift
//  Volingo
//
//  Created by jacob on 2025/8/10.
//

import Foundation

// MARK: - 词典相关模型
struct Word {
    let id: String
    let word: String
    let pronunciation: String
    let definitions: [Definition]
    let examples: [String]
}

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
