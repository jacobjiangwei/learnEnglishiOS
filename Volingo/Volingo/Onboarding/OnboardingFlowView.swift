//
//  OnboardingFlowView.swift
//  Volingo
//
//  Created by jacob on 2026/2/8.
//

import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject private var store: UserStateStore
    @State private var step: OnboardingStep = .welcome
    @State private var selectedLevel: UserLevel? = nil
    @State private var selectedTextbook: TextbookOption? = nil
    @State private var testScore: Double = 0
    @State private var confirmedLevel: UserLevel? = nil
    @State private var attemptId = UUID()
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
                    stepHeader

                    Spacer(minLength: 16)

                    switch step {
                    case .welcome:
                        OnboardingWelcomeView { step = .levelSelect }
                    case .levelSelect:
                        LevelSelectView(selectedLevel: $selectedLevel) {
                            if let selectedLevel {
                                store.updateSelectedLevel(selectedLevel)
                                selectedTextbook = TextbookOption.recommended(for: selectedLevel)
                                attemptId = UUID()
                                step = .textbookSelect
                            }
                        }
                    case .textbookSelect:
                        TextbookSelectView(
                            selectedTextbook: $selectedTextbook,
                            recommendedTextbook: selectedLevel.map { TextbookOption.recommended(for: $0) },
                            onContinue: {
                            if let selectedTextbook, let selectedLevel {
                                if store.onboardingSkipTest {
                                    store.completeOnboardingWithoutTest(selectedLevel: selectedLevel, textbook: selectedTextbook)
                                } else {
                                    store.updateSelectedTextbook(selectedTextbook)
                                    attemptId = UUID()
                                    step = .levelTest
                                }
                            }
                        },
                            availableOptions: selectedLevel.map { TextbookOption.options(for: $0) } ?? []
                        )
                    case .levelTest:
                        if let selectedLevel {
                            LevelTestView(level: selectedLevel, attemptId: attemptId) { score, recommended in
                                testScore = score
                                confirmedLevel = recommended
                                step = .result
                            }
                        }
                    case .result:
                        OnboardingResultView(
                            selectedLevel: selectedLevel,
                            confirmedLevel: confirmedLevel,
                            score: testScore,
                            onConfirm: {
                                if let confirmedLevel {
                                    store.completeOnboarding(testScore: testScore, confirmedLevel: confirmedLevel)
                                }
                            },
                            onRetest: {
                                attemptId = UUID()
                                step = .levelTest
                            },
                            onDowngrade: { downgrade in
                                selectedLevel = downgrade
                                store.updateSelectedLevel(downgrade)
                                attemptId = UUID()
                                step = .levelTest
                            }
                        )
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            guard !didInitialize else { return }
            didInitialize = true

            switch store.onboardingEntry {
            case .full:
                break
            case .selectLevel:
                step = .levelSelect
            case .selectTextbook:
                step = .textbookSelect
            case .retest:
                if let level = store.userState.selectedLevel ?? store.userState.confirmedLevel {
                    selectedLevel = level
                    selectedTextbook = store.userState.selectedTextbook
                    attemptId = UUID()
                    step = .levelTest
                } else {
                    step = .levelSelect
                }
            }

            store.onboardingEntry = .full
        }
    }

    private var stepHeader: some View {
        HStack {
            Text(step.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            Spacer()
            Text(step.stepHint)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.top, 16)
    }
}

enum OnboardingStep {
    case welcome
    case levelSelect
    case textbookSelect
    case levelTest
    case result

    var title: String {
        switch self {
        case .welcome:     return "开启学习之旅"
        case .levelSelect: return "选择学习等级"
        case .textbookSelect: return "选择教材体系"
        case .levelTest:   return "智能定级测试"
        case .result:      return "测试结果"
        }
    }

    var stepHint: String {
        switch self {
        case .welcome:        return "1/5"
        case .levelSelect:    return "2/5"
        case .textbookSelect: return "3/5"
        case .levelTest:      return "4/5"
        case .result:         return "5/5"
        }
    }
}

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
                        LinearGradient(colors: [Color.orange, Color.red], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(14)
            }
        }
    }
}

struct LevelSelectView: View {
    @Binding var selectedLevel: UserLevel?
    let onContinue: () -> Void

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
                            LevelCard(level: level, isSelected: selectedLevel == level)
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        selectedLevel = level
                                    }
                                }
                        }
                    }
                }

                Button(action: onContinue) {
                    Text("进入测试")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(selectedLevel == nil ? Color.gray.opacity(0.4) : Color.blue)
                        .cornerRadius(14)
                }
                .disabled(selectedLevel == nil)
            }
        }
    }
}

struct TextbookSelectView: View {
    @Binding var selectedTextbook: TextbookOption?
    let recommendedTextbook: TextbookOption?
    let onContinue: () -> Void
    let availableOptions: [TextbookOption]

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
                                    isSelected: selectedTextbook == option,
                                    isRecommended: recommendedTextbook == option
                                )
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        selectedTextbook = option
                                    }
                                }
                            }
                        }
                    }
                }

                Button(action: onContinue) {
                    Text("进入测试")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(selectedTextbook == nil ? Color.gray.opacity(0.4) : Color.blue)
                        .cornerRadius(14)
                }
                .disabled(selectedTextbook == nil)
            }
        }
    }
}

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
                Text(level.rawValue)
                    .font(.system(size: 17, weight: .bold))
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

struct OnboardingResultView: View {
    let selectedLevel: UserLevel?
    let confirmedLevel: UserLevel?
    let score: Double
    let onConfirm: () -> Void
    let onRetest: () -> Void
    let onDowngrade: (UserLevel) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Circle()
                .fill(Color.green.opacity(0.15))
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.green)
                )

            Text("测试完成")
                .font(.system(size: 26, weight: .bold))

            Text("正确率 \(Int(score * 100))%")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.secondary)

            if let confirmedLevel {
                VStack(spacing: 8) {
                    Text("建议等级")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text(confirmedLevel.rawValue)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(confirmedLevel.color)
                }
            }

            Button(action: onConfirm) {
                Text("确认等级并开始学习")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.green)
                    .cornerRadius(14)
            }

            if let selectedLevel, let fallback = selectedLevel.fallbackLevel {
                Button(action: { onDowngrade(fallback) }) {
                    Text("觉得难? 降级到 \(fallback.rawValue)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(12)
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
                            let recommended = recommendedLevel(for: viewModel.score, selected: viewModel.level)
                            onComplete(viewModel.score, recommended)
                        }
                    }
                }) {
                    Text(viewModel.selectedOptionIndex == nil ? "请选择一个答案" : "下一题")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(viewModel.selectedOptionIndex == nil ? Color.gray.opacity(0.4) : Color.blue)
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
        if score >= selected.passThreshold { return selected }
        return selected.fallbackLevel ?? selected
    }
}

struct OptionRow: View {
    enum State {
        case idle
        case correct
        case incorrect
    }

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
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var backgroundColor: Color {
        switch state {
        case .idle:
            return Color.white
        case .correct:
            return Color.green.opacity(0.12)
        case .incorrect:
            return Color.red.opacity(0.12)
        }
    }

    private var borderColor: Color {
        switch state {
        case .idle:
            return Color.gray.opacity(0.2)
        case .correct:
            return Color.green
        case .incorrect:
            return Color.red
        }
    }
}

#Preview {
    OnboardingFlowView()
}
