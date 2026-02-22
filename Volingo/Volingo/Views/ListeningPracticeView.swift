//
//  ListeningPracticeView.swift
//  Volingo
//
//  Created by jacob on 2026/2/13.
//

import SwiftUI

/// 听力专项练习（使用系统 TTS 朗读）
struct ListeningPracticeView: View {
    let questions: [ListeningQuestion]
    var onAnswer: ((String, Bool) -> Void)? = nil
    @State private var currentIndex = 0
    @State private var selectedIndex: Int? = nil
    @State private var showExplanation = false
    @State private var correctCount = 0
    @State private var showResult = false
    @StateObject private var audio = AudioService.shared

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

                        // 播放按钮 — 系统 TTS
                        HStack(spacing: 12) {
                            Button(action: { audio.playWordPronunciation(question.transcript) }) {
                                HStack {
                                    Image(systemName: audio.isPlaying ? "speaker.wave.3.fill" : "play.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                    Text(audio.isPlaying ? "播放中…" : "播放")
                                        .font(.subheadline.bold())
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(audio.isPlaying)

                            Button(action: { audio.playWordPronunciation(question.transcript, rate: 0.2) }) {
                                HStack {
                                    Image(systemName: "tortoise.fill")
                                        .font(.title2)
                                        .foregroundColor(.orange)
                                    Text("慢速")
                                        .font(.subheadline.bold())
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.orange.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(audio.isPlaying)
                        }

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
                                let isCorrect = index == question.correctIndex
                                if isCorrect { correctCount += 1 }
                                onAnswer?(question.id, isCorrect)
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
        .reportableQuestion(id: questions.isEmpty || showResult ? nil : questions[currentIndex].id)
        .onAppear { autoPlayAfterDelay() }
    }

    private func optionLabel(_ index: Int) -> String {
        let labels = ["A", "B", "C", "D", "E", "F"]
        return index < labels.count ? labels[index] : "\(index + 1)"
    }

    private func nextQuestion() {
        audio.stopPlaying()
        if currentIndex < questions.count - 1 {
            currentIndex += 1
            selectedIndex = nil
            showExplanation = false
            autoPlayAfterDelay()
        } else {
            showResult = true
        }
    }

    /// 延迟 0.5 秒后自动播放当前题目音频
    private func autoPlayAfterDelay() {
        guard !questions.isEmpty, currentIndex < questions.count else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard !showResult, !audio.isPlaying else { return }
            audio.playWordPronunciation(questions[currentIndex].transcript)
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
