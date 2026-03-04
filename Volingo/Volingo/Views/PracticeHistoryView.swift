//
//  PracticeHistoryView.swift
//  海豹英语
//
//  历史记录列表 + 回放路由
//

import SwiftUI

// MARK: - 历史记录列表

struct PracticeHistoryView: View {
    @ObservedObject private var store = PracticeHistoryStore.shared
    @State private var showClearConfirm = false

    var body: some View {
        Group {
            if store.sessions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("暂无练习记录")
                        .foregroundColor(.secondary)
                    Text("完成练习后，题目会自动保存在这里")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.sessions) { session in
                        NavigationLink(destination: HistoryReplayRouterView(session: session)) {
                            HistorySessionRow(session: session)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            store.delete(id: store.sessions[index].id)
                        }
                    }
                }
            }
        }
        .navigationTitle("历史记录")
        .toolbar {
            if !store.sessions.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .alert("清空所有历史记录？", isPresented: $showClearConfirm) {
            Button("清空", role: .destructive) {
                store.clearAll()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不可撤销")
        }
    }
}

// MARK: - 单行展示

private struct HistorySessionRow: View {
    let session: HistorySession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.displayName)
                    .font(.headline)
                Spacer()
                if session.correctCount + session.wrongCount > 0 {
                    Text("\(session.accuracy)%")
                        .font(.subheadline.bold())
                        .foregroundColor(accuracyColor)
                }
                Text("\(session.questionCount) 题")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            HStack {
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if session.correctCount + session.wrongCount > 0 {
                    Spacer()
                    HStack(spacing: 8) {
                        Label("\(session.correctCount)", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Label("\(session.wrongCount)", systemImage: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var accuracyColor: Color {
        switch session.accuracy {
        case 90...100: return .green
        case 60..<90: return .orange
        default: return .red
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: session.timestamp)
    }
}

// MARK: - 回放路由

struct HistoryReplayRouterView: View {
    let session: HistorySession
    @EnvironmentObject private var store: UserStateStore
    @StateObject private var vm = PracticeViewModel()

    private var resolvedType: QuestionType {
        QuestionType.from(apiKey: session.questionType) ?? .multipleChoice
    }

    var body: some View {
        Group {
            switch resolvedType {
            case .multipleChoice, .quickSprint, .errorReview, .randomChallenge, .timedDrill:
                replayMCQ(title: resolvedType.rawValue)
            case .cloze:
                replayCloze
            case .reading:
                replayReading
            case .translation:
                replayTextInput(state: vm.translationItems, title: "翻译题")
            case .rewriting:
                replayTextInput(state: vm.rewritingItems, title: "句型改写")
            case .errorCorrection:
                replayErrorCorrection
            case .sentenceOrdering:
                replayOrdering
            case .listening:
                replayListening
            case .speaking:
                replaySpeaking
            case .vocabulary:
                replayMCQ(title: "词汇专项", state: vm.vocabularyQuestions)
            case .grammar:
                replayMCQ(title: "语法专项", state: vm.grammarQuestions)
            case .scenarioDaily, .scenarioCampus, .scenarioWorkplace, .scenarioTravel:
                replayScenario
            }
        }
        .navigationTitle("回放 · \(session.displayName)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.loadFromRawJSON(type: resolvedType, data: session.rawJSON)
        }
    }

    // MARK: - 各题型回放视图（onAnswer 传 nil，不记录不提交）

    @ViewBuilder
    private func replayMCQ(title: String, state: LoadingState<[MCQQuestion]>? = nil) -> some View {
        let s = state ?? vm.mcqQuestions
        switch s {
        case .idle, .loading: ProgressView()
        case .loaded(let q): MCQPracticeView(title: title, questions: q, showTranslationHint: store.userState.gradeEnum?.isPrimary ?? false, onAnswer: nil)
        case .error(let msg): Text(msg).foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var replayCloze: some View {
        switch vm.clozeQuestions {
        case .idle, .loading: ProgressView()
        case .loaded(let q): ClozePracticeView(questions: q, onAnswer: nil)
        case .error(let msg): Text(msg).foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var replayReading: some View {
        switch vm.readingPassage {
        case .idle, .loading: ProgressView()
        case .loaded(let p): ReadingPracticeView(passage: p, onAnswer: nil)
        case .error(let msg): Text(msg).foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func replayTextInput(state: LoadingState<[TextInputItem]>, title: String) -> some View {
        switch state {
        case .idle, .loading: ProgressView()
        case .loaded(let items): TextInputPracticeView(title: title, items: items, showTranslationHint: store.userState.gradeEnum?.isPrimary ?? false, onAnswer: nil)
        case .error(let msg): Text(msg).foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var replayErrorCorrection: some View {
        switch vm.errorCorrectionQuestions {
        case .idle, .loading: ProgressView()
        case .loaded(let q): ErrorCorrectionPracticeView(questions: q, onAnswer: nil)
        case .error(let msg): Text(msg).foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var replayOrdering: some View {
        switch vm.orderingQuestions {
        case .idle, .loading: ProgressView()
        case .loaded(let q): OrderingPracticeView(questions: q, onAnswer: nil)
        case .error(let msg): Text(msg).foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var replayListening: some View {
        switch vm.listeningQuestions {
        case .idle, .loading: ProgressView()
        case .loaded(let q): ListeningPracticeView(questions: q, onAnswer: nil)
        case .error(let msg): Text(msg).foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var replaySpeaking: some View {
        switch vm.speakingQuestions {
        case .idle, .loading: ProgressView()
        case .loaded(let q): SpeakingPracticeView(questions: q, onAnswer: nil)
        case .error(let msg): Text(msg).foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var replayScenario: some View {
        switch vm.scenarioQuestions {
        case .idle, .loading: ProgressView()
        case .loaded(let q): ScenarioPracticeView(questions: q, onAnswer: nil)
        case .error(let msg): Text(msg).foregroundColor(.secondary)
        }
    }
}
