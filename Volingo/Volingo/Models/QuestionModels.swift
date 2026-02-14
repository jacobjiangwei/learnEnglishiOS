//
//  QuestionModels.swift
//  Volingo
//
//  Created by jacob on 2026/2/13.
//

import Foundation

// MARK: - 统一题目协议

/// 所有题目的基础协议
protocol PracticeQuestion: Identifiable {
    var id: UUID { get }
    var type: QuestionType { get }
    var difficulty: DifficultyLevel { get }
}

/// 难度等级
enum DifficultyLevel: String, Codable, CaseIterable {
    case easy   = "简单"
    case medium = "中等"
    case hard   = "困难"
}

// MARK: - 选择题模型

struct MCQQuestion: PracticeQuestion {
    let id = UUID()
    let type: QuestionType = .multipleChoice
    let difficulty: DifficultyLevel
    let stem: String            // 题干
    let options: [String]       // 选项
    let correctIndex: Int       // 正确答案索引
    let explanation: String     // 解析
}

// MARK: - 填空题模型

struct ClozeQuestion: PracticeQuestion {
    let id = UUID()
    let type: QuestionType = .cloze
    let difficulty: DifficultyLevel
    let sentence: String        // 含空格的句子，用 ___ 标记空白
    let answer: String          // 正确答案
    let hint: String?           // 提示
    let explanation: String
}

// MARK: - 阅读理解模型

struct ReadingPassage: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let questions: [ReadingQuestion]
}

struct ReadingQuestion: PracticeQuestion {
    let id = UUID()
    let type: QuestionType = .reading
    let difficulty: DifficultyLevel
    let stem: String
    let options: [String]
    let correctIndex: Int
    let explanation: String
}

// MARK: - 翻译题模型

struct TranslationQuestion: PracticeQuestion {
    let id = UUID()
    let type: QuestionType = .translation
    let difficulty: DifficultyLevel
    let sourceText: String          // 原文
    let sourceLanguage: String      // "zh" 或 "en"
    let referenceAnswer: String     // 参考译文
    let keywords: [String]          // 必须包含的关键词
    let explanation: String
}

// MARK: - 句型改写模型

struct RewritingQuestion: PracticeQuestion {
    let id = UUID()
    let type: QuestionType = .rewriting
    let difficulty: DifficultyLevel
    let originalSentence: String    // 原句
    let instruction: String         // 改写要求
    let referenceAnswer: String     // 参考答案
    let explanation: String
}

// MARK: - 纠错题模型

struct ErrorCorrectionQuestion: PracticeQuestion {
    let id = UUID()
    let type: QuestionType = .errorCorrection
    let difficulty: DifficultyLevel
    let sentence: String            // 含错误的句子
    let errorRange: String          // 错误部分
    let correction: String          // 正确写法
    let explanation: String
}

// MARK: - 排序题模型

struct OrderingQuestion: PracticeQuestion {
    let id = UUID()
    let type: QuestionType = .sentenceOrdering
    let difficulty: DifficultyLevel
    let shuffledParts: [String]     // 打乱的片段
    let correctOrder: [Int]         // 正确顺序的索引
    let explanation: String
}

// MARK: - 听力题模型

struct ListeningQuestion: PracticeQuestion {
    let id = UUID()
    let type: QuestionType = .listening
    let difficulty: DifficultyLevel
    let audioURL: String?           // 音频 URL（mock 先留空）
    let transcript: String          // 听力原文（用于 mock 显示）
    let stem: String                // 问题
    let options: [String]
    let correctIndex: Int
    let explanation: String
}

// MARK: - 口语题模型

struct SpeakingQuestion: PracticeQuestion {
    let id = UUID()
    let type: QuestionType = .speaking
    let difficulty: DifficultyLevel
    let prompt: String              // 朗读/回答内容
    let referenceText: String       // 参考文本
    let category: SpeakingCategory
}

enum SpeakingCategory: String {
    case readAloud  = "跟读"
    case respond    = "对话回答"
    case retell     = "复述"
    case describe   = "看图说话"
}

// MARK: - 写作题模型

struct WritingQuestion: PracticeQuestion {
    let id = UUID()
    let type: QuestionType = .writing
    let difficulty: DifficultyLevel
    let prompt: String              // 写作要求
    let category: WritingCategory
    let wordLimit: ClosedRange<Int> // 字数范围
    let referenceAnswer: String     // 参考范文
}

enum WritingCategory: String {
    case sentence    = "写句子"
    case paragraph   = "写段落"
    case essay       = "写短文"
    case application = "应用文"
}

// MARK: - 词汇题模型

struct VocabularyQuestion: PracticeQuestion {
    let id = UUID()
    let type: QuestionType = .vocabulary
    let difficulty: DifficultyLevel
    let word: String
    let phonetic: String?
    let stem: String                // 题目
    let options: [String]
    let correctIndex: Int
    let explanation: String
    let category: VocabularyCategory
}

enum VocabularyCategory: String {
    case meaning    = "词义辨析"
    case spelling   = "拼写"
    case form       = "词形变化"
    case synonym    = "近义词"
}

// MARK: - 语法题模型

struct GrammarQuestion: PracticeQuestion {
    let id = UUID()
    let type: QuestionType = .grammar
    let difficulty: DifficultyLevel
    let stem: String
    let options: [String]
    let correctIndex: Int
    let explanation: String
    let topic: GrammarTopic
}

enum GrammarTopic: String {
    case tense          = "时态"
    case clause         = "从句"
    case nonFinite      = "非谓语"
    case article        = "冠词"
    case preposition    = "介词"
    case passive        = "被动语态"
}

// MARK: - 场景对话题模型

struct ScenarioQuestion: PracticeQuestion {
    let id = UUID()
    let type: QuestionType
    let difficulty: DifficultyLevel
    let scenarioTitle: String       // 场景标题
    let context: String             // 场景描述
    let dialogueLines: [DialogueLine]
    let userPrompt: String          // 用户需要说/选的内容
    let options: [String]?          // 如果是选择形式
    let correctIndex: Int?
    let referenceResponse: String   // 参考回答
}

struct DialogueLine: Identifiable {
    let id = UUID()
    let speaker: String             // "AI" 或 "You"
    let text: String
}

// MARK: - 练习会话（包裹一组题目）

struct PracticeSession: Identifiable {
    let id = UUID()
    let questionType: QuestionType
    let questions: [any PracticeQuestion]
    var currentIndex: Int = 0
    var correctCount: Int = 0
    var wrongCount: Int = 0
    
    var totalCount: Int { questions.count }
    var isCompleted: Bool { currentIndex >= questions.count }
    var progress: Double { Double(currentIndex) / Double(max(questions.count, 1)) }
}

// MARK: - 今日套餐会话（混合题型）

struct TodayPracticeSession: Identifiable {
    let id = UUID()
    let sections: [PracticeSession]  // 按题型分段
    var currentSectionIndex: Int = 0
    
    var totalQuestions: Int { sections.reduce(0) { $0 + $1.totalCount } }
    var completedQuestions: Int { sections.reduce(0) { $0 + $1.currentIndex } }
    var overallProgress: Double { Double(completedQuestions) / Double(max(totalQuestions, 1)) }
}
