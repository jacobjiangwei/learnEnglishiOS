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
    case primary1    = "小学一年级"
    case primary2    = "小学二年级"
    case primary3    = "小学三年级"
    case primary4    = "小学四年级"
    case primary5    = "小学五年级"
    case primary6    = "小学六年级"
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

    /// Whether this is an elementary school level (grades 1-6)
    var isPrimary: Bool {
        switch self {
        case .primary1, .primary2, .primary3, .primary4, .primary5, .primary6:
            return true
        default:
            return false
        }
    }

    /// Short Chinese subtitle shown below the label.
    var subtitle: String {
        switch self {
        case .primary1:  return "小学一年级"
        case .primary2:  return "小学二年级"
        case .primary3:  return "小学三年级"
        case .primary4:  return "小学四年级"
        case .primary5:  return "小学五年级"
        case .primary6:  return "小学六年级"
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
           case .primary1, .primary2, .primary3,
                .primary4, .primary5, .primary6: return .domesticPrimary
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
        case .primary1:  return "~400 词"
        case .primary2:  return "~600 词"
        case .primary3:  return "~800 词"
        case .primary4:  return "~1,000 词"
        case .primary5:  return "~1,200 词"
        case .primary6:  return "~1,500 词"
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
        case .primary1:  return nil
        case .primary2:  return .primary1
        case .primary3:  return .primary2
        case .primary4:  return .primary3
        case .primary5:  return .primary4
        case .primary6:  return .primary5
        case .junior1:   return .primary6
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

    /// Grade number used for textbook code generation.
    var gradeNumber: Int? {
        switch self {
        case .primary1:  return 1
        case .primary2:  return 2
        case .primary3:  return 3
        case .primary4:  return 4
        case .primary5:  return 5
        case .primary6:  return 6
        case .junior1:   return 7
        case .junior2:   return 8
        case .junior3:   return 9
        case .senior1:   return 10
        case .senior2:   return 11
        case .senior3:   return 12
        default:         return nil
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

// MARK: - Textbook

enum TextbookOption: String, Codable, CaseIterable, Identifiable {
    case primaryPEP = "小学·人教版"
    case primaryFLTRP = "小学·外研版"
    case primaryYilin = "小学·译林版"
    case primaryHujiao = "小学·沪教版"
    case juniorPEP = "初中·人教版"
    case juniorFLTRP = "初中·外研版"
    case juniorYilin = "初中·译林版"
    case juniorHujiao = "初中·沪教版"
    case seniorPEP = "高中·人教版"
    case seniorFLTRP = "高中·外研版"
    case seniorYilin = "高中·译林版"
    case seniorHujiao = "高中·沪教版"
    case collegeCet = "大学英语（四级/六级）"
    case graduateExam = "考研英语"
    case preschoolPhonics = "启蒙/自然拼读"
    case cefr = "CEFR 分级"
    case cambridge = "剑桥 English in Use"
    case longman = "朗文 Speakout/Cutting Edge"
    case ielts = "雅思备考"
    case toefl = "托福备考"

    var id: String { rawValue }

    var group: TextbookGroup {
        switch self {
        case .primaryPEP, .primaryFLTRP, .primaryYilin, .primaryHujiao,
             .juniorPEP, .juniorFLTRP, .juniorYilin, .juniorHujiao,
             .seniorPEP, .seniorFLTRP, .seniorYilin, .seniorHujiao,
             .collegeCet, .graduateExam, .preschoolPhonics:
            return .gradeSync
        case .cefr:
            return .generalLevel
        case .cambridge, .longman:
            return .international
        case .ielts, .toefl:
            return .examPrep
        }
    }

    var subtitle: String {
        switch self {
        case .primaryPEP:            return "小学主流版本"
        case .primaryFLTRP:          return "小学主流版本"
        case .primaryYilin:          return "小学主流版本"
        case .primaryHujiao:         return "小学主流版本"
        case .juniorPEP:             return "初中主流版本"
        case .juniorFLTRP:           return "初中主流版本"
        case .juniorYilin:           return "初中主流版本"
        case .juniorHujiao:          return "初中主流版本"
        case .seniorPEP:             return "高中主流版本"
        case .seniorFLTRP:           return "高中主流版本"
        case .seniorYilin:           return "高中主流版本"
        case .seniorHujiao:          return "高中主流版本"
        case .collegeCet:        return "大学英语体系"
        case .graduateExam:      return "考研词汇与阅读"
        case .preschoolPhonics:  return "启蒙与发音基础"
        case .cefr:              return "国际通用等级"
        case .cambridge:         return "语法+词汇体系化"
        case .longman:           return "口语与场景表达"
        case .ielts:             return "题型与评分导向"
        case .toefl:             return "学术英语导向"
        }
    }

    static func recommended(for level: UserLevel) -> TextbookOption {
        switch level {
        case .primary1, .primary2, .primary3, .primary4, .primary5, .primary6:
            return .primaryPEP
        case .junior1, .junior2, .junior3:
            return .juniorPEP
        case .senior1, .senior2, .senior3:
            return .seniorPEP
        case .cet4, .cet6:
            return .collegeCet
        case .graduate:
            return .graduateExam
        case .daily:
            return .cefr
        case .ket, .pet, .fce, .cae, .cpe:
            return .cambridge
        case .cefrA1, .cefrA2, .cefrB1, .cefrB2, .cefrC1, .cefrC2:
            return .cefr
        case .ielts:
            return .ielts
        case .toefl:
            return .toefl
        }
    }

    static func options(for level: UserLevel) -> [TextbookOption] {
        switch level {
        case .primary1, .primary2, .primary3, .primary4, .primary5, .primary6:
            return [.primaryPEP, .primaryFLTRP, .primaryYilin, .primaryHujiao]
        case .junior1, .junior2, .junior3:
            return [.juniorPEP, .juniorFLTRP, .juniorYilin, .juniorHujiao]
        case .senior1, .senior2, .senior3:
            return [.seniorPEP, .seniorFLTRP, .seniorYilin, .seniorHujiao]
        case .cet4, .cet6:
            return [.collegeCet]
        case .graduate:
            return [.graduateExam]
        case .daily:
            return [.cefr, .longman]
        case .ket, .pet, .fce, .cae, .cpe:
            return [.cambridge, .cefr]
        case .cefrA1, .cefrA2, .cefrB1, .cefrB2, .cefrC1, .cefrC2:
            return [.cefr]
        case .ielts:
            return [.ielts]
        case .toefl:
            return [.toefl]
        }
    }

    /// Base identifier used by the query code.
    var seriesCode: String {
        switch self {
        case .primaryPEP:            return "primaryPEP"
        case .primaryFLTRP:          return "primaryFLTRP"
        case .primaryYilin:          return "primaryYilin"
        case .primaryHujiao:         return "primaryHujiao"
        case .juniorPEP:             return "juniorPEP"
        case .juniorFLTRP:           return "juniorFLTRP"
        case .juniorYilin:           return "juniorYilin"
        case .juniorHujiao:          return "juniorHujiao"
        case .seniorPEP:             return "seniorPEP"
        case .seniorFLTRP:           return "seniorFLTRP"
        case .seniorYilin:           return "seniorYilin"
        case .seniorHujiao:          return "seniorHujiao"
        case .collegeCet:            return "collegeCet"
        case .graduateExam:          return "graduateExam"
        case .preschoolPhonics:      return "preschoolPhonics"
        case .cefr:                  return "cefr"
        case .cambridge:             return "cambridge"
        case .longman:               return "longman"
        case .ielts:                 return "ielts"
        case .toefl:                 return "toefl"
        }
    }

    /// Full textbook query code, e.g. juniorPEP-7a.
    func code(for level: UserLevel, term: Semester) -> String? {
        guard group == .gradeSync else {
            return seriesCode
        }
        guard let grade = level.gradeNumber else {
            return seriesCode
        }
        return "\(seriesCode)-\(grade)\(term.rawValue)"
    }
}

enum Semester: String, Codable, CaseIterable, Identifiable {
    case first = "a"
    case second = "b"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .first:  return "上"
        case .second: return "下"
        }
    }

    /// 根据当前日期推荐学期：9月–1月 = 上学期，2月–7月 = 下学期
    static var current: Semester {
        let month = Calendar.current.component(.month, from: Date())
        // 9,10,11,12,1 -> 上学期; 2,3,4,5,6,7 -> 下学期; 8月开学前算上学期
        return (month >= 2 && month <= 7) ? .second : .first
    }
}

enum TextbookGroup: String, CaseIterable, Identifiable {
    case gradeSync = "学段版本"
    case generalLevel = "通用分级"
    case international = "国际教材"
    case examPrep = "考试备考"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .gradeSync:     return "books.vertical.fill"
        case .generalLevel:  return "chart.bar.fill"
        case .international: return "globe.europe.africa.fill"
        case .examPrep:      return "pencil.and.outline"
        }
    }

    var color: Color {
        switch self {
        case .gradeSync:     return .orange
        case .generalLevel:  return .teal
        case .international: return .indigo
        case .examPrep:      return .red
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

// MARK: - User State (persisted)

struct UserState: Codable {
    var isOnboardingCompleted: Bool = false
    var selectedLevel: UserLevel?
    var selectedTextbook: TextbookOption?
    var selectedSemester: Semester?
    var confirmedLevel: UserLevel?
    var lastAssessmentScore: Double?
    var lastAssessmentAt: Date?
    var createdAt: Date = Date()
    var preferences: LearningPreferences = LearningPreferences()

    /// Whether the selected level requires a semester choice (小学/初中/高中).
    /// `gradeNumber` is non-nil only for primary1…senior3 (grades 1-12),
    /// so this is true exclusively for 小学一年级 ~ 高三.
    var needsSemester: Bool {
        guard let level = selectedLevel ?? confirmedLevel else { return false }
        return level.gradeNumber != nil
    }
}

enum OnboardingEntry {
    case full
    case selectLevel
    case selectTextbook
    case retest
}

struct LearningPreferences: Codable {
    var dailyWordGoal: Int = 10
    var dailyMinutesGoal: Int = 10
    var studyMode: StudyMode = .balanced
}

enum StudyMode: String, Codable, CaseIterable {
    case balanced = "均衡"
    case exam = "应试"
    case daily = "日常"
    case speaking = "口语"
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
