//
//  TodayPackageCardView.swift
//  Volingo
//
//  Created by jacob on 2026/2/13.
//

import SwiftUI

struct TodayPackageCardView: View {
    let package: TodayPackage
    @State private var showBreakdown = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 主卡片
            VStack(alignment: .leading, spacing: 16) {
                // 顶部：标签 + 日期
                HStack {
                    Label("今日推荐", systemImage: "star.fill")
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
                    Text("共 \(package.totalQuestions) 题 · 约 \(package.estimatedMinutes) 分钟")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text(package.typeSummary)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                }
                
                // 底部：按钮
                HStack(spacing: 12) {
                    // 主按钮：开始
                    NavigationLink(destination: TodaySessionView(package: package)) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("开始练习")
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
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
                    colors: [Color.blue, Color.blue.opacity(0.8), Color.purple.opacity(0.7)],
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
                HStack {
                    Image(systemName: item.type.icon)
                        .foregroundColor(item.type.color)
                        .frame(width: 24)
                    
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
    TodayPackageCardView(package: .mock())
        .padding()
}
