//
//  PracticeModels.swift
//  Volingo
//
//  Created by jacob on 2026/2/13.
//

import Foundation
import SwiftUI

// MARK: - 题型定义（注册表模式）

/// 所有支持的题型
enum QuestionType: String, Codable, CaseIterable, Identifiable {
    // 题型类
    case multipleChoice     = "选择题"
    case cloze              = "填空题"
    case reading            = "阅读理解"
    case translation        = "翻译题"
    case rewriting          = "句型改写"
    case errorCorrection    = "纠错题"
    case sentenceOrdering   = "排序题"
    
    // 能力类
    case listening          = "听力专项"
    case speaking           = "口语专项"
    case writing            = "写作专项"
    case vocabulary         = "词汇专项"
    case grammar            = "语法专项"
    
    // 场景类
    case scenarioDaily      = "日常场景"
    case scenarioCampus     = "校园场景"
    case scenarioWorkplace  = "职场场景"
    case scenarioTravel     = "旅行场景"
    
    // 轻量类
    case quickSprint        = "5分钟快练"
    case errorReview        = "错题复练"
    case randomChallenge    = "随机挑战"
    case timedDrill         = "提速训练"
    
    var id: String { rawValue }

    /// API 通信用的英文标识（对齐 API_PROTOCOL.md）
    var apiKey: String {
        switch self {
        case .multipleChoice:    return "multipleChoice"
        case .cloze:             return "cloze"
        case .reading:           return "reading"
        case .translation:       return "translation"
        case .rewriting:         return "rewriting"
        case .errorCorrection:   return "errorCorrection"
        case .sentenceOrdering:  return "sentenceOrdering"
        case .listening:         return "listening"
        case .speaking:          return "speaking"
        case .writing:           return "writing"
        case .vocabulary:        return "vocabulary"
        case .grammar:           return "grammar"
        case .scenarioDaily:     return "scenarioDaily"
        case .scenarioCampus:    return "scenarioCampus"
        case .scenarioWorkplace: return "scenarioWorkplace"
        case .scenarioTravel:    return "scenarioTravel"
        case .quickSprint:       return "quickSprint"
        case .errorReview:       return "errorReview"
        case .randomChallenge:   return "randomChallenge"
        case .timedDrill:        return "timedDrill"
        }
    }

    /// 从 API 英文标识构造
    static func from(apiKey: String) -> QuestionType? {
        allCases.first { $0.apiKey == apiKey }
    }
    
    /// 题型所属分组
    var category: TrainingCategory {
        switch self {
        case .multipleChoice, .cloze, .reading, .translation,
             .rewriting, .errorCorrection, .sentenceOrdering:
            return .questionType
        case .listening, .speaking, .writing, .vocabulary, .grammar:
            return .skill
        case .scenarioDaily, .scenarioCampus, .scenarioWorkplace, .scenarioTravel:
            return .scenario
        case .quickSprint, .errorReview, .randomChallenge, .timedDrill:
            return .lightweight
        }
    }
    
    /// 图标
    var icon: String {
        switch self {
        case .multipleChoice:    return "checkmark.circle"
        case .cloze:             return "text.badge.plus"
        case .reading:           return "doc.text"
        case .translation:       return "arrow.left.arrow.right"
        case .rewriting:         return "arrow.triangle.2.circlepath"
        case .errorCorrection:   return "xmark.circle"
        case .sentenceOrdering:  return "arrow.up.arrow.down"
        case .listening:         return "headphones"
        case .speaking:          return "mic.fill"
        case .writing:           return "pencil.line"
        case .vocabulary:        return "textformat.abc"
        case .grammar:           return "text.book.closed"
        case .scenarioDaily:     return "cup.and.saucer.fill"
        case .scenarioCampus:    return "graduationcap.fill"
        case .scenarioWorkplace: return "briefcase.fill"
        case .scenarioTravel:    return "airplane"
        case .quickSprint:       return "bolt.fill"
        case .errorReview:       return "arrow.counterclockwise"
        case .randomChallenge:   return "shuffle"
        case .timedDrill:        return "timer"
        }
    }
    
    /// 主题色
    var color: Color {
        switch category {
        case .questionType:  return .blue
        case .skill:         return .purple
        case .scenario:      return .orange
        case .lightweight:   return .green
        }
    }
    
    /// 简短描述
    var subtitle: String {
        switch self {
        case .multipleChoice:    return "单选/多选/判断"
        case .cloze:             return "单词/语法/完形"
        case .reading:           return "短文/长文/匹配"
        case .translation:       return "中译英/英译中"
        case .rewriting:         return "同义/主被动转换"
        case .errorCorrection:   return "找错改错"
        case .sentenceOrdering:  return "句子/段落排序"
        case .listening:         return "对话/独白/笔记"
        case .speaking:          return "跟读/对话/复述"
        case .writing:           return "写句/写段/应用文"
        case .vocabulary:        return "背词/辨析/词形"
        case .grammar:           return "时态/从句/非谓语"
        case .scenarioDaily:     return "点餐/问路/购物"
        case .scenarioCampus:    return "课堂/作业/考试"
        case .scenarioWorkplace: return "面试/邮件/会议"
        case .scenarioTravel:    return "机场/酒店/交通"
        case .quickSprint:       return "短时完成，快速提升"
        case .errorReview:       return "回顾今日错题"
        case .randomChallenge:   return "混合题型挑战"
        case .timedDrill:        return "限时作答训练"
        }
    }
}

// MARK: - 专项训练分组

/// 训练分组
enum TrainingCategory: String, CaseIterable, Identifiable {
    case questionType = "题型训练"
    case skill        = "能力训练"
    case scenario     = "场景训练"
    case lightweight  = "轻量训练"
    
    var id: String { rawValue }
    
    /// 分组图标
    var icon: String {
        switch self {
        case .questionType: return "list.bullet.rectangle"
        case .skill:        return "brain.head.profile"
        case .scenario:     return "theatermasks"
        case .lightweight:  return "hare"
        }
    }
    
    /// 分组颜色
    var color: Color {
        switch self {
        case .questionType: return .blue
        case .skill:        return .purple
        case .scenario:     return .orange
        case .lightweight:  return .green
        }
    }
    
    /// 该分组下的所有题型
    var questionTypes: [QuestionType] {
        QuestionType.allCases.filter { $0.category == self }
    }
}

// MARK: - 今日推荐套餐

/// 套餐中的单个题型配置
struct PackageItem: Identifiable {
    let id = UUID()
    let type: QuestionType
    let count: Int          // 该题型题量
    let weight: Double      // 权重（0-1）
}

/// 今日推荐套餐
struct TodayPackage: Identifiable {
    let id = UUID()
    let date: Date
    let level: String                   // 当前年级/等级
    let items: [PackageItem]            // 题型构成
    let estimatedMinutes: Int           // 预计时长
    
    /// 总题量
    var totalQuestions: Int {
        items.reduce(0) { $0 + $1.count }
    }
    
    /// 题型摘要（前3个）
    var typeSummary: String {
        items.prefix(3)
            .map { "\($0.type.rawValue) \($0.count)题" }
            .joined(separator: " · ")
    }
}


