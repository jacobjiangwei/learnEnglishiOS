//
//  OnboardingFlowView.swift
//  Volingo
//
//  Created by jacob on 2026/2/8.
//

import SwiftUI

// MARK: - Pipeline Step Type

/// Every possible step the onboarding pipeline can contain.
/// Steps are assembled dynamically based on user choices.
enum OnboardingStepType: String, Identifiable, Equatable {
    case welcome
    case levelSelect
    case textbookSelect
    case levelTest
    case result

    var id: String { rawValue }

    var title: String {
        switch self {
        case .welcome:        return "开启学习之旅"
        case .levelSelect:    return "选择学习等级"
        case .textbookSelect: return "选择教材体系"
        case .levelTest:      return "智能定级测试"
        case .result:         return "测试结果"
        }
    }
}

// MARK: - Draft State (collected during onboarding, not yet persisted)

struct OnboardingDraft {
    var selectedLevel: UserLevel?
    var selectedSemester: Semester?
    var selectedTextbook: TextbookOption?
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
    /// Textbook step is included only when multiple options exist.
    var pipeline: [OnboardingStepType] {
        var steps: [OnboardingStepType] = [.welcome, .levelSelect]

        if let level = draft.selectedLevel {
            let options = TextbookOption.options(for: level)
            if options.count > 1 {
                steps.append(.textbookSelect)
            }
        } else {
            // Before level is chosen, assume textbook is needed
            steps.append(.textbookSelect)
        }

        steps.append(.levelTest)
        steps.append(.result)
        return steps
    }

    var currentStep: OnboardingStepType {
        let p = pipeline
        return p[min(currentIndex, p.count - 1)]
    }

    var stepLabel: String {
        "\(currentIndex + 1)/\(pipeline.count)"
    }

    /// True when the current step is the last one before the test.
    /// Used to show a "跳过测试" option.
    var isLastBeforeTest: Bool {
        let p = pipeline
        guard let testIdx = p.firstIndex(of: .levelTest) else { return false }
        return currentIndex == testIdx - 1
    }

    // MARK: Navigation

