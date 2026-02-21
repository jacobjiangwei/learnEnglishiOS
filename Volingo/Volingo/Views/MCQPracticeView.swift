//
//  MCQPracticeView.swift
//  Volingo
//
//  Created by jacob on 2026/2/13.
//

import SwiftUI

/// 选择题练习（也用于词汇、语法等 MCQ 类题型）
struct MCQPracticeView: View {
    let title: String
    let questions: [MCQQuestion]
    var showTranslationHint: Bool = false  // 小学阶段可显示翻译提示
    var onAnswer: ((String, Bool) -> Void)? = nil
    @State private var currentIndex = 0
    @State private var selectedIndex: Int? = nil
    @State private var showExplanation = false
    @State private var showTranslation = false
    @State private var correctCount = 0
    @State private var showResult = false

    var body: some View {
        VStack(spacing: 0) {
            if questions.isEmpty {
                emptyView
            } else if showResult {
                PracticeResultView(title: title, totalCount: questions.count, correctCount: correctCount)
            } else {
                PracticeProgressHeader(current: currentIndex, total: questions.count)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        let question = questions[currentIndex]

                        Text(question.stem)
                            .font(.title3.bold())
                            .padding(.bottom, 4)

                        // 小学阶段：可点击查看中文翻译
                        if showTranslationHint, let translation = question.translation, !translation.isEmpty {
                            if showTranslation {
                                Text(translation)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.bottom, 4)
                            } else {
                                Button {
                                    withAnimation { showTranslation = true }
                                } label: {
                                    Label("看不懂？点击查看翻译", systemImage: "translate")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                .padding(.bottom, 4)
                            }
                        }

                        ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                            OptionButton(
                                label: optionLabel(index),
                                text: option,
                                isSelected: selectedIndex == index,
                                isCorrect: index == question.correctIndex,
                                showResult: showExplanation
                            ) {
                                guard !showExplanation else { return }
                                selectedIndex = index
                                showExplanation = true
                                let isCorrect = index == question.correctIndex
                                if isCorrect { correctCount += 1 }
                                onAnswer?(question.id, isCorrect)
                            }
                        }

                        if showExplanation {
                            ExplanationCard(text: question.explanation)
                            NextQuestionButton(isLast: currentIndex >= questions.count - 1) {
                                nextQuestion()
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func optionLabel(_ index: Int) -> String {
        let labels = ["A", "B", "C", "D", "E", "F"]
        return index < labels.count ? labels[index] : "\(index + 1)"
    }

    private func nextQuestion() {
        if currentIndex < questions.count - 1 {
            currentIndex += 1
            selectedIndex = nil
            showExplanation = false
            showTranslation = false
        } else {
            showResult = true
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("暂无题目")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationView {
        MCQPracticeView(title: "选择题", questions: [
            MCQQuestion(id: "preview-1", stem: "The past tense of 'go' is ___.", translation: "“go”的过去式是___。", options: ["goed", "went", "gone", "going"], correctIndex: 1, explanation: "go 的过去式是 went。"),
        ], showTranslationHint: true)
    }
}
