//
//  PracticeResultView.swift
//  Volingo
//
//  Created by jacob on 2026/2/13.
//

import SwiftUI

struct PracticeResultView: View {
    let title: String
    let totalCount: Int
    let correctCount: Int
    @Environment(\.dismiss) private var dismiss

    private var wrongCount: Int { totalCount - correctCount }
    private var scorePercent: Int {
        totalCount > 0 ? Int(Double(correctCount) / Double(totalCount) * 100) : 0
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // 分数环
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 150, height: 150)
                Circle()
                    .trim(from: 0, to: Double(scorePercent) / 100.0)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 4) {
                    Text("\(scorePercent)%")
                        .font(.largeTitle.bold())
                    Text(scoreLabel)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // 统计
            HStack(spacing: 40) {
                ResultStatItem(value: "\(totalCount)", label: "总题数", color: .blue)
                ResultStatItem(value: "\(correctCount)", label: "正确", color: .green)
                ResultStatItem(value: "\(wrongCount)", label: "错误", color: .red)
            }

            Spacer()

            // 返回
            Button(action: { dismiss() }) {
                Text("返回")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .navigationTitle("练习结果")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var scoreColor: Color {
        switch scorePercent {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }

    private var scoreLabel: String {
        switch scorePercent {
        case 90...100: return "优秀！"
        case 80..<90: return "很好！"
        case 60..<80: return "继续加油"
        default: return "需要多练习"
        }
    }
}

private struct ResultStatItem: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationView {
        PracticeResultView(title: "选择题", totalCount: 10, correctCount: 7)
    }
}
