//
//  TodayPackageCardView.swift
//  海豹英语
//
//  Created by jacob on 2026/2/13.
//

import SwiftUI

struct TodayPackageCardView: View {
    let package: TodayPackage
    @ObservedObject private var packageStore = TodayPackageStore.shared
    @State private var showBreakdown = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 主卡片
            VStack(alignment: .leading, spacing: 16) {
                // 顶部：标签 + 日期
                HStack {
                    Label("每日挑战", systemImage: "flame.fill")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.25))
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // 中间：核心信息
                VStack(alignment: .leading, spacing: 6) {
                    if packageStore.allCompleted {
                        Text("今日挑战已完成 🏆")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                    } else {
                        Text("\(package.levelDisplayName) · 全国统一题")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                    }
                    
                    if packageStore.allCompleted {
                        let progress = packageStore.completionProgress
                        Text("全部 \(progress.total) 项已完成")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                    } else {
                        let progress = packageStore.completionProgress
                        if progress.completed > 0 {
                            Text("共 \(package.totalQuestions) 题 · 约 \(package.estimatedMinutes) 分钟 · 已完成 \(progress.completed)/\(progress.total)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.85))
                        } else {
                            Text("共 \(package.totalQuestions) 题 · 约 \(package.estimatedMinutes) 分钟")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    
                    // 参与人数（占位，后续后端支持后替换）
                    // TODO: 接入后端统计 API
                    // Text("今日已有 1,247 人参与 · 平均正确率 78%")
                    //     .font(.caption)
                    //     .foregroundColor(.white.opacity(0.7))
                }
                
                // 底部：按钮
                HStack(spacing: 12) {
                    // 主按钮
                    NavigationLink(destination: TodaySessionView(package: package)) {
                        HStack {
                            if packageStore.allCompleted {
                                Image(systemName: "trophy.fill")
                                Text("查看排行榜")
                            } else {
                                let progress = packageStore.completionProgress
                                if progress.completed > 0 {
                                    Image(systemName: "play.fill")
                                    Text("继续挑战")
                                } else {
                                    Image(systemName: "bolt.fill")
                                    Text("接受今日挑战")
                                }
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // 次按钮：查看构成
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            showBreakdown.toggle()
                        }
                    }) {
                        Image(systemName: showBreakdown ? "chevron.up" : "chevron.down")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color.orange, Color.orange.opacity(0.85), Color.red.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
            // 展开：题型构成明细
            if showBreakdown {
                breakdownView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    // MARK: - 题型明细展开
    
    private var breakdownView: some View {
        VStack(spacing: 0) {
            ForEach(package.items) { item in
                let completed = packageStore.isCompleted(questionType: item.type.apiKey)
                HStack {
                    if completed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .frame(width: 24)
                    } else {
                        Image(systemName: item.type.icon)
                            .foregroundColor(item.type.color)
                            .frame(width: 24)
                    }
                    
                    Text(item.type.rawValue)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(item.count) 题")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // 权重条
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(item.type.color.opacity(0.3))
                            .frame(width: geo.size.width)
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(item.type.color)
                                    .frame(width: geo.size.width * item.weight)
                            }
                    }
                    .frame(width: 60, height: 6)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                
                if item.id != package.items.last?.id {
                    Divider().padding(.leading, 56)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.top, -8)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: package.date)
    }
}

#Preview {
    TodayPackageCardView(package: TodayPackage(
        date: Date(),
        level: "juniorPEP-7a",
        items: [
            PackageItem(type: .multipleChoice, count: 5, weight: 0.4),
            PackageItem(type: .cloze, count: 3, weight: 0.3),
        ],
        estimatedMinutes: 10
    ))
    .padding()
}
