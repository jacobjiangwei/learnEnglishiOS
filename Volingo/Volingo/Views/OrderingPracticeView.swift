//
//  OrderingPracticeView.swift
//  Volingo
//
//  Created by jacob on 2026/2/13.
//

import SwiftUI

/// 排序题练习
struct OrderingPracticeView: View {
    let questions: [OrderingQuestion]
    @State private var currentIndex = 0
    @State private var selectedIndices: [Int] = []
    @State private var submitted = false
    @State private var correctCount = 0
    @State private var showResult = false

    var body: some View {
        VStack(spacing: 0) {
            if showResult {
                PracticeResultView(title: "排序题", totalCount: questions.count, correctCount: correctCount)
            } else {
                PracticeProgressHeader(current: currentIndex, total: questions.count)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        let question = questions[currentIndex]

                        Text("将以下部分排列成正确的句子：")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        // 用户已选排列
                        if !selectedIndices.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("你的排列：")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(selectedIndices.map { question.shuffledParts[$0] }.joined(separator: " "))
                                    .font(.title3)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        // 可选单词
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                            ForEach(Array(question.shuffledParts.enumerated()), id: \.offset) { index, part in
                                let isSelected = selectedIndices.contains(index)
                                Button(action: {
                                    guard !submitted else { return }
                                    if isSelected {
                                        selectedIndices.removeAll { $0 == index }
                                    } else {
                                        selectedIndices.append(index)
                                    }
                                }) {
                                    Text(part)
                                        .font(.body)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(isSelected ? Color.blue.opacity(0.15) : Color(.secondarySystemGroupedBackground))
                                        .foregroundColor(isSelected ? .blue : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                                        )
                                }
                                .disabled(submitted)
                            }
                        }

                        // 提交
                        if !submitted && selectedIndices.count == question.shuffledParts.count {
                            Button(action: { submit(question) }) {
                                Text("提交")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        if submitted {
                            let isCorrect = selectedIndices == question.correctOrder

                            HStack {
                                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(isCorrect ? .green : .red)
                                Text(isCorrect ? "正确！" : "正确顺序：")
                                    .font(.headline)
                                    .foregroundColor(isCorrect ? .green : .red)
                            }

                            if !isCorrect {
                                Text(question.correctOrder.map { question.shuffledParts[$0] }.joined(separator: " "))
                                    .font(.body)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.green.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
        .navigationTitle("排序题")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit(_ question: OrderingQuestion) {
        submitted = true
        if selectedIndices == question.correctOrder { correctCount += 1 }
    }

    private func nextQuestion() {
        if currentIndex < questions.count - 1 {
            currentIndex += 1
            selectedIndices = []
            submitted = false
        } else {
            showResult = true
        }
    }
}

#Preview {
    NavigationView {
        OrderingPracticeView(questions: MockDataFactory.orderingQuestions())
    }
}
