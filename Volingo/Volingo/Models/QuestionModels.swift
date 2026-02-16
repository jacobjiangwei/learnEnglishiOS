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
    var id: String { get }
    var type: QuestionType { get }
}

// MARK: - 选择题模型

struct MCQQuestion: PracticeQuestion {
    let id: String
    let type: QuestionType = .multipleChoice
    let stem: String            // 题干
    let options: [String]       // 选项
    let correctIndex: Int       // 正确答案索引
    let explanation: String     // 解析
}

// MARK: - 填空题模型

struct ClozeQuestion: PracticeQuestion {
    let id: String
    let type: QuestionType = .cloze
    let sentence: String        // 含空格的句子，用 ___ 标记空白
    let answer: String          // 正确答案
    let hint: String?           // 提示
    let explanation: String
}

// MARK: - 阅读理解模型

struct ReadingPassage: Identifiable {
    let id: String
    let title: String
    let content: String
    let questions: [ReadingQuestion]
}

struct ReadingQuestion: PracticeQuestion {
    let id: String
    let type: QuestionType = .reading
    let stem: String
    let options: [String]
    let correctIndex: Int
    let explanation: String
}

// MARK: - 翻译题模型

struct TranslationQuestion: PracticeQuestion {
    let id: String
    let type: QuestionType = .translation
    let sourceText: String          // 原文
    let sourceLanguage: String      // "zh" 或 "en"
    let referenceAnswer: String     // 参考译文
    let keywords: [String]          // 必须包含的关键词
    let explanation: String
}

// MARK: - 句型改写模型

struct RewritingQuestion: PracticeQuestion {
    let id: String
    let type: QuestionType = .rewriting
    let originalSentence: String    // 原句
    let instruction: String         // 改写要求
    let referenceAnswer: String     // 参考答案
    let explanation: String
}

// MARK: - 纠错题模型

struct ErrorCorrectionQuestion: PracticeQuestion {
    let id: String
    let type: QuestionType = .errorCorrection
    let sentence: String            // 含错误的句子
    let errorRange: String          // 错误部分
    let correction: String          // 正确写法
    let explanation: String
}

// MARK: - 排序题模型

struct OrderingQuestion: PracticeQuestion {
    let id: String
    let type: QuestionType = .sentenceOrdering
    let shuffledParts: [String]     // 打乱的片段
    let correctOrder: [Int]         // 正确顺序的索引
    let explanation: String
}

// MARK: - 听力题模型

struct ListeningQuestion: PracticeQuestion {
    let id: String
    let type: QuestionType = .listening
    let audioURL: String?           // 音频 URL
    let transcript: String          // 听力原文
    let stem: String                // 问题
    let options: [String]
    let correctIndex: Int
    let explanation: String
}

// MARK: - 口语题模型（多邻国风格：所有题型都有明确期望答案）

struct SpeakingQuestion: PracticeQuestion {
    let id: String
    let type: QuestionType = .speaking
    let prompt: String              // 题目提示（中文指令）
    let referenceText: String       // 期望用户说出的英文文本
    let translation: String?        // 中文释义（翻译说时显示为题干）
    let category: SpeakingCategory
}

/// 多邻国风格口语题型
enum SpeakingCategory: String {
    /// 朗读：显示英文句子 → 用户照着读
    case readAloud      = "朗读句子"
    /// 翻译说：显示中文 → 用户说出英文翻译
    case translateSpeak = "翻译并朗读"
    /// 听后说：先播放音频 + 显示文字 → 用户跟读
    case listenRepeat   = "听后跟读"
    /// 补全说：句子缺一部分 → 用户说出完整句子
    case completeSpeak  = "补全句子"

    /// 从 API 返回的英文 key 初始化
    static func from(apiKey: String) -> SpeakingCategory {
        switch apiKey {
        case "readAloud":       return .readAloud
        case "translateSpeak":  return .translateSpeak
        case "listenRepeat":    return .listenRepeat
        case "completeSpeak":   return .completeSpeak
        // 兼容旧数据
        case "respond":         return .translateSpeak
        case "retell":          return .listenRepeat
        case "describe":        return .readAloud
        default:                return .readAloud
        }
    }

    /// 题型图标
    var icon: String {
        switch self {
        case .readAloud:      return "text.bubble"
        case .translateSpeak: return "character.bubble"
        case .listenRepeat:   return "ear"
        case .completeSpeak:  return "text.badge.plus"
        }
    }
}

// MARK: - 写作题模型

struct WritingQuestion: PracticeQuestion {
    let id: String
    let type: QuestionType = .writing
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
    let id: String
    let type: QuestionType = .vocabulary
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
    let id: String
    let type: QuestionType = .grammar
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
    let id: String
    let type: QuestionType
    let scenarioTitle: String       // 场景标题
    let context: String             // 场景描述
    let dialogueLines: [DialogueLine]
    let userPrompt: String          // 用户需要说/选的内容
    let options: [String]?          // 如果是选择形式
    let correctIndex: Int?
    let referenceResponse: String   // 参考回答
}

struct DialogueLine: Identifiable {
    let id: String
    let speaker: String             // "AI" 或 "You"
    let text: String
}
