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
            if showResult {
                PracticeResultView(title: "听力专项", totalCount: questions.count, correctCount: correctCount)
            } else {
                PracticeProgressHeader(current: currentIndex, total: questions.count)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        let question = questions[currentIndex]

                        // 播放按钮（Mock）
                        Button(action: { showTranscript = true }) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading) {
                                    Text("播放听力")
                                        .font(.headline)
                                    Text("点击播放（Mock：显示原文）")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        if showTranscript {
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
}

#Preview {
    NavigationView {
        ListeningPracticeView(questions: MockDataFactory.listeningQuestions())
    }
}
