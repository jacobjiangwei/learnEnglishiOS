//
//  PracticeRouterView.swift
//  Volingo
//
//  Created by jacob on 2026/2/13.
//

import SwiftUI

/// 题型路由：根据 QuestionType 从 API 加载题目，展示对应的练习界面
struct PracticeRouterView: View {
    let questionType: QuestionType
    @EnvironmentObject private var store: UserStateStore
    @StateObject private var vm = PracticeViewModel()

    private var textbookCode: String {
        store.currentTextbookCode ?? "juniorPEP-7a"
    }

    private func handleAnswer(_ questionId: String, _ isCorrect: Bool) {
        vm.recordAnswer(questionId: questionId, isCorrect: isCorrect)
    }

    var body: some View {
        Group {
            switch questionType {
            // 题型类
            case .multipleChoice, .quickSprint, .errorReview, .randomChallenge, .timedDrill:
                mcqContent(title: questionType.rawValue)
            case .cloze:
                clozeContent
            case .reading:
                readingContent
            case .translation:
                textInputContent(state: vm.translationItems, title: "翻译题")
            case .rewriting:
                textInputContent(state: vm.rewritingItems, title: "句型改写")
            case .errorCorrection:
                errorCorrectionContent
            case .sentenceOrdering:
                orderingContent

            // 能力类
            case .listening:
                listeningContent
            case .speaking:
                speakingContent
            case .writing:
                textInputContent(state: vm.writingItems, title: "写作专项")
            case .vocabulary:
                mcqContent(title: "词汇专项", state: vm.vocabularyQuestions)
            case .grammar:
                mcqContent(title: "语法专项", state: vm.grammarQuestions)

            // 场景类
            case .scenarioDaily, .scenarioCampus, .scenarioWorkplace, .scenarioTravel:
                scenarioContent
            }
        }
        .onAppear {
            vm.loadQuestions(type: questionType, textbookCode: textbookCode)
            AnalyticsService.shared.trackPracticeStarted(questionType: questionType.apiKey, textbookCode: textbookCode)
            AnalyticsService.shared.trackScreenView("Practice_\(questionType.rawValue)")
        }
        .onDisappear {
            if !vm.isReplayMode {
                vm.saveToHistory()
                // 标记今日推荐中该题型已完成
                TodayPackageStore.shared.markCompleted(questionType: questionType.apiKey)
            }
            Task { await vm.submitResults() }
        }
    }

    // MARK: - 通用加载 / 错误视图

    private func loadingView() -> some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("正在加载题目…")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("重试") {
                vm.loadQuestions(type: questionType, textbookCode: textbookCode)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - MCQ（选择题 / 词汇 / 语法 / 轻量类）

    @ViewBuilder
    private func mcqContent(title: String, state: LoadingState<[MCQQuestion]>? = nil) -> some View {
        let s = state ?? vm.mcqQuestions
        switch s {
        case .idle, .loading:
            loadingView()
        case .loaded(let questions):
            MCQPracticeView(title: title, questions: questions, showTranslationHint: store.userState.confirmedLevel?.isPrimary ?? false, onAnswer: handleAnswer)
        case .error(let msg):
            errorView(msg)
        }
    }

    // MARK: - 填空

    @ViewBuilder
    private var clozeContent: some View {
        switch vm.clozeQuestions {
        case .idle, .loading:
            loadingView()
        case .loaded(let questions):
            ClozePracticeView(questions: questions, onAnswer: handleAnswer)
        case .error(let msg):
            errorView(msg)
        }
    }

    // MARK: - 阅读

    @ViewBuilder
    private var readingContent: some View {
        switch vm.readingPassage {
        case .idle, .loading:
            loadingView()
        case .loaded(let passage):
            ReadingPracticeView(passage: passage, onAnswer: handleAnswer)
        case .error(let msg):
            errorView(msg)
        }
    }

    // MARK: - 文本输入（翻译 / 改写 / 写作）

    @ViewBuilder
    private func textInputContent(state: LoadingState<[TextInputItem]>, title: String) -> some View {
        switch state {
        case .idle, .loading:
            loadingView()
        case .loaded(let items):
            TextInputPracticeView(title: title, items: items, showTranslationHint: store.userState.confirmedLevel?.isPrimary ?? false, onAnswer: handleAnswer)
        case .error(let msg):
            errorView(msg)
        }
    }

    // MARK: - 纠错

    @ViewBuilder
    private var errorCorrectionContent: some View {
        switch vm.errorCorrectionQuestions {
        case .idle, .loading:
            loadingView()
        case .loaded(let questions):
            ErrorCorrectionPracticeView(questions: questions, onAnswer: handleAnswer)
        case .error(let msg):
            errorView(msg)
        }
    }

    // MARK: - 排序

    @ViewBuilder
    private var orderingContent: some View {
        switch vm.orderingQuestions {
        case .idle, .loading:
            loadingView()
        case .loaded(let questions):
            OrderingPracticeView(questions: questions, onAnswer: handleAnswer)
        case .error(let msg):
            errorView(msg)
        }
    }

    // MARK: - 听力

    @ViewBuilder
    private var listeningContent: some View {
        switch vm.listeningQuestions {
        case .idle, .loading:
            loadingView()
        case .loaded(let questions):
            ListeningPracticeView(questions: questions, onAnswer: handleAnswer)
        case .error(let msg):
            errorView(msg)
        }
    }

    // MARK: - 口语

    @ViewBuilder
    private var speakingContent: some View {
        switch vm.speakingQuestions {
        case .idle, .loading:
            loadingView()
        case .loaded(let questions):
            SpeakingPracticeView(questions: questions, onAnswer: handleAnswer)
        case .error(let msg):
            errorView(msg)
        }
    }

    // MARK: - 场景

    @ViewBuilder
    private var scenarioContent: some View {
        switch vm.scenarioQuestions {
        case .idle, .loading:
            loadingView()
        case .loaded(let questions):
            ScenarioPracticeView(questions: questions, onAnswer: handleAnswer)
        case .error(let msg):
            errorView(msg)
        }
    }
}

#Preview {
    NavigationView {
        PracticeRouterView(questionType: .multipleChoice)
            .environmentObject(UserStateStore())
    }
}
