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
    var hasLoaded = false
    private var lastTextbookCode: String?

    private let api = APIService.shared
    private let packageStore = TodayPackageStore.shared

    func load(textbookCode: String, force: Bool = false) {
        guard force || !hasLoaded || lastTextbookCode != textbookCode else { return }
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        lastTextbookCode = textbookCode

        Task {
            // 1. 今日套餐：优先用本地缓存（教材匹配时）
            if packageStore.hasTodayCache(for: textbookCode), let cached = packageStore.cached {
                todayPackage = buildPackageFromCache(cached)
            } else {
                // 无缓存或非今天 → 从 API 拉取并缓存
                do {
                    let (pkgResp, rawData) = try await api.fetchTodayPackage(textbookCode: textbookCode)
                    packageStore.cacheFromAPI(response: pkgResp, rawData: rawData, textbookCode: textbookCode)
                    if let cached = packageStore.cached {
                        todayPackage = buildPackageFromCache(cached)
                    }
                } catch {
                    print("加载今日套餐失败: \(error)")
                }
            }

            // 2. 统计照常拉
            do {
                stats = try await api.fetchStats(days: 30)
            } catch {
                print("加载统计失败: \(error)")
            }

            isLoading = false
            hasLoaded = true
        }
    }

    /// 从缓存刷新本地 UI 状态（不请求 API）
    func refreshFromCache() {
        if let cached = packageStore.cached {
            todayPackage = buildPackageFromCache(cached)
        }
    }

    private func buildPackageFromCache(_ cached: CachedTodayPackage) -> TodayPackage {
        TodayPackage(
            date: Date(),
            level: cached.textbookCode,
            items: cached.items.compactMap { item in
                guard let type = QuestionType.from(apiKey: item.questionType) else { return nil }
                return PackageItem(type: type, count: item.count, weight: item.weight)
            },
            estimatedMinutes: cached.estimatedMinutes
        )
    }

    var streak: Int { stats?.currentStreak ?? 0 }
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

                    // 2. 每日挑战（大卡）
                    if let package = vm.todayPackage {
                        TodayPackageCardView(package: package)
                    } else if vm.isLoading {
                        ProgressView("加载每日挑战…")
                            .frame(height: 160)
                    }

                    // 3. 复习 & 薄弱区
                    reviewSection

                    // 4. 专项训练分组
                    ForEach(TrainingCategory.allCases) { category in
                        TrainingSectionView(category: category)
                    }

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
            .onReceive(NotificationCenter.default.publisher(for: .practiceResultsSubmitted)) { _ in
                vm.refreshFromCache()
                // 只刷新统计
                Task {
                    vm.stats = try? await APIService.shared.fetchStats(days: 30)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - 顶部状态

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(currentLevelLabel)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let package = vm.todayPackage {
                    if TodayPackageStore.shared.allCompleted {
                        Text("今日挑战已全部完成 🏆")
                            .font(.headline)
                    } else {
                        Text("今天完成 \(package.totalQuestions) 题即达成目标")
                            .font(.headline)
                    }
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
            let wrongCount = ErrorQuestionStore.shared.pendingReviewCount
            NavigationLink(destination: PracticeRouterView(questionType: .errorReview)) {
                ReviewQuickCard(
                    icon: "arrow.counterclockwise",
                    title: "错题复练",
                    value: wrongCount > 0 ? "\(wrongCount) 道错题待复习" : "暂无错题 🎉",
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

// MARK: - Preview

#Preview {
    HomeView()
        .environmentObject(UserStateStore())
}
