//
//  OnboardingFlowView.swift
//  海豹英语
//
//  Created by jacob on 2026/2/8.
//

import SwiftUI

// MARK: - Pipeline Step Type

/// Every possible step the onboarding pipeline can contain.
/// Steps are assembled dynamically based on user choices.
enum OnboardingStepType: String, Identifiable, Equatable {
    case welcome
    case gradeSelect
    case publisherSelect
    case unitSelect
    case levelTest
    case result

    var id: String { rawValue }

    var title: String {
        switch self {
        case .welcome:         return "开启学习之旅"
        case .gradeSelect:     return "选择年级"
        case .publisherSelect: return "选择教材"
        case .unitSelect:      return "选择单元"
        case .levelTest:       return "智能定级测试"
        case .result:          return "测试结果"
        }
    }
}

// MARK: - Draft State (collected during onboarding, not yet persisted)

struct OnboardingDraft {
    var selectedGrade: UserLevel?
    var selectedPublisher: Publisher?
    var selectedSemester: Semester?
    var selectedUnit: Int = 1
    var testScore: Double = 0
    var confirmedLevel: UserLevel?
    var attemptId = UUID()
}

// MARK: - Coordinator (pipeline brain)

@MainActor
final class OnboardingCoordinator: ObservableObject {
    @Published var draft = OnboardingDraft()
    @Published var currentIndex: Int = 0

    /// Dynamically computed step pipeline.
    /// Publisher step is included only for school grades.
    /// Level test is hidden — users pick grade + publisher and go straight in.
    var pipeline: [OnboardingStepType] {
        var steps: [OnboardingStepType] = [.welcome, .gradeSelect]

        if let grade = draft.selectedGrade {
            if grade.isSchoolGrade {
                steps.append(.publisherSelect)
                steps.append(.unitSelect)
            }
        } else {
            // Before grade is chosen, assume publisher + unit are needed
            steps.append(.publisherSelect)
            steps.append(.unitSelect)
        }

        // Level test hidden for now — skip straight to learning
        // steps.append(.levelTest)
        // steps.append(.result)
        return steps
    }

    var currentStep: OnboardingStepType {
        let p = pipeline
        return p[min(currentIndex, p.count - 1)]
    }

    var stepLabel: String {
        "\(currentIndex + 1)/\(pipeline.count)"
    }

    /// True when the current step is the last step in the pipeline.
    var isLastStep: Bool {
        currentIndex == pipeline.count - 1
    }

    // MARK: Navigation

