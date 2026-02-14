//
//  PracticeComponents.swift
//  Volingo
//
//  Created by jacob on 2026/2/13.
//

import SwiftUI

// MARK: - 选项按钮（MCQ 通用）

struct OptionButton: View {
    let label: String
    let text: String
    let isSelected: Bool
    let isCorrect: Bool
    let showResult: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.headline)
                    .foregroundColor(labelFgColor)
                    .frame(width: 32, height: 32)
                    .background(labelBgColor)
                    .clipShape(Circle())

                Text(text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()

                if showResult && isSelected {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isCorrect ? .green : .red)
                }
                if showResult && isCorrect && !isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green.opacity(0.6))
                }
            }
            .padding()
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: (showResult && (isSelected || isCorrect)) ? 2 : 1)
            )
        }
        .disabled(showResult)
    }

    private var labelFgColor: Color {
        if showResult && isCorrect { return .white }
        if showResult && isSelected { return .white }
        return .blue
    }

    private var labelBgColor: Color {
        if showResult && isCorrect { return .green }
        if showResult && isSelected && !isCorrect { return .red }
        return Color.blue.opacity(0.1)
    }

    private var bgColor: Color {
        if showResult && isCorrect { return Color.green.opacity(0.08) }
        if showResult && isSelected && !isCorrect { return Color.red.opacity(0.08) }
        return Color(.secondarySystemGroupedBackground)
    }

    private var borderColor: Color {
        if showResult && isCorrect { return .green }
        if showResult && isSelected && !isCorrect { return .red }
        return Color(.separator)
    }
}

// MARK: - 解析卡

struct ExplanationCard: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 下一题按钮

struct NextQuestionButton: View {
    let isLast: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(isLast ? "查看结果" : "下一题")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - 进度条

struct PracticeProgressHeader: View {
    let current: Int
    let total: Int

    var body: some View {
        VStack(spacing: 4) {
            ProgressView(value: Double(current), total: Double(total))
                .tint(.blue)
            HStack {
                Text("第 \(current + 1) / \(total) 题")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
