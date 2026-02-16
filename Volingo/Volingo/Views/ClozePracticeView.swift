//
//  ClozePracticeView.swift
//  Volingo
//
//  Created by jacob on 2026/2/13.
//

import SwiftUI

/// 填空题练习
struct ClozePracticeView: View {
    let questions: [ClozeQuestion]
    @State private var currentIndex = 0
    @State private var userAnswer = ""
    @State private var submitted = false
    @State private var correctCount = 0
    @State private var showResult = false
    @State private var showHint = false
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

                        if let hint = question.hint {
                            if showHint {
                                Text("💡 提示：\(hint)")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .transition(.opacity)
                            } else if !submitted {
                                Button {
                                    withAnimation { showHint = true }
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
    }

    private func checkAnswer(_ q: ClozeQuestion) -> Bool {
        userAnswer.lowercased().trimmingCharacters(in: .whitespaces) == q.answer.lowercased()
    }

    private func submitAnswer(_ q: ClozeQuestion) {
        submitted = true
        isFocused = false
        if checkAnswer(q) { correctCount += 1 }
    }

    private func nextQuestion() {
        if currentIndex < questions.count - 1 {
            currentIndex += 1
            userAnswer = ""
            submitted = false
            showHint = false
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
            ClozeQuestion(id: "preview-1", sentence: "I have ___ finished my homework.", answer: "already", hint: "已经", explanation: "already 用于肯定句。"),
        ])
    }
}
