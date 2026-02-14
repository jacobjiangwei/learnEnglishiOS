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
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if showResult {
                PracticeResultView(title: "填空题", totalCount: questions.count, correctCount: correctCount)
            } else {
                PracticeProgressHeader(current: currentIndex, total: questions.count)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        let question = questions[currentIndex]

                        Text(question.sentence)
                            .font(.title3.bold())

                        if let hint = question.hint {
                            Text("提示：\(hint)")
                                .font(.subheadline)
                                .foregroundColor(.blue)
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
        } else {
            showResult = true
        }
    }
}

#Preview {
    NavigationView {
        ClozePracticeView(questions: MockDataFactory.clozeQuestions())
    }
}