    func goNext() {
        // Auto-select default publisher for school grades if publisher step is skipped
        if currentStep == .gradeSelect, let grade = draft.selectedGrade {
            if grade.isSchoolGrade && draft.selectedPublisher == nil {
                draft.selectedPublisher = .pep
            }
        }

        let p = pipeline
        if currentIndex < p.count - 1 {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentIndex += 1
            }
        }
    }

    func jumpToTest() {
        let p = pipeline
        if let idx = p.firstIndex(of: .levelTest) {
            draft.attemptId = UUID()
            withAnimation(.easeInOut(duration: 0.25)) {
                currentIndex = idx
            }
        }
    }

    func jumpToResult() {
        let p = pipeline
        if let idx = p.firstIndex(of: .result) {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentIndex = idx
            }
        }
    }

    func retestFromResult() {
        draft.attemptId = UUID()
        draft.testScore = 0
        draft.confirmedLevel = nil
        jumpToTest()
    }

    func downgradeAndRetest(_ level: UserLevel) {
        draft.selectedGrade = level
        draft.attemptId = UUID()
        draft.testScore = 0
        draft.confirmedLevel = nil
        jumpToTest()
    }

    /// Commit draft → UserStateStore and finish (main path — skip test).
    /// Also creates device user if needed and syncs profile to server.
    func skipTest(store: UserStateStore) {
        guard let grade = draft.selectedGrade else { return }
        AnalyticsService.shared.trackOnboardingStep("completed")
        AnalyticsService.shared.trackOnboardingCompleted()
        store.completeOnboarding(
            grade: grade,
            publisher: draft.selectedPublisher,
            semester: draft.selectedSemester,
            currentUnit: draft.selectedUnit
        )

        // Lazy user creation + profile sync
        Task {
            await createUserAndSyncProfile(store: store)
        }
    }

    /// Commit draft → UserStateStore and finish (test completed path).
    func completeWithTest(store: UserStateStore) {
        guard let confirmed = draft.confirmedLevel else { return }
        AnalyticsService.shared.trackOnboardingCompleted()
        AnalyticsService.shared.setUserLevel(confirmed.rawValue)
        store.completeOnboarding(
            grade: confirmed,
            publisher: draft.selectedPublisher,
            semester: draft.selectedSemester,
            currentUnit: draft.selectedUnit
        )

        // Lazy user creation + profile sync
        Task {
            await createUserAndSyncProfile(store: store)
        }
    }

    /// Create anonymous device user (if not yet authenticated) and sync profile to server.
    private func createUserAndSyncProfile(store: UserStateStore) async {
        let authManager = AuthManager.shared

        // Step 1: Create device user if not authenticated
        if !authManager.isAuthenticated {
            do {
                try await authManager.createDeviceUser()
                print("[Onboarding] ✅ 匿名用户创建成功")
            } catch {
                print("[Onboarding] ⚠️ 创建匿名用户失败: \(error)")
                return
            }
        }

        // Step 2: Sync profile (grade, publisher, semester, onboardingCompleted) to server
        let grade = (draft.confirmedLevel ?? draft.selectedGrade)?.apiKey ?? ""
        let publisher = draft.selectedPublisher?.rawValue
        let semester = draft.selectedSemester?.rawValue
        let unit = draft.selectedUnit
        do {
            try await authManager.updateProfile(grade: grade, publisher: publisher, semester: semester, currentUnit: unit, onboardingCompleted: true)
            print("[Onboarding] ✅ 用户资料已同步到服务器")
        } catch {
            print("[Onboarding] ⚠️ 同步用户资料失败: \(error)")
        }
    }

    /// Restore from an entry point (e.g. "modify goal")
    func restore(from entry: OnboardingEntry, state: UserState) {
        switch entry {
        case .full:
            break
        case .selectLevel:
            if let idx = pipeline.firstIndex(of: .gradeSelect) {
                currentIndex = idx
            }
        case .selectTextbook:
            // Restore grade from state
            if let gradeStr = state.grade, let grade = UserLevel.from(apiKey: gradeStr) {
                draft.selectedGrade = grade
                if let semStr = state.semester {
                    draft.selectedSemester = Semester(rawValue: semStr)
                }
            }
            if let idx = pipeline.firstIndex(of: .publisherSelect) {
                currentIndex = idx
            } else if let idx = pipeline.firstIndex(of: .gradeSelect) {
                currentIndex = idx
            }
        case .retest:
            if let gradeStr = state.grade, let grade = UserLevel.from(apiKey: gradeStr) {
                draft.selectedGrade = grade
                if let semStr = state.semester {
                    draft.selectedSemester = Semester(rawValue: semStr)
                }
                if let pubStr = state.publisher {
                    draft.selectedPublisher = Publisher(rawValue: pubStr)
                }
                draft.attemptId = UUID()
                jumpToTest()
            }
        }
    }
}

// MARK: - Main Flow View (thin shell)

