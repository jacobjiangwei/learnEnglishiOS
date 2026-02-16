//
//  ListeningPracticeView.swift
//  Volingo
//
//  Created by jacob on 2026/2/13.
//

import SwiftUI

/// 听力专项练习（Mock：点击播放显示原文）
struct ListeningPracticeView: View {
    let questions: [ListeningQuestion]
    @State private var currentIndex = 0
    @State private var selectedIndex: Int? = nil
    @State private var showExplanation = false
    @State private var correctCount = 0
    @State private var showResult = false
    @State private var showTranscript = false

    var body: some View {
        VStack(spacing: 0) {
            if questions.isEmpty {
                emptyView
            } else if showResult {
                PracticeResultView(title: "听力专项", totalCount: questions.count, correctCount: correctCount)
            } else {
                PracticeProgressHeader(current: currentIndex, total: questions.count)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        let question = questions[currentIndex]

                        // 播放按钮（Mock）
                        Button(action: { showTranscript = true }) {
                            HStack {
                                Image(systemName: showTranscript ? "speaker.wave.3.fill" : "play.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading) {
                                    Text(showTranscript ? "正在播放…" : "播放听力")
                                        .font(.headline)
                                    Text("Mock 模式：无真实音频")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // 原文仅在提交答案后显示
                        if showExplanation {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("听力原文")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                Text(question.transcript)
                                    .font(.body)
                            }
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Divider()

                        Text(question.stem)
                            .font(.title3.bold())

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
                                if index == question.correctIndex { correctCount += 1 }
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
        .navigationTitle("听力专项")
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
            showTranscript = false
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
        ListeningPracticeView(questions: [
            ListeningQuestion(id: "preview-1", audioURL: nil, transcript: "Good morning, class.", stem: "What time of day is it?", options: ["Morning", "Afternoon", "Evening", "Night"], correctIndex: 0, explanation: "Good morning 表示早上好。"),
        ])
    }
}
