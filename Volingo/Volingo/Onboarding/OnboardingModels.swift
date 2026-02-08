//
//  OnboardingModels.swift
//  Volingo
//
//  Created by jacob on 2026/2/8.
//

import Foundation
import SwiftUI

// MARK: - User Level

/// Represents the user's English proficiency level.
/// Display order follows the enum declaration.
enum UserLevel: String, Codable, CaseIterable, Identifiable {
    // Domestic system
    case primary     = "小学"
    case junior1     = "初一"
    case junior2     = "初二"
    case junior3     = "初三"
    case senior1     = "高一"
    case senior2     = "高二"
    case senior3     = "高三"
    case cet4        = "四级"
    case cet6        = "六级"
    case graduate    = "考研"
    case daily       = "日常"

    // Overseas system
    case ket         = "KET"
    case pet         = "PET"
    case fce         = "FCE"
    case cae         = "CAE"
    case cpe         = "CPE"
    case cefrA1      = "CEFR A1"
    case cefrA2      = "CEFR A2"
    case cefrB1      = "CEFR B1"
    case cefrB2      = "CEFR B2"
    case cefrC1      = "CEFR C1"
    case cefrC2      = "CEFR C2"
    case ielts       = "IELTS"
    case toefl       = "TOEFL"

    var id: String { rawValue }

    /// Short Chinese subtitle shown below the label.
    var subtitle: String {
        switch self {
        case .primary:   return "小学阶段"
        case .junior1:   return "初中一年级"
        case .junior2:   return "初中二年级"
        case .junior3:   return "初中三年级"
        case .senior1:   return "高中一年级"
        case .senior2:   return "高中二年级"
        case .senior3:   return "高中三年级"
        case .cet4:      return "大学英语四级"
        case .cet6:      return "大学英语六级"
        case .graduate:  return "研究生入学"
        case .daily:     return "日常英语"
        case .ket:       return "剑桥 A2"
        case .pet:       return "剑桥 B1"
        case .fce:       return "剑桥 B2"
        case .cae:       return "剑桥 C1"
        case .cpe:       return "剑桥 C2"
        case .cefrA1:    return "欧标入门"
        case .cefrA2:    return "欧标基础"
        case .cefrB1:    return "欧标中级"
        case .cefrB2:    return "欧标中高"
        case .cefrC1:    return "欧标高级"
        case .cefrC2:    return "欧标精通"
        case .ielts:     return "雅思"
        case .toefl:     return "托福"
        }
    }

    /// Friendly group header used in the picker.
    var group: LevelGroup {
        switch self {
           case .primary:                        return .domesticPrimary
           case .junior1, .junior2, .junior3:    return .domesticMiddle
           case .senior1, .senior2, .senior3:    return .domesticHigh
           case .cet4, .cet6:                    return .domesticCollege
           case .graduate:                       return .domesticExam
           case .daily:                          return .domesticDaily
           case .ket, .pet, .fce, .cae, .cpe:    return .overseasCambridge
           case .cefrA1, .cefrA2, .cefrB1,
               .cefrB2, .cefrC1, .cefrC2:       return .overseasCefr
           case .ielts, .toefl:                  return .overseasExam
        }
    }

    /// SF Symbol icon for the card.
    var icon: String { group.icon }

    /// Card tint color.
    var color: Color { group.color }

    /// Approximate vocabulary size for this level — shown as context to parents.
    var vocabRange: String {
        switch self {
        case .primary:   return "~800 词"
        case .junior1:   return "~1,200 词"
        case .junior2:   return "~1,800 词"
        case .junior3:   return "~2,500 词"
        case .senior1:   return "~3,000 词"
        case .senior2:   return "~3,500 词"
        case .senior3:   return "~4,000 词"
        case .cet4:      return "~4,500 词"
        case .cet6:      return "~6,000 词"
        case .graduate:  return "~7,000 词"
        case .daily:     return "~3,000 词"
        case .ket:       return "~1,500 词"
        case .pet:       return "~2,500 词"
        case .fce:       return "~4,000 词"
        case .cae:       return "~6,000 词"
        case .cpe:       return "~8,000 词"
        case .cefrA1:    return "~800 词"
        case .cefrA2:    return "~1,500 词"
        case .cefrB1:    return "~2,500 词"
        case .cefrB2:    return "~4,000 词"
        case .cefrC1:    return "~6,000 词"
        case .cefrC2:    return "~8,000 词"
        case .ielts:     return "~7,000 词"
        case .toefl:     return "~8,000 词"
        }
    }

