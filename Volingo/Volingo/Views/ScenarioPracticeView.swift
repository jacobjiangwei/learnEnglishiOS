//
//  ScenarioPracticeView.swift
//  Volingo
//
//  Created by jacob on 2026/2/13.
//

import SwiftUI

/// 场景对话练习
struct ScenarioPracticeView: View {
    let questions: [ScenarioQuestion]
    var onAnswer: ((String, Bool) -> Void)? = nil
    @State private var currentIndex = 0
    @State private var selectedIndex: Int? = nil
    @State private var showExplanation = false
    @State private var correctCount = 0
    @State private var showResult = false

    var body: some View {
        VStack(spacing: 0) {
            if showResult {
                PracticeResultView(title: "场景训练", totalCount: questions.count, correctCount: correctCount)
            } else if currentIndex < questions.count {
                PracticeProgressHeader(current: currentIndex, total: questions.count)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        let question = questions[currentIndex]

                        // 场景标题与说明
                        VStack(alignment: .leading, spacing: 4) {
                            Text(question.scenarioTitle)
                                .font(.headline)
                            Text(question.context)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // 对话流
                        ForEach(question.dialogueLines) { line in
                            HStack(alignment: .top, spacing: 8) {
                                Text(line.speaker)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(line.speaker == "You" ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15))
                                    .clipShape(Capsule())
                                Text(line.text)
                                    .font(.body)
                            }
                        }

                        Divider()

                        Text(question.userPrompt)
                            .font(.title3.bold())

                        // 选项
                        if let options = question.options, let correctIdx = question.correctIndex {
                            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                                OptionButton(
                                    label: optionLabel(index),
                                    text: option,
                                    isSelected: selectedIndex == index,
                                    isCorrect: index == correctIdx,
                                    showResult: showExplanation
                                ) {
                                    guard !showExplanation else { return }
                                    selectedIndex = index
                                    showExplanation = true
                                    let isCorrect = index == correctIdx
                                    if isCorrect { correctCount += 1 }
                                    onAnswer?(question.id, isCorrect)
                                }
                            }
                        }

                        if showExplanation {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("参考回答")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.green)
                                Text(question.referenceResponse)
                                    .font(.body)
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
        .navigationTitle("场景训练")
        .navigationBarTitleDisplayMode(.inline)
        .reportableQuestion(id: questions.isEmpty || showResult ? nil : questions[currentIndex].id)
    }

    private func optionLabel(_ index: Int) -> String {
        let labels = ["A", "B", "C", "D"]
        return index < labels.count ? labels[index] : "\(index + 1)"
    }

    private func nextQuestion() {
        if currentIndex < questions.count - 1 {
            currentIndex += 1
            selectedIndex = nil
            showExplanation = false
        } else {
            showResult = true
        }
    }
}

#Preview {
    NavigationView {
        ScenarioPracticeView(questions: [
            ScenarioQuestion(
                id: "preview-1", type: .scenarioDaily,
                scenarioTitle: "在咖啡店", context: "你走进一家咖啡店。",
                dialogueLines: [DialogueLine(id: "dl-1", speaker: "Staff", text: "What can I get for you?")],
                userPrompt: "你想要一杯拿铁",
                options: ["A latte, please.", "Give me food.", "Where is the bus?", "I don't know."],
                correctIndex: 0, referenceResponse: "A latte, please."),
        ])
    }
}
