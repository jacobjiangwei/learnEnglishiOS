//
//  OnboardingModels.swift
//  海豹英语
//
//  Created by jacob on 2026/2/8.
//

import Foundation
import SwiftUI

// MARK: - User Level (= Grade)

/// Represents the user's grade / proficiency level.
/// The enum case name doubles as the `grade` API code (e.g. "junior1", "cefrB2").
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

    /// Stable identifier for API transport (enum case name, e.g. "junior1", "cefrB2")
    var apiKey: String {
        String(describing: self)
    }

    /// Find a UserLevel by its API key
    static func from(apiKey: String) -> UserLevel? {
        allCases.first { $0.apiKey == apiKey }
    }

    /// Whether this grade is a school grade (has textbook + semester).
    var isSchoolGrade: Bool {
        gradeNumber != nil
    }

    /// Whether this is an elementary school level (grades 1-6)
    var isPrimary: Bool {
        switch self {
        case .primary1, .primary2, .primary3, .primary4, .primary5, .primary6:
            return true
        default:
            return false
        }
    }

    /// Stage prefix used in textbookCode generation: "primary", "junior", "senior"
    var stage: String? {
        switch self {
        case .primary1, .primary2, .primary3, .primary4, .primary5, .primary6:
            return "primary"
        case .junior1, .junior2, .junior3:
            return "junior"
        case .senior1, .senior2, .senior3:
            return "senior"
        default:
            return nil
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

// MARK: - Publisher

/// Textbook publisher — only needed for school grades.
enum Publisher: String, Codable, CaseIterable, Identifiable {
    case pep    = "pep"
    case fltrp  = "fltrp"
    case yilin  = "yilin"
    case hujiao = "hujiao"

    var id: String { rawValue }

    /// Chinese display name
    var displayName: String {
        switch self {
        case .pep:    return "人教版"
        case .fltrp:  return "外研版"
        case .yilin:  return "译林版"
        case .hujiao: return "沪教版"
        }
    }

    /// Short English code used in textbookCode generation (e.g. "PEP", "Yilin")
    var codePrefix: String {
        switch self {
        case .pep:    return "PEP"
        case .fltrp:  return "FLTRP"
        case .yilin:  return "Yilin"
        case .hujiao: return "Hujiao"
        }
    }

    /// Subtitle shown in the picker
    var subtitle: String {
        switch self {
        case .pep:    return "全国使用最广泛"
        case .fltrp:  return "注重听说能力"
        case .yilin:  return "江苏地区常用"
        case .hujiao: return "上海地区常用"
        }
    }

    /// Icon for the card
    var icon: String { "books.vertical.fill" }

    /// Card tint color
    var color: Color {
        switch self {
        case .pep:    return .orange
        case .fltrp:  return .blue
        case .yilin:  return .green
        case .hujiao: return .purple
        }
    }

    /// Default recommended publisher
    static let recommended: Publisher = .pep
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

// MARK: - Unit Count Mapping

/// Returns the number of units for a given grade + publisher + semester combination.
/// Data based on current mainstream textbook editions.
func unitCount(for grade: UserLevel, publisher: Publisher, semester: Semester) -> Int {
    switch (grade, publisher, semester) {
    // ── 小学 PEP ──
    case (.primary1, .pep, _):          return 6
    case (.primary2, .pep, _):          return 6
    case (.primary3, .pep, _):          return 6
    case (.primary4, .pep, _):          return 6
    case (.primary5, .pep, _):          return 6
    case (.primary6, .pep, _):          return 6

    // ── 小学 外研版 ──
    case (.primary1, .fltrp, _):        return 10
    case (.primary2, .fltrp, _):        return 10
    case (.primary3, .fltrp, _):        return 10
    case (.primary4, .fltrp, _):        return 10
    case (.primary5, .fltrp, _):        return 10
    case (.primary6, .fltrp, _):        return 10

    // ── 小学 译林版 ──
    case (.primary1, .yilin, _):        return 8
    case (.primary2, .yilin, _):        return 8
    case (.primary3, .yilin, _):        return 8
    case (.primary4, .yilin, _):        return 8
    case (.primary5, .yilin, _):        return 8
    case (.primary6, .yilin, _):        return 8

    // ── 小学 沪教版 ──
    case (.primary1, .hujiao, _):       return 12
    case (.primary2, .hujiao, _):       return 12
    case (.primary3, .hujiao, _):       return 12
    case (.primary4, .hujiao, _):       return 12
    case (.primary5, .hujiao, _):       return 12
    case (.primary6, .hujiao, _):       return 12

    // ── 初中 PEP ──
    case (.junior1, .pep, _):           return 10
    case (.junior2, .pep, _):           return 10
    case (.junior3, .pep, _):           return 10

    // ── 初中 外研版 ──
    case (.junior1, .fltrp, _):         return 12
    case (.junior2, .fltrp, _):         return 12
    case (.junior3, .fltrp, _):         return 12

    // ── 初中 译林版 ──
    case (.junior1, .yilin, _):         return 8
    case (.junior2, .yilin, _):         return 8
    case (.junior3, .yilin, _):         return 8

    // ── 初中 沪教版 ──
    case (.junior1, .hujiao, _):        return 12
    case (.junior2, .hujiao, _):        return 12
    case (.junior3, .hujiao, _):        return 12

    // ── 高中 PEP ──
    case (.senior1, .pep, _):           return 5
    case (.senior2, .pep, _):           return 5
    case (.senior3, .pep, _):           return 5

    // ── 高中 外研版 ──
    case (.senior1, .fltrp, _):         return 6
    case (.senior2, .fltrp, _):         return 6
    case (.senior3, .fltrp, _):         return 6

    // ── 高中 译林版 ──
    case (.senior1, .yilin, _):         return 4
    case (.senior2, .yilin, _):         return 4
    case (.senior3, .yilin, _):         return 4

    // ── 高中 沪教版 ──
    case (.senior1, .hujiao, _):        return 6
    case (.senior2, .hujiao, _):        return 6
    case (.senior3, .hujiao, _):        return 6

    default:                            return 16
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

    // ── 学习设置 ──
    var grade: String?           // "junior1" — UserLevel.apiKey
    var publisher: String?       // "pep" — Publisher.rawValue (school grades only)
    var semester: String?        // "a" / "b" — Semester.rawValue (school grades only)
    var currentUnit: Int?        // 1-based (V1: always 1)

    var createdAt: Date = Date()
    var preferences: LearningPreferences = LearningPreferences()

    /// Resolved grade enum
    var gradeEnum: UserLevel? {
        guard let grade else { return nil }
        return UserLevel.from(apiKey: grade)
    }

    /// Resolved publisher enum
    var publisherEnum: Publisher? {
        guard let publisher else { return nil }
        return Publisher(rawValue: publisher)
    }

    /// Resolved semester enum
    var semesterEnum: Semester? {
        guard let semester else { return nil }
        return Semester(rawValue: semester)
    }

    /// Whether the current grade is a school grade (needs publisher + semester).
    var needsPublisher: Bool {
        gradeEnum?.isSchoolGrade ?? false
    }

    /// Computed textbookCode for API queries (e.g. "juniorPEP-7a" or "cet4").
    var textbookCode: String? {
        guard let gradeEnum else { return nil }

        // Non-school grade → grade itself is the textbookCode
        guard gradeEnum.isSchoolGrade else { return grade }

        // School grade → need publisher + semester
        guard let pub = publisherEnum,
              let sem = semester,
              let stage = gradeEnum.stage,
              let gradeNum = gradeEnum.gradeNumber else { return nil }
        return "\(stage)\(pub.codePrefix)-\(gradeNum)\(sem)"
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
            title: "智能英语学习伙伴",
            body: "专为中国孩子打造，\n从单词到写作，一站式搞定"
        ),
        WelcomePage(
            icon: "chart.line.uptrend.xyaxis",
            color: .blue,
            title: "量身定制学习之路",
            body: "根据你的等级和教材，\n推荐最适合的学习内容和练习难度"
        ),
        WelcomePage(
            icon: "brain.head.profile",
            color: .purple,
            title: "越练越聪明",
            body: "AI 动态出题 + 艾宾浩斯记忆法，\n巩固每一个知识点，学了就不忘"
        ),
    ]
}
