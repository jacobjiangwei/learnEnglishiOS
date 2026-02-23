//
//  ClozePracticeView.swift
//  海豹英语
//
//  Created by jacob on 2026/2/13.
//

import SwiftUI

/// 填空题练习
struct ClozePracticeView: View {
    let questions: [ClozeQuestion]
    var onAnswer: ((String, Bool) -> Void)? = nil
    @State private var currentIndex = 0
    @State private var userAnswer = ""
    @State private var submitted = false
    @State private var correctCount = 0
    @State private var showResult = false
    @State private var showHints = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if questions.isEmpty {
                emptyView
            } else if showResult {
                PracticeResultView(title: "填空题", totalCount: questions.count, correctCount: correctCount)
            } else {
                PracticeProgressHeader(current: currentIndex, total: questions.count)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        let question = questions[currentIndex]

                        Text(question.sentence)
                            .font(.title3.bold())

                        // Hints: show all words as reference when requested
                        if !question.hints.isEmpty {
                            if showHints {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("💡 可选词汇：")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                    FlowLayout(spacing: 8) {
                                        ForEach(question.hints, id: \.self) { word in
                                            Text(word)
                                                .font(.body.bold())
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.blue.opacity(0.1))
                                                .foregroundColor(.blue)
                                                .cornerRadius(16)
                                        }
                                    }
                                }
                                .transition(.opacity)
                            } else if !submitted {
                                Button {
                                    withAnimation { showHints = true }
                                } label: {
                                    Label("显示提示", systemImage: "lightbulb")
                                        .font(.subheadline)
                                }
                                .buttonStyle(.bordered)
                                .tint(.blue)
                            }
                        }

                        HStack {
                            TextField("输入答案…", text: $userAnswer)
                                .textFieldStyle(.roundedBorder)
                                .focused($isFocused)
                                .disabled(submitted)

                            if !submitted {
                                Button("提交") { submitAnswer(question) }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(userAnswer.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }

                        if submitted {
                            let isCorrect = checkAnswer(question)

                            HStack {
                                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(isCorrect ? .green : .red)
                                Text(isCorrect ? "正确！" : "正确答案：\(question.answer)")
                                    .font(.headline)
                                    .foregroundColor(isCorrect ? .green : .red)
                            }

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
        .navigationTitle("填空题")
        .navigationBarTitleDisplayMode(.inline)
        .reportableQuestion(id: questions.isEmpty || showResult ? nil : questions[currentIndex].id)
    }

    private func checkAnswer(_ q: ClozeQuestion) -> Bool {
        userAnswer.lowercased().trimmingCharacters(in: .whitespaces) == q.answer.lowercased()
    }

    private func submitAnswer(_ q: ClozeQuestion) {
        submitted = true
        isFocused = false
        let isCorrect = checkAnswer(q)
        if isCorrect { correctCount += 1 }
        onAnswer?(q.id, isCorrect)
    }

    private func nextQuestion() {
        if currentIndex < questions.count - 1 {
            currentIndex += 1
            userAnswer = ""
            submitted = false
            showHints = false
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
        ClozePracticeView(questions: [
            ClozeQuestion(id: "preview-1", sentence: "I have ___ finished my homework.", answer: "already", hints: ["already", "yet", "still", "never"], explanation: "already 用于肯定句。"),
        ])
    }
}