    /// The passing threshold for the level test (0-1).
    var passThreshold: Double { 0.6 }

    /// Suggested fallback level if the user fails the test.
    var fallbackLevel: UserLevel? {
        switch self {
        case .primary:   return nil
        case .junior1:   return .primary
        case .junior2:   return .junior1
        case .junior3:   return .junior2
        case .senior1:   return .junior3
        case .senior2:   return .senior1
        case .senior3:   return .senior2
        case .cet4:      return .senior3
        case .cet6:      return .cet4
        case .graduate:  return .cet6
        case .daily:     return nil
        case .ket:       return nil
        case .pet:       return .ket
        case .fce:       return .pet
        case .cae:       return .fce
        case .cpe:       return .cae
        case .cefrA1:    return nil
        case .cefrA2:    return .cefrA1
        case .cefrB1:    return .cefrA2
        case .cefrB2:    return .cefrB1
        case .cefrC1:    return .cefrB2
        case .cefrC2:    return .cefrC1
        case .ielts:     return .cefrB2
        case .toefl:     return .cefrB2
        }
    }
}

enum LevelGroup: String, CaseIterable, Identifiable {
    case domesticPrimary  = "国内·小学"
    case domesticMiddle   = "国内·初中"
    case domesticHigh     = "国内·高中"
    case domesticCollege  = "国内·大学"
    case domesticExam     = "国内·考研"
    case domesticDaily    = "国内·日常"
    case overseasCambridge = "国外·剑桥"
    case overseasCefr      = "国外·CEFR"
    case overseasExam      = "国外·留学考试"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .domesticPrimary:   return "house.fill"
        case .domesticMiddle:    return "book.fill"
        case .domesticHigh:      return "graduationcap.fill"
        case .domesticCollege:   return "building.columns.fill"
        case .domesticExam:      return "flag.checkered"
        case .domesticDaily:     return "cup.and.saucer.fill"
        case .overseasCambridge: return "star.fill"
        case .overseasCefr:      return "globe.europe.africa.fill"
        case .overseasExam:      return "airplane"
        }
    }

    var color: Color {
        switch self {
        case .domesticPrimary:   return .orange
        case .domesticMiddle:    return .blue
        case .domesticHigh:      return .indigo
        case .domesticCollege:   return .purple
        case .domesticExam:      return .red
        case .domesticDaily:     return .green
        case .overseasCambridge: return .pink
        case .overseasCefr:      return .teal
        case .overseasExam:      return .cyan
        }
    }
}

// MARK: - Level Test Question

struct LevelTestQuestion: Identifiable {
    let id = UUID()
    let stem: String           // The question text
    let options: [String]      // 4 choices
    let correctIndex: Int      // 0-based
    let level: UserLevel       // Which level this question belongs to
}

// MARK: - Onboarding State (persisted)

struct OnboardingState: Codable {
    var isCompleted: Bool = false
    var selectedLevel: UserLevel?
    var testScore: Double?          // 0-1
    var confirmedLevel: UserLevel?  // The final level after test
    var completedAt: Date?
}

// MARK: - Welcome Page

struct WelcomePage: Identifiable {
    let id = UUID()
    let icon: String         // SF Symbol
    let color: Color
    let title: String
    let body: String
}

extension WelcomePage {
    static let pages: [WelcomePage] = [
        WelcomePage(
            icon: "wand.and.stars",
            color: .orange,
            title: "欢迎来到 Volingo",
            body: "专为中国孩子打造的智能英语学习伙伴，\n从单词到写作，一站式搞定"
        ),
        WelcomePage(
            icon: "chart.line.uptrend.xyaxis",
            color: .blue,
            title: "量身定制你的学习之路",
            body: "通过科学定级测试，\n为你推荐最适合的学习内容和练习难度"
        ),
        WelcomePage(
            icon: "brain.head.profile",
            color: .purple,
            title: "越练越聪明",
            body: "AI 动态出题 + 艾宾浩斯记忆法，\n巩固每一个知识点，学了就不忘"
        ),
    ]
}
