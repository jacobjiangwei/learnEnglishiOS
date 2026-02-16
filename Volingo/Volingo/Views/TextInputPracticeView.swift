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
    @State private var selfEvalDone = false
    @State private var correctCount = 0
    @State private var showResult = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if items.isEmpty {
                emptyView
            } else if showResult {
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

                            // 自评模式：用户自己判断对错
                            if item.isSelfEvaluated && !selfEvalDone {
                                VStack(spacing: 8) {
                                    Text("对照参考答案，你觉得自己答对了吗？")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    HStack(spacing: 16) {
                                        Button {
                                            correctCount += 1
                                            selfEvalDone = true
                                        } label: {
                                            Label("答对了", systemImage: "checkmark.circle.fill")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(Color.green)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                        Button {
                                            selfEvalDone = true
                                        } label: {
                                            Label("没答对", systemImage: "xmark.circle.fill")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(Color.red)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                    }
                                }
                                .padding(.top, 8)
                            }

                            // 非自评模式或自评已完成：显示解析和下一题
                            if !item.isSelfEvaluated || selfEvalDone {
                                ExplanationCard(text: item.explanation)

                                NextQuestionButton(isLast: currentIndex >= items.count - 1) {
                                    nextQuestion()
                                }
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
        // 自评模式由用户按钮判定，这里不自动计分
        if !item.isSelfEvaluated {
            if !item.keywords.isEmpty {
                let matchCount = item.keywords.filter { userAnswer.lowercased().contains($0.lowercased()) }.count
                if Double(matchCount) / Double(item.keywords.count) >= 0.5 { correctCount += 1 }
            } else {
                correctCount += 1
            }
        }
    }

    private func nextQuestion() {
        if currentIndex < items.count - 1 {
            currentIndex += 1
            userAnswer = ""
            submitted = false
            selfEvalDone = false
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

/// 文本输入题目适配结构
struct TextInputItem: Identifiable {
    let id: String
    let sourceText: String
    let instruction: String?
    let referenceAnswer: String
    let keywords: [String]
    let explanation: String
    /// 是否由用户自评判定对错（翻译/写作等开放题）
    var isSelfEvaluated: Bool = false
}

#Preview {
    NavigationView {
        TextInputPracticeView(title: "翻译题", items: [
            TextInputItem(id: "preview-1", sourceText: "我每天早上七点起床。", instruction: "请翻译成英文", referenceAnswer: "I get up at seven every morning.", keywords: ["get up", "seven"], explanation: "get up 表示起床。", isSelfEvaluated: true),
        ])
    }
}
