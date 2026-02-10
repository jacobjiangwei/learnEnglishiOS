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

    init(level: UserLevel, attemptId: UUID, count: Int = 10) {
        self.level = level
        self.questions = LevelTestQuestionBank.questions(for: level, attemptId: attemptId, count: count)
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
    static func questions(for level: UserLevel, attemptId: UUID, count: Int) -> [LevelTestQuestion] {
        var pool = baseQuestions(for: level)
        if pool.isEmpty {
            pool = genericQuestions(for: level)
        }

        var generator = SeededGenerator(seed: attemptId.uuidString.hashValue)
        pool.shuffle(using: &generator)
        let selected = Array(pool.prefix(max(6, min(count, pool.count))))
        return selected.map { shuffledOptions(for: $0, generator: &generator) }
    }

    private static func shuffledOptions(for question: LevelTestQuestion, generator: inout SeededGenerator) -> LevelTestQuestion {
        let indices = Array(question.options.indices)
        var shuffled = indices
        shuffled.shuffle(using: &generator)

        let newOptions = shuffled.map { question.options[$0] }
        let newCorrectIndex = shuffled.firstIndex(of: question.correctIndex) ?? question.correctIndex
        return LevelTestQuestion(
            stem: question.stem,
            options: newOptions,
            correctIndex: newCorrectIndex,
            level: question.level
        )
    }

    private static func baseQuestions(for level: UserLevel) -> [LevelTestQuestion] {
        switch level.group {
        case .domesticPrimary:
            return primaryQuestions(for: level)
        case .domesticMiddle:
            return middleQuestions(for: level)
        case .domesticHigh:
            return highQuestions(for: level)
        case .domesticCollege:
            return collegeQuestions(for: level)
        case .domesticExam:
            return graduateQuestions(for: level)
        case .domesticDaily:
            return dailyQuestions(for: level)
        case .overseasCambridge:
            return cambridgeQuestions(for: level)
        case .overseasCefr:
            return cefrQuestions(for: level)
        case .overseasExam:
            return overseasExamQuestions(for: level)
        }
    }

    private static func primaryQuestions(for level: UserLevel) -> [LevelTestQuestion] {
        return [
            LevelTestQuestion(stem: "选出‘苹果’的英文", options: ["apple", "banana", "orange", "grape"], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出‘书包’的英文", options: ["bag", "book", "desk", "chair"], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出‘我有一只猫。’的英文", options: ["I have a cat.", "I has a cat.", "I have cat.", "I has cat."], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出正确的颜色：blue", options: ["蓝色", "红色", "绿色", "黄色"], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出‘他是我的朋友。’的英文", options: ["He is my friend.", "He are my friend.", "He am my friend.", "He is my friends."], correctIndex: 0, level: level)
        ]
    }

    private static func middleQuestions(for level: UserLevel) -> [LevelTestQuestion] {
        return [
            LevelTestQuestion(stem: "选出正确介词：I am ___ school.", options: ["in", "on", "at", "by"], correctIndex: 2, level: level),
            LevelTestQuestion(stem: "选出‘他们正在跑步’的英文", options: ["They are running.", "They is running.", "They are run.", "They running."], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出动词过去式：go", options: ["goes", "went", "going", "gone"], correctIndex: 1, level: level),
            LevelTestQuestion(stem: "选出正确句子：", options: ["She don't like milk.", "She doesn't like milk.", "She doesn't likes milk.", "She don't likes milk."], correctIndex: 1, level: level),
            LevelTestQuestion(stem: "选出正确疑问句：你几点起床？", options: ["What time do you get up?", "What time you get up?", "What time are you get up?", "What time does you get up?"], correctIndex: 0, level: level)
        ]
    }

    private static func highQuestions(for level: UserLevel) -> [LevelTestQuestion] {
        return [
            LevelTestQuestion(stem: "选出正确句子：", options: ["Neither he nor I am wrong.", "Neither he nor I are wrong.", "Neither he nor I be wrong.", "Neither he nor I is wrong."], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选择同义词：important", options: ["significant", "strange", "quiet", "weak"], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出正确时态：By the time he arrived, she ___ .", options: ["left", "had left", "has left", "was left"], correctIndex: 1, level: level),
            LevelTestQuestion(stem: "选出正确的非谓语：", options: ["Seeing is believing.", "See is believing.", "Saw is believing.", "Seen is believing."], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出语法正确的句子：", options: ["I prefer tea to coffee.", "I prefer tea than coffee.", "I prefer tea for coffee.", "I prefer tea with coffee."], correctIndex: 0, level: level)
        ]
    }

    private static func collegeQuestions(for level: UserLevel) -> [LevelTestQuestion] {
        return [
            LevelTestQuestion(stem: "选出最佳改写：The policy was implemented quickly.", options: ["The policy was carried out rapidly.", "The policy was done fastly.", "The policy was implement quick.", "The policy was making quickly."], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出最恰当的词：This result is ___ with our expectations.", options: ["consistent", "confuse", "consist", "consistency"], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出正确用法：", options: ["No sooner had I arrived than it rained.", "No sooner I arrived than it rained.", "No sooner did I arrived than it rained.", "No sooner had I arrive than it rained."], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选择同义词：conclude", options: ["finish", "confuse", "admire", "limit"], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出正确搭配：", options: ["take responsibility for", "take responsibility to", "take responsibility with", "take responsibility at"], correctIndex: 0, level: level)
        ]
    }

    private static func graduateQuestions(for level: UserLevel) -> [LevelTestQuestion] {
        return [
            LevelTestQuestion(stem: "选出最佳改写：The company faced severe challenges.", options: ["The company encountered severe challenges.", "The company met severe challenges with.", "The company faced with severe challenges.", "The company facing severe challenges."], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选择最恰当的词：The proposal was ___ by the committee.", options: ["endorsed", "avoid", "relax", "arrive"], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出语法正确句子：", options: ["Had it not been for him, I would have failed.", "Had it not been for him, I will fail.", "Had not been for him, I would fail.", "Had it not been for him, I would failed."], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选择同义词：evidence", options: ["proof", "advise", "effort", "reason"], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出正确介词：", options: ["be committed to", "be committed with", "be committed at", "be committed by"], correctIndex: 0, level: level)
        ]
    }

    private static func dailyQuestions(for level: UserLevel) -> [LevelTestQuestion] {
        return [
            LevelTestQuestion(stem: "选出‘多少钱？’的英文", options: ["How much is it?", "How many is it?", "How long is it?", "How far is it?"], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出‘我迷路了’的英文", options: ["I am lost.", "I am lose.", "I lost.", "I am losing."], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出正确回答：Thank you.", options: ["You are welcome.", "Yes, please.", "No, thanks.", "See you."], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出正确句子：", options: ["Could you help me?", "Could you helps me?", "Could you helping me?", "Could you helped me?"], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出‘我想要一杯水’的英文", options: ["I'd like a glass of water.", "I like a glass water.", "I want water a glass.", "I'd like water of a glass."], correctIndex: 0, level: level)
        ]
    }

    private static func cambridgeQuestions(for level: UserLevel) -> [LevelTestQuestion] {
        return [
            LevelTestQuestion(stem: "选出正确句子：", options: ["He can play the piano.", "He can plays the piano.", "He can to play the piano.", "He can playing the piano."], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出‘请把门关上’的英文", options: ["Please close the door.", "Please closed the door.", "Please closes the door.", "Please closing the door."], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出正确介词：She is good ___ math.", options: ["at", "in", "on", "to"], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选择同义词：happy", options: ["glad", "sad", "angry", "tired"], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出正确时态：I ___ here since 2020.", options: ["have lived", "live", "lived", "am living"], correctIndex: 0, level: level)
        ]
    }

    private static func cefrQuestions(for level: UserLevel) -> [LevelTestQuestion] {
        return [
            LevelTestQuestion(stem: "选择最恰当的词：He was ___ to arrive on time.", options: ["likely", "possible", "probably", "maybe"], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出正确搭配：", options: ["make progress", "do progress", "take progress", "get progress"], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出语法正确句子：", options: ["If I had known, I would have told you.", "If I know, I would tell you.", "If I had knew, I would tell you.", "If I knowed, I would have told you."], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选择同义词：rapid", options: ["quick", "late", "slow", "tired"], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出正确结构：", options: ["be interested in", "be interested at", "be interested on", "be interested to"], correctIndex: 0, level: level)
        ]
    }

    private static func overseasExamQuestions(for level: UserLevel) -> [LevelTestQuestion] {
        return [
            LevelTestQuestion(stem: "选出最佳改写：The research indicates a clear trend.", options: ["The research suggests a clear trend.", "The research tell a clear trend.", "The research indicates clear trendly.", "The research says a clearly trend."], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选择最恰当的词：The solution is ___ to be effective.", options: ["proven", "prove", "proving", "proof"], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出正确句子：", options: ["The report has been submitted.", "The report has submitted.", "The report have been submitted.", "The report was submitted by yesterday."], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选择同义词：significant", options: ["important", "simple", "common", "casual"], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出正确搭配：", options: ["be responsible for", "be responsible to", "be responsible with", "be responsible at"], correctIndex: 0, level: level)
        ]
    }

    private static func genericQuestions(for level: UserLevel) -> [LevelTestQuestion] {
        return [
            LevelTestQuestion(stem: "选出‘我们是学生。’的英文", options: ["We are students.", "We is students.", "We am student.", "We are student."], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出正确句子：", options: ["She doesn't like milk.", "She don't like milk.", "She doesn't likes milk.", "She don't likes milk."], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选择同义词：big", options: ["large", "small", "short", "thin"], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出正确介词：I am ___ school.", options: ["at", "on", "in", "by"], correctIndex: 0, level: level),
            LevelTestQuestion(stem: "选出正确疑问句：你几点起床？", options: ["What time do you get up?", "What time you get up?", "What time are you get up?", "What time does you get up?"], correctIndex: 0, level: level)
        ]
    }
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        self.state = UInt64(bitPattern: Int64(seed))
        if self.state == 0 { self.state = 0x9E3779B97F4A7C15 }
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