struct OnboardingFlowView: View {
    @EnvironmentObject private var store: UserStateStore
    @StateObject private var coordinator = OnboardingCoordinator()
    @State private var didInitialize = false
    @State private var showEmailLogin = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.white, Color(white: 0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header (hidden on welcome)
                    if coordinator.currentStep != .welcome {
                        HStack {
                            Text(coordinator.currentStep.title)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                            Spacer()
                            Text(coordinator.stepLabel)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 16)

                        Spacer(minLength: 16)
                    }

                    // Step content
                    stepView

                    if coordinator.currentStep != .welcome {
                        Spacer(minLength: 24)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .sheet(isPresented: $showEmailLogin) {
            EmailLoginView {
                handleLoginSuccess()
            }
        }
        .onAppear {
            guard !didInitialize else { return }
            didInitialize = true
            coordinator.restore(from: store.onboardingEntry, state: store.userState)
            store.onboardingEntry = .full
        }
    }

    /// After login/register: restore from cloud profile or advance past welcome
    private func handleLoginSuccess() {
        if let profile = AuthManager.shared.currentUser,
           store.restoreFromCloudProfile(profile) {
            // Cloud profile has level/textbook → onboarding complete (RootView will switch)
            return
        }
        // No cloud data — advance to level select so user can pick
        coordinator.goNext()
    }

    @ViewBuilder
    private var stepView: some View {
        switch coordinator.currentStep {
        case .welcome:
            OnboardingWelcomeView {
                AnalyticsService.shared.trackOnboardingStep("welcome")
                coordinator.goNext()
            } onLogin: {
                showEmailLogin = true
            }

        case .gradeSelect:
            GradeSelectView(coordinator: coordinator) {
                AnalyticsService.shared.trackOnboardingStep("gradeSelect")
                if let grade = coordinator.draft.selectedGrade {
                    store.updateGrade(grade)
                    AnalyticsService.shared.trackOnboardingLevelSelected(grade.rawValue)
                }
                // For non-school grades, this is the last step → complete
                if coordinator.isLastStep {
                    coordinator.skipTest(store: store)
                } else {
                    coordinator.goNext()
                }
            }

        case .publisherSelect:
            PublisherSelectView(coordinator: coordinator) {
                AnalyticsService.shared.trackOnboardingStep("publisherSelect")
                if let pub = coordinator.draft.selectedPublisher {
                    store.updatePublisher(pub)
                }
                // Unit select follows publisher select
                if coordinator.isLastStep {
                    coordinator.skipTest(store: store)
                } else {
                    coordinator.goNext()
                }
            }

        case .unitSelect:
            UnitSelectView(coordinator: coordinator) {
                AnalyticsService.shared.trackOnboardingStep("unitSelect")
                coordinator.skipTest(store: store)
            }

        case .levelTest:
            if let level = coordinator.draft.selectedGrade {
                LevelTestView(
                    level: level,
                    attemptId: coordinator.draft.attemptId
                ) { score, recommended in
                    coordinator.draft.testScore = score
                    coordinator.draft.confirmedLevel = recommended
                    AnalyticsService.shared.trackOnboardingTestCompleted(
                        score: score,
                        recommendedLevel: recommended.rawValue
                    )
                    coordinator.jumpToResult()
                }
            }

        case .result:
            if let selected = coordinator.draft.selectedGrade {
                OnboardingResultView(
                    selectedLevel: selected,
                    score: coordinator.draft.testScore,
                    passed: coordinator.draft.testScore >= selected.passThreshold,
                    onConfirm: {
                        coordinator.completeWithTest(store: store)
                    },
                    onRetest: {
                        coordinator.retestFromResult()
                    },
                    onDowngrade: { downgrade in
                        coordinator.downgradeAndRetest(downgrade)
                    }
                )
            }
        }
    }
}

// MARK: - Welcome

struct OnboardingWelcomeView: View {
    let onContinue: () -> Void
    let onLogin: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero branding
            VStack(spacing: 14) {
                Text("🦭")
                    .font(.system(size: 88))
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
                Text("海豹英语")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Text("让英语学习更轻松")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer().frame(height: 44)

            // Feature highlights
            VStack(spacing: 14) {
                WelcomeFeatureRow(icon: "sparkles", color: .orange, text: "AI 智能出题，个性化练习")
                WelcomeFeatureRow(icon: "book.closed.fill", color: .blue, text: "同步课本教材，紧跟学校进度")
                WelcomeFeatureRow(icon: "brain.head.profile", color: .purple, text: "科学记忆算法，学了不忘")
            }
            .padding(.horizontal, 4)

            Spacer()

            // CTA Buttons
            VStack(spacing: 12) {
                Button(action: onContinue) {
                    Text("开始学习")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(colors: [Color.orange, Color(red: 1.0, green: 0.3, blue: 0.2)],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.orange.opacity(0.3), radius: 8, y: 4)
                }

                Button(action: onLogin) {
                    Text("注册 / 登录")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(white: 0.18))
                    .cornerRadius(16)
                }
            }
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Welcome Feature Row

private struct WelcomeFeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
            Spacer()
        }
    }
}

