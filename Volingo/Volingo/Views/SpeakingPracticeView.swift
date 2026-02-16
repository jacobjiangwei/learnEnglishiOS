//
//  SpeakingPracticeView.swift
//  Volingo
//
//  Created by jacob on 2026/2/13.
//

import SwiftUI

/// 口语专项练习（Mock：模拟录音 + 评分）
struct SpeakingPracticeView: View {
    let questions: [SpeakingQuestion]
    var onAnswer: ((String, Bool) -> Void)? = nil
    @State private var currentIndex = 0
    @State private var isRecording = false
    @State private var hasRecorded = false
    @State private var showReference = false
    @State private var showResult = false

    var body: some View {
        VStack(spacing: 0) {
            if questions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "mic.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("暂无口语题目")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if showResult {
                PracticeResultView(title: "口语专项", totalCount: questions.count, correctCount: questions.count)
            } else {
                PracticeProgressHeader(current: currentIndex, total: questions.count)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        let question = questions[currentIndex]

                        // 类型标签
                        Text(question.category.rawValue)
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.15))
                            .foregroundColor(.purple)
                            .clipShape(Capsule())

                        // 提示
                        Text(question.prompt)
                            .font(.title3.bold())

                        // 参考文本（朗读题直接显示，其他题型录音后显示）
                        if question.category == .readAloud {
                            Text(question.referenceText)
                                .font(.body)
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // 录音按钮（Mock）
                        Button(action: {
                            if !hasRecorded {
                                isRecording.toggle()
                                if !isRecording {
                                    hasRecorded = true
                                    showReference = true
                                    onAnswer?(questions[currentIndex].id, true)
                                }
                            }
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(isRecording ? .red : (hasRecorded ? .gray : .blue))
                                Text(recordLabel)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        }
                        .disabled(hasRecorded)

                        // Mock 评分
                        if showReference {
                            // 非朗读题：录音后展示参考答案
                            if question.category != .readAloud {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("参考答案")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                    Text(question.referenceText)
                                        .font(.body)
                                }
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Mock 评分：85/100")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                Text("发音清晰，语调自然。建议注意连读和重音。")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.green.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            NextQuestionButton(isLast: currentIndex >= questions.count - 1) {
                                nextQuestion()
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("口语专项")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var recordLabel: String {
        if isRecording { return "录音中…点击停止" }
        if hasRecorded { return "已完成录音" }
        return "点击开始录音"
    }

    private func nextQuestion() {
        if currentIndex < questions.count - 1 {
            currentIndex += 1
            isRecording = false
            hasRecorded = false
            showReference = false
        } else {
            showResult = true
        }
    }
}

#Preview {
    NavigationView {
        SpeakingPracticeView(questions: [
            SpeakingQuestion(id: "preview-1", prompt: "请朗读以下句子：", referenceText: "The weather is nice today.", category: .readAloud),
        ])
    }
}
