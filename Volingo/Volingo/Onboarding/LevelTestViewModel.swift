//
//  LevelTestViewModel.swift
//  Volingo
//
//  Created by jacob on 2026/2/8.
//

import Foundation
import SwiftUI

final class LevelTestViewModel: ObservableObject {
    @Published private(set) var questions: [LevelTestQuestion] = []
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var correctCount: Int = 0
    @Published private(set) var isCompleted: Bool = false
    @Published var selectedOptionIndex: Int? = nil

    let level: UserLevel

    init(level: UserLevel) {
        self.level = level
        self.questions = LevelTestQuestionBank.questions(for: level)
    }

    var currentQuestion: LevelTestQuestion? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentIndex) / Double(questions.count)
    }

    var score: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(correctCount) / Double(questions.count)
    }

    func selectOption(_ index: Int) {
        guard selectedOptionIndex == nil else { return }
        selectedOptionIndex = index

        if let currentQuestion, index == currentQuestion.correctIndex {
            correctCount += 1
        }
    }

    func goNext() {
        guard selectedOptionIndex != nil else { return }
        selectedOptionIndex = nil
        currentIndex += 1
        if currentIndex >= questions.count {
            isCompleted = true
        }
    }

    func reset() {
        currentIndex = 0
        correctCount = 0
        isCompleted = false
        selectedOptionIndex = nil
    }
}

enum LevelTestQuestionBank {
    static func questions(for level: UserLevel) -> [LevelTestQuestion] {
        // Placeholder bank with simple, kid-friendly questions.
        // Replace with real level-specific banks later.
        let base: [LevelTestQuestion] = [
            LevelTestQuestion(
                stem: "选出‘苹果’的英文",
                options: ["apple", "banana", "orange", "grape"],
                correctIndex: 0,
                level: level
            ),
            LevelTestQuestion(
                stem: "选出‘我们是学生。’的英文",
                options: ["We are students.", "We is students.", "We am student.", "We are student."],
                correctIndex: 0,
                level: level
            ),
            LevelTestQuestion(
                stem: "选出句子中动词过去式：go",
                options: ["goes", "went", "going", "gone"],
                correctIndex: 1,
                level: level
            ),
            LevelTestQuestion(
                stem: "选出正确的介词：I am ___ school.",
                options: ["in", "on", "at", "by"],
                correctIndex: 2,
                level: level
            ),
            LevelTestQuestion(
                stem: "选择同义词：big",
                options: ["small", "large", "short", "thin"],
                correctIndex: 1,
                level: level
            ),
            LevelTestQuestion(
                stem: "选出正确句子：",
                options: ["She don't like milk.", "She doesn't like milk.", "She doesn't likes milk.", "She don't likes milk."],
                correctIndex: 1,
                level: level
            ),
            LevelTestQuestion(
                stem: "选出‘他们正在跑步’的英文",
                options: ["They are running.", "They is running.", "They are run.", "They running."],
                correctIndex: 0,
                level: level
            ),
            LevelTestQuestion(
                stem: "选出正确疑问句：你几点起床？",
                options: ["What time do you get up?", "What time you get up?", "What time are you get up?", "What time does you get up?"],
                correctIndex: 0,
                level: level
            )
        ]

        if level == .toefl || level == .ielts || level == .graduate ||
            level == .fce || level == .cae || level == .cpe ||
            level == .cefrC1 || level == .cefrC2 {
            return base + [
                LevelTestQuestion(
                    stem: "选择最恰当的词：This result is ___ with our expectations.",
                    options: ["consistent", "confuse", "consist", "consistency"],
                    correctIndex: 0,
                    level: level
                ),
                LevelTestQuestion(
                    stem: "选出最佳改写：The policy was implemented quickly.",
                    options: ["The policy was carried out rapidly.", "The policy was done fastly.", "The policy was implement quick.", "The policy was making quickly."],
                    correctIndex: 0,
                    level: level
                )
            ]
        }

        return base
    }
}