// MARK: - Grade Select (+ semester sheet)

struct GradeSelectView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    let onContinue: () -> Void

    @State private var showSemesterSheet = false

    private var draft: OnboardingDraft { coordinator.draft }

    private var needsSemester: Bool {
        draft.selectedGrade?.isSchoolGrade ?? false
    }

    private var canContinue: Bool {
        guard draft.selectedGrade != nil else { return false }
        if needsSemester && draft.selectedSemester == nil { return false }
        return true
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("请选择孩子目前的年级")
                    .font(.system(size: 18, weight: .semibold))

                ForEach(LevelGroup.allCases) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(group.rawValue)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.secondary)

                        ForEach(UserLevel.allCases.filter { $0.group == group }) { level in
                            LevelCard(
                                level: level,
                                isSelected: draft.selectedGrade == level,
                                semesterLabel: semesterLabel(for: level)
                            )
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    coordinator.draft.selectedGrade = level
                                    if level.isSchoolGrade {
                                        // Pre-fill smart default, then show sheet to confirm
                                        if coordinator.draft.selectedSemester == nil {
                                            coordinator.draft.selectedSemester = Semester.current
                                        }
                                        showSemesterSheet = true
                                    } else {
                                        coordinator.draft.selectedSemester = nil
                                        coordinator.draft.selectedPublisher = nil
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 100)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button(action: onContinue) {
                    Text("下一步")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(canContinue ? Color.blue : Color.gray.opacity(0.4))
                        .cornerRadius(14)
                }
                .disabled(!canContinue)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(.thinMaterial)
        }
        .sheet(isPresented: $showSemesterSheet) {
            SemesterSheetView(
                levelName: draft.selectedGrade?.rawValue ?? "",
                selectedSemester: Binding(
                    get: { coordinator.draft.selectedSemester },
                    set: { coordinator.draft.selectedSemester = $0 }
                )
            )
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
    }

    /// Show semester badge on selected grade card
    private func semesterLabel(for level: UserLevel) -> String? {
        guard draft.selectedGrade == level,
              level.isSchoolGrade,
              let sem = draft.selectedSemester else { return nil }
        return "\(sem.title)学期"
    }
}

// MARK: - Semester Sheet

struct SemesterSheetView: View {
    let levelName: String
    @Binding var selectedSemester: Semester?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("选择学期")
                .font(.system(size: 20, weight: .bold))

            Text(levelName)
                .font(.system(size: 16))
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                ForEach(Semester.allCases) { semester in
                    SemesterPill(
                        semester: semester,
                        isSelected: selectedSemester == semester
                    )
                    .onTapGesture {
                        withAnimation(.spring()) {
                            selectedSemester = semester
                        }
                    }
                }
            }
            .padding(.horizontal, 20)

            Button(action: { dismiss() }) {
                Text("确定")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(selectedSemester == nil ? Color.gray.opacity(0.4) : Color.blue)
                    .cornerRadius(14)
            }
            .disabled(selectedSemester == nil)
            .padding(.horizontal, 20)
        }
        .padding(.top, 24)
    }
}

struct SemesterPill: View {
    let semester: Semester
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: semester == .first ? "1.circle.fill" : "2.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(isSelected ? .blue : .gray)
            Text("\(semester.title)学期")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isSelected ? .blue : .primary)
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.white)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Publisher Select

