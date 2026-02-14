//
//  HomeView.swift
//  Volingo
//
//  Created by jacob on 2026/2/13.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: UserStateStore
    
    private let todayPackage = TodayPackage.mock()
    private let progress = HomeProgress.mock()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. 顶部状态
                    headerSection
                    
                    // 2. 今日推荐套餐（大卡）
                    TodayPackageCardView(package: todayPackage)
                    
                    // 3. 复习 & 薄弱区
                    reviewSection
                    
                    // 4. 专项训练分组
                    ForEach(TrainingCategory.allCases) { category in
                        TrainingSectionView(category: category)
                    }
                    
                    // 5. 轻量进度
                    progressSection
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal)
            }
            .navigationTitle("首页")
            .background(Color(.systemGroupedBackground))
        }
    }
    
    // MARK: - 顶部状态
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(currentLevelLabel)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("今天完成 \(todayPackage.totalQuestions) 题即达成目标")
                    .font(.headline)
            }
            Spacer()
            // 连续学习天数
            VStack(spacing: 2) {
                Text("\(progress.streak)")
                    .font(.title2.bold())
                    .foregroundColor(.orange)
                Text("天连续")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.top, 8)
    }
    
    // MARK: - 复习 & 薄弱区
    
    private var reviewSection: some View {
        HStack(spacing: 12) {
            // 错题复练
            NavigationLink(destination: PracticeRouterView(questionType: .errorReview)) {
                ReviewQuickCard(
                    icon: "arrow.counterclockwise",
                    title: "今日错题",
                    value: "\(progress.todayErrorCount) 题",
                    color: .red
                )
            }
            .buttonStyle(.plain)
            
            // 薄弱题型
            NavigationLink(destination: PracticeRouterView(questionType: progress.weakTypes.first ?? .cloze)) {
                ReviewQuickCard(
                    icon: "exclamationmark.triangle",
                    title: "薄弱项",
                    value: progress.weakTypes.prefix(2).map(\.rawValue).joined(separator: "·"),
                    color: .orange
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - 轻量进度
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("本周进度")
                .font(.headline)
            
            HStack(spacing: 16) {
                ProgressStatView(label: "已做题", value: "\(progress.weeklyQuestionsDone)")
                ProgressStatView(label: "连续学习", value: "\(progress.streak) 天")
                ProgressStatView(label: "今日错题", value: "\(progress.todayErrorCount)")
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private var currentLevelLabel: String {
        if let level = store.userState.confirmedLevel {
            return level.rawValue
        }
        if let selected = store.userState.selectedLevel {
            return selected.rawValue
        }
        return "未定级"
    }
}

// MARK: - 复习快捷卡

private struct ReviewQuickCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline.bold())
            }
            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 进度统计项

private struct ProgressStatView: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .environmentObject(UserStateStore())
}
