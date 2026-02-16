//
//  HomeView.swift
//  Volingo
//
//  Created by jacob on 2026/2/13.
//

import SwiftUI

// MARK: - Home ViewModel

@MainActor
class HomeViewModel: ObservableObject {
    @Published var todayPackage: TodayPackage?
    @Published var stats: StatsResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIService.shared

    func load(textbookCode: String) {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        Task {
            // 并发加载套餐和统计
            async let pkgTask = api.fetchTodayPackage(textbookCode: textbookCode)
            async let statsTask = api.fetchStats(days: 30)

            do {
                let pkgResp = try await pkgTask
                todayPackage = TodayPackage(
                    date: Date(),
                    level: textbookCode,
                    items: pkgResp.items.compactMap { item in
                        guard let type = QuestionType.from(apiKey: item.type) else { return nil }
                        return PackageItem(type: type, count: item.count, weight: item.weight)
                    },
                    estimatedMinutes: pkgResp.estimatedMinutes
                )
            } catch {
                print("加载今日套餐失败: \(error)")
                // 套餐加载失败不阻塞首页
            }

            do {
                stats = try await statsTask
            } catch {
                print("加载统计失败: \(error)")
            }

            isLoading = false
        }
    }

    var streak: Int { stats?.currentStreak ?? 0 }
    var totalCompleted: Int { stats?.totalCompleted ?? 0 }
}

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject private var store: UserStateStore
    @StateObject private var vm = HomeViewModel()

    private var textbookCode: String {
        store.currentTextbookCode ?? "juniorPEP-7a"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. 顶部状态
                    headerSection

                    // 2. 今日推荐套餐（大卡）
                    if let package = vm.todayPackage {
                        TodayPackageCardView(package: package)
                    } else if vm.isLoading {
                        ProgressView("加载今日套餐…")
                            .frame(height: 160)
                    }

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
            .onAppear {
                vm.load(textbookCode: textbookCode)
                AnalyticsService.shared.trackScreenView("HomeView")
            }
        }
    }

    // MARK: - 顶部状态

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(currentLevelLabel)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let package = vm.todayPackage {
                    Text("今天完成 \(package.totalQuestions) 题即达成目标")
                        .font(.headline)
                } else {
                    Text("开始今天的学习吧")
                        .font(.headline)
                }
            }
            Spacer()
            // 连续学习天数
            VStack(spacing: 2) {
                Text("\(vm.streak)")
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
            NavigationLink(destination: PracticeRouterView(questionType: .errorReview)) {
                ReviewQuickCard(
                    icon: "arrow.counterclockwise",
                    title: "错题复练",
                    value: "回顾今日错题",
                    color: .red
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: PracticeRouterView(questionType: .randomChallenge)) {
                ReviewQuickCard(
                    icon: "shuffle",
                    title: "随机挑战",
                    value: "混合题型",
                    color: .orange
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 轻量进度

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("学习概况")
                .font(.headline)

            HStack(spacing: 16) {
                ProgressStatView(label: "总做题", value: "\(vm.totalCompleted)")
                ProgressStatView(label: "连续学习", value: "\(vm.streak) 天")
                ProgressStatView(label: "正确率", value: correctRateLabel)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var correctRateLabel: String {
        guard let stats = vm.stats, stats.totalCompleted > 0 else { return "--" }
        let rate = Double(stats.totalCorrect) / Double(stats.totalCompleted) * 100
        return String(format: "%.0f%%", rate)
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
