//
//  TextInputPracticeView.swift
//  Volingo
//
//  Created by jacob on 2026/2/13.
//

import SwiftUI

/// 文本输入型练习（翻译 / 句型改写 / 写作）
struct TextInputPracticeView: View {
    let title: String
    let items: [TextInputItem]
    @State private var currentIndex = 0
    @State private var userAnswer = ""
    @State private var submitted = false
    @State private var correctCount = 0
    @State private var showResult = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if showResult {
                PracticeResultView(title: title, totalCount: items.count, correctCount: correctCount)
            } else {
                PracticeProgressHeader(current: currentIndex, total: items.count)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        let item = items[currentIndex]

                        if let instruction = item.instruction {
                            Text(instruction)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }

                        Text(item.sourceText)
                            .font(.title3.bold())
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        TextEditor(text: $userAnswer)
                            .frame(minHeight: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.separator), lineWidth: 1)
                            )
                            .focused($isFocused)
                            .disabled(submitted)

                        if !submitted {
                            Button(action: { submit(item) }) {
                                Text("提交")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(userAnswer.isEmpty ? Color.gray : Color.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(userAnswer.isEmpty)
                        }

                        if submitted {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("参考答案")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.green)
                                Text(item.referenceAnswer)
                                    .font(.body)
                            }
                            .padding()
                            .background(Color.green.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            if !item.keywords.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("关键词")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(item.keywords, id: \.self) { keyword in
                                                let found = userAnswer.lowercased().contains(keyword.lowercased())
                                                Text(keyword)
                                                    .font(.caption)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(found ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                                    .foregroundColor(found ? .green : .red)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                            }

                            ExplanationCard(text: item.explanation)

                            NextQuestionButton(isLast: currentIndex >= items.count - 1) {
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

    private func submit(_ item: TextInputItem) {
        submitted = true
        isFocused = false
        if !item.keywords.isEmpty {
            let matchCount = item.keywords.filter { userAnswer.lowercased().contains($0.lowercased()) }.count
            if Double(matchCount) / Double(item.keywords.count) >= 0.5 { correctCount += 1 }
        } else {
            correctCount += 1
        }
    }

    private func nextQuestion() {
        if currentIndex < items.count - 1 {
            currentIndex += 1
            userAnswer = ""
            submitted = false
        } else {
            showResult = true
        }
    }
}

/// 文本输入题目适配结构
struct TextInputItem {
    let sourceText: String
    let instruction: String?
    let referenceAnswer: String
    let keywords: [String]
    let explanation: String
}

#Preview {
    NavigationView {
        TextInputPracticeView(title: "翻译题", items: MockDataFactory.translationItems())
    }
}