struct PublisherSelectView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    let onContinue: () -> Void

    private var draft: OnboardingDraft { coordinator.draft }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("请选择教材版本")
                    .font(.system(size: 18, weight: .semibold))

                ForEach(Publisher.allCases) { pub in
                    PublisherCard(
                        publisher: pub,
                        isSelected: draft.selectedPublisher == pub,
                        isRecommended: pub == .pep
                    )
                    .onTapGesture {
                        withAnimation(.spring()) {
                            coordinator.draft.selectedPublisher = pub
                        }
                    }
                }
            }
            .padding(.bottom, 100)
        }
        .onAppear {
            // Pre-select recommended publisher if none chosen
            if coordinator.draft.selectedPublisher == nil {
                coordinator.draft.selectedPublisher = .pep
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button(action: onContinue) {
                    Text("下一步")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(draft.selectedPublisher == nil ? Color.gray.opacity(0.4) : Color.blue)
                        .cornerRadius(14)
                }
                .disabled(draft.selectedPublisher == nil)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(.thinMaterial)
        }
    }
}

// MARK: - Unit Select View

struct UnitSelectView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    let onContinue: () -> Void

    private var maxUnit: Int {
        guard let grade = coordinator.draft.selectedGrade,
              let publisher = coordinator.draft.selectedPublisher else { return 16 }
        let semester = coordinator.draft.selectedSemester ?? .current
        return unitCount(for: grade, publisher: publisher, semester: semester)
    }

    private let columns = [
        GridItem(.adaptive(minimum: 64, maximum: 80), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("你学到第几单元了？")
                    .font(.system(size: 18, weight: .semibold))

                Text("选择你当前正在学习的单元")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(1...maxUnit, id: \.self) { unit in
                        let isSelected = coordinator.draft.selectedUnit == unit
                        Button {
                            withAnimation(.spring()) {
                                coordinator.draft.selectedUnit = unit
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Text("\(unit)")
                                    .font(.system(size: 22, weight: .bold))
                                Text("单元")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(isSelected ? .white : .primary)
                            .frame(width: 64, height: 64)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(isSelected ? Color.blue : Color.white)
                                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.2), lineWidth: 1.5)
                            )
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding(.bottom, 100)
        }
        .onAppear {
            // Default to unit 1
            if coordinator.draft.selectedUnit < 1 || coordinator.draft.selectedUnit > maxUnit {
                coordinator.draft.selectedUnit = 1
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button(action: onContinue) {
                    Text("开始学习")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.blue)
                        .cornerRadius(14)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(.thinMaterial)
        }
    }
}

// MARK: - Reusable Cards

struct PublisherCard: View {
    let publisher: Publisher
    let isSelected: Bool
    let isRecommended: Bool

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(publisher.color.opacity(0.15))
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: publisher.icon)
                        .foregroundColor(publisher.color)
                        .font(.system(size: 22, weight: .bold))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(publisher.displayName)
                    .font(.system(size: 17, weight: .bold))
                Text(publisher.subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                if isRecommended {
                    Text("推荐")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(publisher.color)
                        .clipShape(Capsule())
                }
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? publisher.color.opacity(0.12) : Color.white)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? publisher.color : Color.clear, lineWidth: 1.5)
        )
    }
}

