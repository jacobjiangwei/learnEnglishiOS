//
//  ProfileView.swift
//  海豹英语
//
//  Created by jacob on 2025/8/10.
//

import SwiftUI

// MARK: - Profile Stats ViewModel

@MainActor
class ProfileStatsViewModel: ObservableObject {
    @Published var stats: StatsResponse?
    @Published var isLoading = false

    private let api = APIService.shared

    func load() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            do {
                stats = try await api.fetchStats(days: 365)
            } catch {
                print("加载学习统计失败: \(error)")
            }
            isLoading = false
        }
    }
}

// MARK: - Profile View

struct ProfileView: View {
    @EnvironmentObject private var onboardingStore: UserStateStore
    @StateObject private var statsVM = ProfileStatsViewModel()
    @State private var pendingAction: ProfileAction? = nil
    @State private var showBindEmail = false
    @ObservedObject private var authManager = AuthManager.shared

    var body: some View {
        NavigationView {
            List {
                // MARK: 账号 — 放在最上面
                Section(header: Text("账号")) {
                    if let user = authManager.currentUser,
                       user.isEmailUser,
                       let email = user.email {
                        Button {
                            showBindEmail = true
                        } label: {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(.blue)
                                Text(email)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 14))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Button {
                            showBindEmail = true
                        } label: {
                            HStack {
                                Image(systemName: "envelope.badge.plus")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("绑定邮箱")
                                        .foregroundColor(.primary)
                                    Text("绑定后可在其他设备登录")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // MARK: 当前学习目标
                Section(header: Text("当前学习目标")) {
                    HStack {
                        Text("等级")
                        Spacer()
                        Text(currentLevelLabel)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("教材")
                        Spacer()
                        Text(currentTextbookLabel)
                            .foregroundColor(.secondary)
                    }

                    if onboardingStore.userState.needsPublisher {
                        HStack {
                            Text("学期")
                            Spacer()
                            Text(currentSemesterLabel)
                                .foregroundColor(.secondary)
                        }

                        Picker("单元", selection: currentUnitBinding) {
                            ForEach(1...maxUnitCount, id: \.self) { unit in
                                Text("第\(unit)单元").tag(unit)
                            }
                        }
                    }

                    Button("修改学习目标") {
                        pendingAction = .modifyGoal
                    }
                }

                // MARK: 学习概况 — 卡片风格
                Section(header: Text("学习概况")) {
                    if statsVM.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if let stats = statsVM.stats {
                        // 第一行：总做题 / 正确率 / 连续学习
                        HStack(spacing: 0) {
                            StatCell(value: "\(stats.totalCompleted)", label: "总做题")
                            StatCell(value: overallAccuracy(stats), label: "正确率", valueColor: overallAccuracyColor(stats))
                            StatCell(value: "\(stats.currentStreak) 天", label: "连续学习")
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    } else {
                        Text("暂无学习数据")
                            .foregroundColor(.secondary)
                    }
                }

                // MARK: 各题型统计
                Section(header: Text("题型统计")) {
                    // 表头
                    HStack {
                        Text("题型")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("做题数")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .trailing)
                        Text("正确率")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .trailing)
                    }
                    ForEach(allQuestionTypeStats) { stat in
                        HStack {
                            Text(questionTypeDisplayName(stat.questionType))
                            Spacer()
                            Text(stat.total > 0 ? "\(stat.total)" : "--")
                                .foregroundColor(.secondary)
                                .frame(width: 60, alignment: .trailing)
                            Text(stat.total > 0 ? String(format: "%.0f%%", stat.accuracy) : "--")
                                .foregroundColor(stat.total > 0 ? accuracyColor(for: stat.accuracy) : .secondary)
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }

                // MARK: 历史记录
                Section(header: Text("历史记录")) {
                    NavigationLink(destination: PracticeHistoryView()) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.blue)
                            Text("练习历史")
                            Spacer()
                            Text("\(PracticeHistoryStore.shared.sessions.count) 条")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                    }
                }

                // MARK: 设置
                Section(header: Text("设置")) {
                    Button("重新完整设置") {
                        pendingAction = .fullReset
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("我的")
            .sheet(isPresented: $showBindEmail) {
                BindEmailView()
            }
            .onAppear {
                statsVM.load()
            }
            .onReceive(NotificationCenter.default.publisher(for: .practiceResultsSubmitted)) { _ in
                statsVM.load()
            }
            .alert(item: $pendingAction) { action in
                switch action {
                case .modifyGoal:
                    return Alert(
                        title: Text("修改学习目标?"),
                        message: Text("将重新选择等级与教材。"),
                        primaryButton: .destructive(Text("确认"), action: {
                            onboardingStore.startModifyGoal()
                        }),
                        secondaryButton: .cancel(Text("取消"))
                    )
                case .fullReset:
                    return Alert(
                        title: Text("重新完整设置?"),
                        message: Text("将重新开始全部流程（欢迎页、等级、教材、测试）。"),
                        primaryButton: .destructive(Text("确认"), action: {
                            onboardingStore.resetOnboarding()
                        }),
                        secondaryButton: .cancel(Text("取消"))
                    )
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Helpers

    private func overallAccuracy(_ stats: StatsResponse) -> String {
        guard stats.totalCompleted > 0 else { return "--" }
        let rate = Double(stats.totalCorrect) / Double(stats.totalCompleted) * 100
        return String(format: "%.0f%%", rate)
    }

    private func overallAccuracyColor(_ stats: StatsResponse) -> Color {
        guard stats.totalCompleted > 0 else { return .primary }
        let rate = Double(stats.totalCorrect) / Double(stats.totalCompleted) * 100
        return accuracyColor(for: rate)
    }

    private func questionTypeDisplayName(_ apiKey: String) -> String {
        QuestionType.from(apiKey: apiKey)?.rawValue ?? apiKey
    }

    /// 所有练习题型（不含轻量类），合并 API 返回的数据，没有数据的显示 0
    private var allQuestionTypeStats: [QuestionTypeStats] {
        let practiceTypes: [QuestionType] = [
            .multipleChoice, .cloze, .reading, .translation, .rewriting,
            .errorCorrection, .sentenceOrdering, .listening, .speaking,
            .vocabulary, .grammar
        ]
        let existing = statsVM.stats?.questionTypeStats ?? []
        let lookup = Dictionary(uniqueKeysWithValues: existing.map { ($0.questionType, $0) })
        return practiceTypes.map { type in
            lookup[type.apiKey] ?? QuestionTypeStats(questionType: type.apiKey, total: 0, correct: 0)
        }
    }

    private var currentLevelLabel: String {
        if let grade = onboardingStore.userState.gradeEnum {
            return grade.rawValue
        }
        return "未定级"
    }

    private var currentTextbookLabel: String {
        if let pub = onboardingStore.userState.publisherEnum {
            return pub.displayName
        }
        return "未选择"
    }

    private var currentSemesterLabel: String {
        if let sem = onboardingStore.userState.semesterEnum {
            return "\(sem.title)学期"
        }
        return "未选择"
    }

    private var maxUnitCount: Int {
        guard let grade = onboardingStore.userState.gradeEnum,
              let publisher = onboardingStore.userState.publisherEnum else { return 16 }
        let semester = onboardingStore.userState.semesterEnum ?? .current
        return unitCount(for: grade, publisher: publisher, semester: semester)
    }

    private var currentUnitBinding: Binding<Int> {
        Binding(
            get: { onboardingStore.userState.currentUnit ?? 1 },
            set: { newUnit in
                onboardingStore.updateCurrentUnit(newUnit)
                syncUnitToServer(newUnit)
            }
        )
    }

    private func syncUnitToServer(_ unit: Int) {
        guard let grade = onboardingStore.userState.grade else { return }
        Task {
            try? await AuthManager.shared.updateProfile(
                grade: grade,
                publisher: onboardingStore.userState.publisher,
                semester: onboardingStore.userState.semester,
                currentUnit: unit
            )
        }
    }
}

// MARK: - 统计数字单元格

private struct StatCell: View {
    let value: String
    let label: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundColor(valueColor)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

private enum ProfileAction: String, Identifiable {
    case modifyGoal
    case fullReset

    var id: String { rawValue }
}

#Preview {
    ProfileView()
}
