//
//  ReadingPracticeView.swift
//  Volingo
//
//  Created by jacob on 2026/2/13.
//

import SwiftUI

/// 阅读理解练习
struct ReadingPracticeView: View {
    let passage: ReadingPassage
    @State private var currentIndex = 0
    @State private var selectedIndex: Int? = nil
    @State private var showExplanation = false
    @State private var correctCount = 0
    @State private var showResult = false
    @State private var showPassage = true

    var body: some View {
        VStack(spacing: 0) {
            if passage.questions.isEmpty {
                emptyView
            } else if showResult {
                PracticeResultView(title: "阅读理解", totalCount: passage.questions.count, correctCount: correctCount)
            } else {
                PracticeProgressHeader(current: currentIndex, total: passage.questions.count)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 文章折叠
                        Button(action: { withAnimation { showPassage.toggle() } }) {
                            HStack {
                                Text(passage.title)
                                    .font(.headline)
                                Spacer()
                                Image(systemName: showPassage ? "chevron.up" : "chevron.down")
                            }
                            .foregroundColor(.primary)
                        }

                        if showPassage {
                            Text(passage.content)
                                .font(.body)
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Divider()

                        let question = passage.questions[currentIndex]

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
                            NextQuestionButton(isLast: currentIndex >= passage.questions.count - 1) {
                                nextQuestion()
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("阅读理解")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func optionLabel(_ index: Int) -> String {
        let labels = ["A", "B", "C", "D", "E", "F"]
        return index < labels.count ? labels[index] : "\(index + 1)"
    }

    private func nextQuestion() {
        if currentIndex < passage.questions.count - 1 {
            currentIndex += 1
            selectedIndex = nil
            showExplanation = false
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
        ReadingPracticeView(passage: ReadingPassage(
            id: "preview-1",
            title: "The History of Tea",
            content: "Tea is one of the most popular drinks in the world.",
            questions: [
                ReadingQuestion(id: "preview-q1", stem: "What is tea?", options: ["A food", "A drink", "A place", "A person"], correctIndex: 1, explanation: "Tea is a drink."),
            ]
        ))
    }
}