struct LevelCard: View {
    let level: UserLevel
    let isSelected: Bool
    var semesterLabel: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(level.color.opacity(0.15))
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: level.icon)
                        .foregroundColor(level.color)
                        .font(.system(size: 22, weight: .bold))
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(level.rawValue)
                        .font(.system(size: 17, weight: .bold))
                    if let semesterLabel {
                        Text(semesterLabel)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
                Text(level.subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(level.vocabRange)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? level.color.opacity(0.12) : Color.white)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? level.color : Color.clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Level Test

struct LevelTestView: View {
    @StateObject private var viewModel: LevelTestViewModel
    let onComplete: (Double, UserLevel) -> Void

    init(level: UserLevel, attemptId: UUID, onComplete: @escaping (Double, UserLevel) -> Void) {
        _viewModel = StateObject(wrappedValue: LevelTestViewModel(level: level, attemptId: attemptId))
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 18) {
            progress

            if let question = viewModel.currentQuestion {
                Text(question.stem)
                    .font(.system(size: 20, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                ForEach(question.options.indices, id: \ .self) { index in
                    OptionRow(
                        text: question.options[index],
                        state: optionState(for: index, correct: question.correctIndex)
                    )
                    .onTapGesture {
                        withAnimation(.spring()) {
                            viewModel.selectOption(index)
                        }
                    }
                }

                Button(action: {
                    withAnimation(.easeInOut) {
                        viewModel.goNext()
                        if viewModel.isCompleted {
                            let recommended = recommendedLevel(
                                for: viewModel.score,
                                selected: viewModel.level
                            )
                            onComplete(viewModel.score, recommended)
                        }
                    }
                }) {
                    Text(viewModel.selectedOptionIndex == nil ? "请选择一个答案" : "下一题")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(viewModel.selectedOptionIndex == nil
                                    ? Color.gray.opacity(0.4) : Color.blue)
                        .cornerRadius(14)
                }
                .disabled(viewModel.selectedOptionIndex == nil)
            }
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("进度 \(viewModel.currentIndex + 1)/\(viewModel.questions.count)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            ProgressView(value: viewModel.progress)
                .tint(Color.blue)
        }
    }

    private func optionState(for index: Int, correct: Int) -> OptionRow.State {
        if let selected = viewModel.selectedOptionIndex {
            if index == correct { return .correct }
            if index == selected { return .incorrect }
            return .idle
        }
        return .idle
    }

    private func recommendedLevel(for score: Double, selected: UserLevel) -> UserLevel {
        // Always return the user's original selection.
        // The result page handles pass/fail UI separately.
        return selected
    }
}

// MARK: - Result

struct OnboardingResultView: View {
    let selectedLevel: UserLevel
    let score: Double
    let passed: Bool
    let onConfirm: () -> Void
    let onRetest: () -> Void
    let onDowngrade: (UserLevel) -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Circle()
                .fill((passed ? Color.green : Color.orange).opacity(0.15))
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: passed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(passed ? .green : .orange)
                )

            Text("测试完成")
                .font(.system(size: 26, weight: .bold))

            Text("正确率 \(Int(score * 100))%")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.secondary)

            // Current selection
            VStack(spacing: 8) {
                Text(passed ? "恭喜通过!" : "未达到通过标准")
                    .font(.system(size: 14))
                    .foregroundColor(passed ? .green : .orange)
                Text(selectedLevel.rawValue)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(selectedLevel.color)
            }

            if passed {
                // --- Passed: single confirm button ---
                Button(action: onConfirm) {
                    Text("确认 \(selectedLevel.rawValue) 并开始学习")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.green)
                        .cornerRadius(14)
                }
            } else {
                // --- Failed: keep original + downgrade option ---
                Button(action: onConfirm) {
                    Text("仍然选择 \(selectedLevel.rawValue)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.blue)
                        .cornerRadius(14)
                }

                if let fallback = selectedLevel.fallbackLevel {
                    Button(action: { onDowngrade(fallback) }) {
                        Text("降级到 \(fallback.rawValue)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(12)
                    }
                }
            }

            Button(action: onRetest) {
                Text("重新测试")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Option Row

struct OptionRow: View {
    enum State { case idle, correct, incorrect }

    let text: String
    let state: State

    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            if state == .correct {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if state == .incorrect {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding(14)
        .background(bgColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var bgColor: Color {
        switch state {
        case .idle:      return Color.white
        case .correct:   return Color.green.opacity(0.12)
        case .incorrect: return Color.red.opacity(0.12)
        }
    }

    private var borderColor: Color {
        switch state {
        case .idle:      return Color.gray.opacity(0.2)
        case .correct:   return Color.green
        case .incorrect: return Color.red
        }
    }
}

#Preview {
    OnboardingFlowView()
}
