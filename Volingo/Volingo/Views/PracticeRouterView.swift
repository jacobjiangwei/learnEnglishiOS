//
//  PracticeRouterView.swift
//  Volingo
//
//  Created by jacob on 2026/2/13.
//

import SwiftUI

/// 题型路由：根据 QuestionType 展示对应的练习界面
struct PracticeRouterView: View {
    let questionType: QuestionType

    var body: some View {
        switch questionType {
        // 题型类
        case .multipleChoice:
            MCQPracticeView(title: "选择题", questions: MockDataFactory.mcqQuestions())
        case .cloze:
            ClozePracticeView(questions: MockDataFactory.clozeQuestions())
        case .reading:
            ReadingPracticeView(passage: MockDataFactory.readingPassage())
        case .translation:
            TextInputPracticeView(title: "翻译题", items: MockDataFactory.translationItems())
        case .rewriting:
            TextInputPracticeView(title: "句型改写", items: MockDataFactory.rewritingItems())
        case .errorCorrection:
            ErrorCorrectionPracticeView(questions: MockDataFactory.errorCorrectionQuestions())
        case .sentenceOrdering:
            OrderingPracticeView(questions: MockDataFactory.orderingQuestions())

        // 能力类
        case .listening:
            ListeningPracticeView(questions: MockDataFactory.listeningQuestions())
        case .speaking:
            SpeakingPracticeView(questions: MockDataFactory.speakingQuestions())
        case .writing:
            TextInputPracticeView(title: "写作专项", items: MockDataFactory.writingItems())
        case .vocabulary:
            MCQPracticeView(title: "词汇专项", questions: MockDataFactory.vocabularyQuestions())
        case .grammar:
            MCQPracticeView(title: "语法专项", questions: MockDataFactory.grammarQuestions())

        // 场景类
        case .scenarioDaily:
            ScenarioPracticeView(questions: MockDataFactory.scenarioQuestions(for: .scenarioDaily))
        case .scenarioCampus:
            ScenarioPracticeView(questions: MockDataFactory.scenarioQuestions(for: .scenarioCampus))
        case .scenarioWorkplace:
            ScenarioPracticeView(questions: MockDataFactory.scenarioQuestions(for: .scenarioWorkplace))
        case .scenarioTravel:
            ScenarioPracticeView(questions: MockDataFactory.scenarioQuestions(for: .scenarioTravel))

        // 轻量类（复用 MCQ，Mock 数据）
        case .quickSprint:
            MCQPracticeView(title: "5分钟快练", questions: MockDataFactory.mcqQuestions())
        case .errorReview:
            MCQPracticeView(title: "错题复练", questions: MockDataFactory.mcqQuestions())
        case .randomChallenge:
            MCQPracticeView(title: "随机挑战", questions: MockDataFactory.mcqQuestions())
        case .timedDrill:
            MCQPracticeView(title: "提速训练", questions: MockDataFactory.mcqQuestions())
        }
    }
}

#Preview {
    NavigationView {
        PracticeRouterView(questionType: .multipleChoice)
    }
}