    func goNext() {
        // Auto-select textbook if only one option and textbook step is skipped
        if currentStep == .levelSelect, let level = draft.selectedLevel {
            let options = TextbookOption.options(for: level)
            if options.count == 1 {
                draft.selectedTextbook = options.first
            } else {
                draft.selectedTextbook = draft.selectedTextbook ?? TextbookOption.recommended(for: level)
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
        draft.selectedLevel = level
        draft.attemptId = UUID()
        draft.testScore = 0
        draft.confirmedLevel = nil
        jumpToTest()
    }

    /// Persist all draft fields to the store.
    private func syncDraftToStore(_ store: UserStateStore) {
        if let level = draft.selectedLevel {
            store.updateSelectedLevel(level)
        }
        if let textbook = draft.selectedTextbook {
            store.updateSelectedTextbook(textbook)
        }
        if let semester = draft.selectedSemester {
            store.updateSelectedSemester(semester)
        }
    }

    /// Commit draft → UserStateStore and finish (skip test path).
    func skipTest(store: UserStateStore) {
        guard let level = draft.selectedLevel else { return }
        syncDraftToStore(store)
        AnalyticsService.shared.trackOnboardingStep("testSkipped")
        AnalyticsService.shared.trackOnboardingCompleted()
        store.completeOnboardingWithoutTest(
            selectedLevel: level,
            textbook: draft.selectedTextbook
        )
    }

    /// Commit draft → UserStateStore and finish (test completed path).
    func completeWithTest(store: UserStateStore) {
        guard let confirmed = draft.confirmedLevel else { return }
        syncDraftToStore(store)
        AnalyticsService.shared.trackOnboardingCompleted()
        AnalyticsService.shared.setUserLevel(confirmed.rawValue)
        store.completeOnboarding(testScore: draft.testScore, confirmedLevel: confirmed)
    }

    /// Restore from an entry point (e.g. "modify goal", "retest")
    func restore(from entry: OnboardingEntry, state: UserState) {
        switch entry {
        case .full:
            break
        case .selectLevel:
            if let idx = pipeline.firstIndex(of: .levelSelect) {
                currentIndex = idx
            }
        case .selectTextbook:
            draft.selectedLevel = state.selectedLevel ?? state.confirmedLevel
            draft.selectedSemester = state.selectedSemester
            if let idx = pipeline.firstIndex(of: .textbookSelect) {
                currentIndex = idx
            } else {
                // textbook step skipped → go to level select
                if let idx = pipeline.firstIndex(of: .levelSelect) {
                    currentIndex = idx
                }
            }
        case .retest:
            if let level = state.selectedLevel ?? state.confirmedLevel {
                draft.selectedLevel = level
                draft.selectedSemester = state.selectedSemester
                draft.selectedTextbook = state.selectedTextbook
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
                    // Header
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

                    // Step content
                    stepView

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            guard !didInitialize else { return }
            didInitialize = true
            coordinator.restore(from: store.onboardingEntry, state: store.userState)
            store.onboardingEntry = .full
        }
    }

    @ViewBuilder
    private var stepView: some View {
        switch coordinator.currentStep {
        case .welcome:
            OnboardingWelcomeView {
                AnalyticsService.shared.trackOnboardingStep("welcome")
                coordinator.goNext()
            }

        case .levelSelect:
            LevelSelectView(coordinator: coordinator) {
                AnalyticsService.shared.trackOnboardingStep("levelSelect")
                if let level = coordinator.draft.selectedLevel {
                    store.updateSelectedLevel(level)
                    AnalyticsService.shared.trackOnboardingLevelSelected(level.rawValue)
                }
                coordinator.goNext()
            } onSkipTest: {
                coordinator.skipTest(store: store)
            }

        case .textbookSelect:
            TextbookSelectView(coordinator: coordinator) {
                AnalyticsService.shared.trackOnboardingStep("textbookSelect")
                if let textbook = coordinator.draft.selectedTextbook {
                    store.updateSelectedTextbook(textbook)
                    AnalyticsService.shared.trackOnboardingTextbookSelected(textbook.rawValue)
                }
                coordinator.goNext()
            } onSkipTest: {
                coordinator.skipTest(store: store)
            }

        case .levelTest:
            if let level = coordinator.draft.selectedLevel {
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
            if let selected = coordinator.draft.selectedLevel {
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
    @State private var index: Int = 0
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            TabView(selection: $index) {
                ForEach(Array(WelcomePage.pages.enumerated()), id: \ .offset) { idx, page in
                    VStack(spacing: 18) {
                        Circle()
                            .fill(page.color.opacity(0.15))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: page.icon)
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(page.color)
                            )
                        Text(page.title)
                            .font(.system(size: 26, weight: .bold))
                        Text(page.body)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .tag(idx)
                    .padding(.top, 20)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 360)

            Button(action: onContinue) {
                Text("开始定级")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(colors: [Color.orange, Color.red],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(14)
            }
        }
    }
}

// MARK: - Level Select (+ semester sheet)

struct LevelSelectView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    let onContinue: () -> Void
    let onSkipTest: () -> Void

    @State private var showSemesterSheet = false

    private var draft: OnboardingDraft { coordinator.draft }

    private var needsSemester: Bool {
        draft.selectedLevel?.gradeNumber != nil
    }

    private var canContinue: Bool {
        guard draft.selectedLevel != nil else { return false }
        if needsSemester && draft.selectedSemester == nil { return false }
        return true
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("请选择孩子目前的学习目标")
                    .font(.system(size: 18, weight: .semibold))

                ForEach(LevelGroup.allCases) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(group.rawValue)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.secondary)

                        ForEach(UserLevel.allCases.filter { $0.group == group }) { level in
                            LevelCard(
                                level: level,
                                isSelected: draft.selectedLevel == level,
                                semesterLabel: semesterLabel(for: level)
                            )
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    coordinator.draft.selectedLevel = level
                                    if level.gradeNumber != nil {
                                        // Pre-fill smart default, then show sheet to confirm
                                        if coordinator.draft.selectedSemester == nil {
                                            coordinator.draft.selectedSemester = Semester.current
                                        }
                                        showSemesterSheet = true
                                    } else {
                                        coordinator.draft.selectedSemester = nil
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

                // "跳过测试" 只在这是测试前最后一页时显示
                if coordinator.isLastBeforeTest && canContinue {
                    Button(action: onSkipTest) {
                        Text("跳过测试，直接开始学习")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(.thinMaterial)
        }
        .sheet(isPresented: $showSemesterSheet) {
            SemesterSheetView(
                levelName: draft.selectedLevel?.rawValue ?? "",
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
        guard draft.selectedLevel == level,
              level.gradeNumber != nil,
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

// MARK: - Textbook Select

struct TextbookSelectView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    let onContinue: () -> Void
    let onSkipTest: () -> Void

    private var draft: OnboardingDraft { coordinator.draft }

    private var availableOptions: [TextbookOption] {
        guard let level = draft.selectedLevel else { return [] }
        return TextbookOption.options(for: level)
    }

    private var recommendedTextbook: TextbookOption? {
        draft.selectedLevel.map { TextbookOption.recommended(for: $0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("请选择教材体系")
                    .font(.system(size: 18, weight: .semibold))

                ForEach(TextbookGroup.allCases) { group in
                    let groupOptions = availableOptions.filter { $0.group == group }
                    if !groupOptions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(group.rawValue)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.secondary)

                            ForEach(groupOptions) { option in
                                TextbookCard(
                                    option: option,
                                    isSelected: draft.selectedTextbook == option,
                                    isRecommended: recommendedTextbook == option
                                )
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        coordinator.draft.selectedTextbook = option
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
                        .background(draft.selectedTextbook == nil ? Color.gray.opacity(0.4) : Color.blue)
                        .cornerRadius(14)
                }
                .disabled(draft.selectedTextbook == nil)

                // 这里一定是测试前最后一页（textbook 存在 = 至少2个选项）
                if draft.selectedTextbook != nil {
                    Button(action: onSkipTest) {
                        Text("跳过测试，直接开始学习")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                    }
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

struct TextbookCard: View {
    let option: TextbookOption
    let isSelected: Bool
    let isRecommended: Bool

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(option.group.color.opacity(0.15))
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: option.group.icon)
                        .foregroundColor(option.group.color)
                        .font(.system(size: 22, weight: .bold))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(option.rawValue)
                    .font(.system(size: 17, weight: .bold))
                Text(option.subtitle)
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
                        .background(option.group.color)
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
                .fill(isSelected ? option.group.color.opacity(0.12) : Color.white)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? option.group.color : Color.clear, lineWidth: 1.5)
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
