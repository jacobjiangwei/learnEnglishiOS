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
    var showTranslationHint: Bool = false
    var onAnswer: ((String, Bool) -> Void)? = nil
    @State private var currentIndex = 0
    @State private var userAnswer = ""
    @State private var submitted = false
    @State private var selfEvalDone = false
    @State private var autoJudgedCorrect = false
    @State private var correctCount = 0
    @State private var showResult = false
    @State private var showSourceTranslation = false
    @State private var showInstructionTranslation = false
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
                            VStack(alignment: .leading, spacing: 4) {
                                Text(instruction)
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                if showTranslationHint, let t = item.instructionTranslation, !t.isEmpty {
                                    if showInstructionTranslation {
                                        Text(t)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .transition(.opacity)
                                    } else {
                                        Button { withAnimation { showInstructionTranslation = true } } label: {
                                            Label("看不懂？点击查看翻译", systemImage: "text.bubble")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.sourceText)
                                .font(.title3.bold())
                            if showTranslationHint, let t = item.sourceTranslation, !t.isEmpty {
                                if showSourceTranslation {
                                    Text(t)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .transition(.opacity)
                                } else {
                                    Button { withAnimation { showSourceTranslation = true } } label: {
                                        Label("查看翻译", systemImage: "character.book.closed")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
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

                            // 自评模式
                            if item.isSelfEvaluated && !selfEvalDone {
                                // 需要用户自评
                                VStack(spacing: 8) {
                                    Text("对照参考答案，你觉得自己答对了吗？")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    HStack(spacing: 16) {
                                        Button {
                                            correctCount += 1
                                            selfEvalDone = true
                                            onAnswer?(items[currentIndex].id, true)
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
                                            onAnswer?(items[currentIndex].id, false)
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

                            // 自动判对提示
                            if item.isSelfEvaluated && autoJudgedCorrect {
                                Label("回答正确！", systemImage: "checkmark.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                    .padding(.top, 4)
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

        if item.isSelfEvaluated {
            // 模糊匹配：如果用户答案与参考答案高度相似，自动判对，跳过自评
            let similarity = stringSimilarity(userAnswer, item.referenceAnswer)
            if similarity >= 0.75 {
                autoJudgedCorrect = true
                selfEvalDone = true
                correctCount += 1
                onAnswer?(item.id, true)
            }
            // 否则走自评流程
        } else {
            var isCorrect = true
            if !item.keywords.isEmpty {
                let matchCount = item.keywords.filter { userAnswer.lowercased().contains($0.lowercased()) }.count
                isCorrect = Double(matchCount) / Double(item.keywords.count) >= 0.5
            }
            if isCorrect { correctCount += 1 }
            onAnswer?(item.id, isCorrect)
        }
    }

    /// 归一化文本：去标点、统一小写、按空格拆词
    private func normalizeWords(_ s: String) -> [String] {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
         .lowercased()
         .replacingOccurrences(of: "\u{2019}", with: "'")  // 智能右引号 → 直引号
         .replacingOccurrences(of: "\u{2018}", with: "'")  // 智能左引号 → 直引号
         .filter { $0.isLetter || $0.isNumber || $0.isWhitespace || $0 == "'" }
         .components(separatedBy: .whitespaces)
         .filter { !$0.isEmpty }
    }

    /// 逐词精确匹配（忽略标点和大小写，拼写必须完全正确）
    private func stringSimilarity(_ a: String, _ b: String) -> Double {
        let w1 = normalizeWords(a)
        let w2 = normalizeWords(b)
        guard !w1.isEmpty || !w2.isEmpty else { return 1.0 }
        return w1 == w2 ? 1.0 : 0.0
    }

    private func nextQuestion() {
        if currentIndex < items.count - 1 {
            currentIndex += 1
            userAnswer = ""
            submitted = false
            selfEvalDone = false
            autoJudgedCorrect = false
            showSourceTranslation = false
            showInstructionTranslation = false
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
    let sourceTranslation: String?
    let instruction: String?
    let instructionTranslation: String?
    let referenceAnswer: String
    let keywords: [String]
    let explanation: String
    /// 是否由用户自评判定对错（翻译/写作等开放题）
    var isSelfEvaluated: Bool = false
}

#Preview {
    NavigationView {
        TextInputPracticeView(title: "翻译题", items: [
            TextInputItem(id: "preview-1", sourceText: "我每天早上七点起床。", sourceTranslation: nil, instruction: "请翻译成英文", instructionTranslation: nil, referenceAnswer: "I get up at seven every morning.", keywords: ["get up", "seven"], explanation: "get up 表示起床。", isSelfEvaluated: true),
        ], showTranslationHint: true)
    }
}
