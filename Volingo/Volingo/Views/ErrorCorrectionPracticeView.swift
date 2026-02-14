//
//  ErrorCorrectionPracticeView.swift
//  Volingo
//
//  Created by jacob on 2026/2/13.
//

import SwiftUI

/// 纠错题练习
struct ErrorCorrectionPracticeView: View {
    let questions: [ErrorCorrectionQuestion]
    @State private var currentIndex = 0
    @State private var selectedWord: String? = nil
    @State private var showExplanation = false
    @State private var correctCount = 0
    @State private var showResult = false

    var body: some View {
        VStack(spacing: 0) {
            if showResult {
                PracticeResultView(title: "纠错题", totalCount: questions.count, correctCount: correctCount)
            } else {
                PracticeProgressHeader(current: currentIndex, total: questions.count)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        let question = questions[currentIndex]

                        Text("点击句子中有错误的单词：")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        // 完整句子
                        Text(question.sentence)
                            .font(.title3.bold())
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        // 单词按钮网格
                        let words = question.sentence.components(separatedBy: " ")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                                Button(action: {
                                    guard !showExplanation else { return }
                                    // 清理标点后比较
                                    let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
                                    selectedWord = cleanWord
                                    showExplanation = true
                                    if cleanWord == question.errorRange { correctCount += 1 }
                                }) {
                                    Text(word)
                                        .font(.body)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(wordBackground(word, question: question))
                                        .foregroundColor(wordForeground(word, question: question))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(wordBorder(word, question: question), lineWidth: 2)
                                        )
                                }
                                .disabled(showExplanation)
                            }
                        }

                        if showExplanation {
                            HStack(spacing: 12) {
                                Text(question.errorRange)
                                    .strikethrough()
                                    .foregroundColor(.red)
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.secondary)
                                Text(question.correction)
                                    .foregroundColor(.green)
                                    .bold()
                            }
                            .font(.title3)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

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
        .navigationTitle("纠错题")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func wordBackground(_ word: String, question: ErrorCorrectionQuestion) -> Color {
        let clean = word.trimmingCharacters(in: .punctuationCharacters)
        guard showExplanation else { return Color(.secondarySystemGroupedBackground) }
        if clean == question.errorRange { return Color.red.opacity(0.15) }
        if clean == selectedWord && clean != question.errorRange { return Color.orange.opacity(0.15) }
        return Color(.secondarySystemGroupedBackground)
    }

    private func wordForeground(_ word: String, question: ErrorCorrectionQuestion) -> Color {
        let clean = word.trimmingCharacters(in: .punctuationCharacters)
        guard showExplanation else { return .primary }
        if clean == question.errorRange { return .red }
        return .primary
    }

    private func wordBorder(_ word: String, question: ErrorCorrectionQuestion) -> Color {
        let clean = word.trimmingCharacters(in: .punctuationCharacters)
        guard showExplanation else { return .clear }
        if clean == question.errorRange { return .red }
        if clean == selectedWord { return .orange }
        return .clear
    }

    private func nextQuestion() {
        if currentIndex < questions.count - 1 {
            currentIndex += 1
            selectedWord = nil
            showExplanation = false
        } else {
            showResult = true
        }
    }
}

#Preview {
    NavigationView {
        ErrorCorrectionPracticeView(questions: MockDataFactory.errorCorrectionQuestions())
    }
}
