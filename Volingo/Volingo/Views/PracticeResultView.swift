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

    // 动画状态
    @State private var animatedProgress: Double = 0
    @State private var displayedPercent: Int = 0
    @State private var showLabel = false
    @State private var showStats = false
    @State private var showConfetti = false

    private var wrongCount: Int { totalCount - correctCount }
    private var scorePercent: Int {
        totalCount > 0 ? Int(Double(correctCount) / Double(totalCount) * 100) : 0
    }

    var body: some View {
        ZStack {
            VStack(spacing: 32) {
                Spacer()

                // 分数环 — 动画填充
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 150, height: 150)
                    Circle()
                        .trim(from: 0, to: animatedProgress)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 4) {
                        Text("\(displayedPercent)%")
                            .font(.largeTitle.bold())
                            .foregroundColor(scoreColor)
                            .contentTransition(.numericText())
                        if showLabel {
                            Text(scoreLabel)
                                .font(.subheadline.bold())
                                .foregroundColor(scoreColor.opacity(0.8))
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }

                // 统计 — 延时淡入
                if showStats {
                    HStack(spacing: 40) {
                        ResultStatItem(value: "\(totalCount)", label: "总题数", color: .blue)
                        ResultStatItem(value: "\(correctCount)", label: "正确", color: .green)
                        ResultStatItem(value: "\(wrongCount)", label: "错误", color: .red)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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

            // 撒花层
            if showConfetti && scorePercent >= 60 {
                ConfettiView(intensity: scorePercent >= 90 ? .high : .low)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .navigationTitle("练习结果")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: startAnimations)
    }

    // MARK: - 动画编排

    private func startAnimations() {
        // 1) 分数环动画 0.8s
        withAnimation(.easeOut(duration: 0.8)) {
            animatedProgress = Double(scorePercent) / 100.0
        }

        // 数字跳动 — 用 Timer 驱动
        let steps = 20
        let interval = 0.8 / Double(steps)
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                withAnimation(.none) {
                    displayedPercent = Int(Double(scorePercent) * Double(i) / Double(steps))
                }
            }
        }

        // 2) 评语弹入 0.8s 后
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showLabel = true
            }
            triggerHaptic()
        }

        // 3) 统计行滑入 1.0s 后
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.4)) {
                showStats = true
            }
        }

        // 4) 撒花 0.6s 后开始
        if scorePercent >= 60 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                showConfetti = true
            }
            // 1.8s 后停止生成新粒子
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                showConfetti = false
            }
        }
    }

    // MARK: - 触感

    private func triggerHaptic() {
        if scorePercent >= 90 {
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
        } else if scorePercent >= 60 {
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.impactOccurred()
        }
    }

    // MARK: - 颜色 & 评语

    private var scoreColor: Color {
        switch scorePercent {
        case 90...100: return .green
        case 60..<90: return .orange
        default: return .red
        }
    }

    private var scoreLabel: String {
        switch scorePercent {
        case 90...100: return "🎉 优秀！"
        case 80..<90: return "👍 很好！"
        case 60..<80: return "💪 继续加油"
        default: return "📖 需要多练习"
        }
    }
}

// MARK: - 撒花粒子系统

private struct ConfettiView: View {
    enum Intensity { case low, high }
    let intensity: Intensity

    @State private var particles: [ConfettiParticle] = []
    private let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    private var emitCount: Int { intensity == .high ? 6 : 2 }

    private static let colors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink,
        Color(red: 1, green: 0.84, blue: 0) // 金色
    ]
    private static let shapes: [ConfettiShape] = [.circle, .rectangle, .star]

    var body: some View {
        Canvas { context, size in
            for p in particles {
                let rect = CGRect(x: p.x - p.size / 2, y: p.y - p.size / 2,
                                  width: p.size, height: p.size * abs(cos(p.spin)))
                context.opacity = Double(p.opacity)
                context.fill(Path(ellipseIn: rect), with: .color(p.color))
            }
        }
        .onReceive(timer) { _ in
            updateParticles()
        }
        .onAppear {
            emitBurst()
        }
    }

    private func emitBurst() {
        let count = intensity == .high ? 40 : 15
        for _ in 0..<count {
            particles.append(makeParticle(fromTop: false))
        }
    }

    private func updateParticles() {
        // 持续发射
        for _ in 0..<emitCount {
            particles.append(makeParticle(fromTop: true))
        }
        // 更新物理
        particles = particles.compactMap { p in
            var p = p
            p.x += p.vx
            p.y += p.vy
            p.vy += 0.15 // 重力
            p.vx *= 0.99
            p.spin += p.spinSpeed
            p.opacity -= 0.008
            return p.opacity > 0 && p.y < UIScreen.main.bounds.height + 50 ? p : nil
        }
    }

    private func makeParticle(fromTop: Bool) -> ConfettiParticle {
        let w = UIScreen.main.bounds.width
        let h = UIScreen.main.bounds.height
        let x = CGFloat.random(in: 0...w)
        let y: CGFloat = fromTop ? CGFloat.random(in: -20...0) : CGFloat.random(in: h * 0.2...h * 0.4)
        return ConfettiParticle(
            x: x, y: y,
            vx: CGFloat.random(in: -3...3),
            vy: fromTop ? CGFloat.random(in: 1...4) : CGFloat.random(in: -8 ... -2),
            size: CGFloat.random(in: 4...10),
            color: Self.colors.randomElement()!,
            shape: Self.shapes.randomElement()!,
            spin: CGFloat.random(in: 0...(.pi * 2)),
            spinSpeed: CGFloat.random(in: -0.15...0.15),
            opacity: Float(1.0)
        )
    }
}

private struct ConfettiParticle {
    var x, y, vx, vy, size: CGFloat
    var color: Color
    var shape: ConfettiShape
    var spin, spinSpeed: CGFloat
    var opacity: Float
}

private enum ConfettiShape { case circle, rectangle, star }

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
        PracticeResultView(title: "选择题", totalCount: 10, correctCount: 9)
    }
}

// MARK: - 正确率颜色（全局复用）

/// 根据正确率百分比返回颜色：< 60 红色，60~89 黄色，≥ 90 绿色
func accuracyColor(for percent: Double) -> Color {
    switch percent {
    case 90...Double.greatestFiniteMagnitude: return .green
    case 60..<90: return .yellow
    default: return .red
    }
}
