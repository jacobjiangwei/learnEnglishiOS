//
//  TodaySessionView.swift
//  海豹英语
//
//  Created by jacob on 2026/2/13.
//

import SwiftUI

/// 今日推荐套餐 - 按题型分段列表，点击每段进入对应练习
struct TodaySessionView: View {
    let package: TodayPackage
    @ObservedObject private var packageStore = TodayPackageStore.shared

    var body: some View {
        List {
            Section {
                ForEach(package.items) { item in
                    let completed = packageStore.isCompleted(questionType: item.type.apiKey)

                    if completed {
                        // 已完成：显示打勾，不可点击
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.type.rawValue)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                Text("已完成")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }

                            Spacer()

                            Text("\(item.count) 题 ✓")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 4)
                    } else {
                        // 未完成：从本地缓存加载题目
                        NavigationLink(destination: CachedPracticeRouterView(questionType: item.type)) {
                            HStack(spacing: 12) {
                                Image(systemName: item.type.icon)
                                    .foregroundColor(item.type.color)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.type.rawValue)
                                        .font(.body)
                                    Text(item.type.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text("\(item.count) 题")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            } header: {
                Text("挑战项目")
            } footer: {
                if packageStore.allCompleted {
                    Text("🏆 今日挑战已全部完成！")
                } else {
                    let progress = packageStore.completionProgress
                    Text("共 \(package.totalQuestions) 题 · 约 \(package.estimatedMinutes) 分钟 · 已完成 \(progress.completed)/\(progress.total)")
                }
            }
        }
        .navigationTitle("每日挑战")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            AnalyticsService.shared.trackScreenView("TodaySessionView")
            AnalyticsService.shared.trackTodayPackageStarted(textbookCode: package.level)
        }
    }
}

// MARK: - 从本地缓存加载题目的练习路由

/// 从 TodayPackageStore 缓存的 JSON 加载题目，不再请求 API
/// 仍然提交答案、记录历史（不是回放模式）
struct CachedPracticeRouterView: View {
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
            case .listening:
                listeningContent
            case .speaking:
                speakingContent
            case .vocabulary:
                mcqContent(title: "词汇专项", state: vm.vocabularyQuestions)
            case .grammar:
                mcqContent(title: "语法专项", state: vm.grammarQuestions)
            case .scenarioDaily, .scenarioCampus, .scenarioWorkplace, .scenarioTravel:
                scenarioContent
            }
        }
        .onAppear {
            loadFromCache()
            AnalyticsService.shared.trackPracticeStarted(questionType: questionType.apiKey, textbookCode: textbookCode)
        }
        .onDisappear {
            vm.saveToHistory()
            TodayPackageStore.shared.markCompleted(questionType: questionType.apiKey)
            Task { await vm.submitResults() }
        }
    }

    private func loadFromCache() {
        if let data = TodayPackageStore.shared.cachedQuestionsJSON(for: questionType.apiKey) {
            vm.loadFromRawJSON(type: questionType, data: data, replay: false)
        } else {
            // 缓存中没有题目 JSON（不应发生），回退为 API 加载
            vm.loadQuestions(type: questionType, textbookCode: textbookCode)
        }
    }

    // MARK: - 各题型视图（与 PracticeRouterView 相同）

    private func loadingView() -> some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("正在加载题目…").foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func mcqContent(title: String, state: LoadingState<[MCQQuestion]>? = nil) -> some View {
        let s = state ?? vm.mcqQuestions
        switch s {
        case .idle, .loading: loadingView()
        case .loaded(let q): MCQPracticeView(title: title, questions: q, showTranslationHint: store.userState.confirmedLevel?.isPrimary ?? false, onAnswer: handleAnswer)
        case .error(let msg): Text(msg).foregroundColor(.secondary)
        }
    }

    @ViewBuilder private var clozeContent: some View {
        switch vm.clozeQuestions {
        case .idle, .loading: loadingView()
        case .loaded(let q): ClozePracticeView(questions: q, onAnswer: handleAnswer)
        case .error(let msg): Text(msg).foregroundColor(.secondary)
        }
    }

    @ViewBuilder private var readingContent: some View {
        switch vm.readingPassage {
        case .idle, .loading: loadingView()
        case .loaded(let p): ReadingPracticeView(passage: p, onAnswer: handleAnswer)
        case .error(let msg): Text(msg).foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func textInputContent(state: LoadingState<[TextInputItem]>, title: String) -> some View {
        switch state {
        case .idle, .loading: loadingView()
        case .loaded(let items): TextInputPracticeView(title: title, items: items, showTranslationHint: store.userState.confirmedLevel?.isPrimary ?? false, onAnswer: handleAnswer)
        case .error(let msg): Text(msg).foregroundColor(.secondary)
        }
    }

    @ViewBuilder private var errorCorrectionContent: some View {
        switch vm.errorCorrectionQuestions {
        case .idle, .loading: loadingView()
        case .loaded(let q): ErrorCorrectionPracticeView(questions: q, onAnswer: handleAnswer)
        case .error(let msg): Text(msg).foregroundColor(.secondary)
        }
    }

    @ViewBuilder private var orderingContent: some View {
        switch vm.orderingQuestions {
        case .idle, .loading: loadingView()
        case .loaded(let q): OrderingPracticeView(questions: q, onAnswer: handleAnswer)
        case .error(let msg): Text(msg).foregroundColor(.secondary)
        }
    }

    @ViewBuilder private var listeningContent: some View {
        switch vm.listeningQuestions {
        case .idle, .loading: loadingView()
        case .loaded(let q): ListeningPracticeView(questions: q, onAnswer: handleAnswer)
        case .error(let msg): Text(msg).foregroundColor(.secondary)
        }
    }

    @ViewBuilder private var speakingContent: some View {
        switch vm.speakingQuestions {
        case .idle, .loading: loadingView()
        case .loaded(let q): SpeakingPracticeView(questions: q, onAnswer: handleAnswer)
        case .error(let msg): Text(msg).foregroundColor(.secondary)
        }
    }

    @ViewBuilder private var scenarioContent: some View {
        switch vm.scenarioQuestions {
        case .idle, .loading: loadingView()
        case .loaded(let q): ScenarioPracticeView(questions: q, onAnswer: handleAnswer)
        case .error(let msg): Text(msg).foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationView {
        TodaySessionView(package: TodayPackage(
            date: Date(),
            level: "juniorPEP-7a",
            items: [
                PackageItem(type: .multipleChoice, count: 5, weight: 0.4),
                PackageItem(type: .cloze, count: 3, weight: 0.3),
            ],
            estimatedMinutes: 10
        ))
        .environmentObject(UserStateStore())
    }
}
