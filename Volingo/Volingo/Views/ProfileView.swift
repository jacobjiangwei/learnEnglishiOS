//
//  ProfileView.swift
//  Volingo
//
//  Created by jacob on 2025/8/10.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var onboardingStore: UserStateStore
    @State private var pendingAction: ProfileAction? = nil

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("当前学习目标")) {
                    HStack {
                        Text("已定级")
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

                    if let score = onboardingStore.userState.lastAssessmentScore {
                        HStack {
                            Text("最近测评")
                            Spacer()
                            Text("正确率 \(Int(score * 100))%")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("学习设置")) {
                    Button("修改学习目标") {
                        pendingAction = .modifyGoal
                    }

                    Button("重新定级测试") {
                        pendingAction = .retest
                    }
                    .foregroundColor(.orange)

                    Button("重新完整设置") {
                        pendingAction = .fullReset
                    }
                    .foregroundColor(.red)
                }

                Section(header: Text("账号")) {
                    Text("游客模式")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("我的")
            .alert(item: $pendingAction) { action in
                switch action {
                case .modifyGoal:
                    return Alert(
                        title: Text("修改学习目标?"),
                        message: Text("将重新选择等级与教材，不会进入测试。"),
                        primaryButton: .destructive(Text("确认"), action: {
                            onboardingStore.startModifyGoal()
                        }),
                        secondaryButton: .cancel(Text("取消"))
                    )
                case .retest:
                    return Alert(
                        title: Text("重新定级测试?"),
                        message: Text("将保留教材选择，并直接进入测试。"),
                        primaryButton: .destructive(Text("确认"), action: {
                            onboardingStore.startRetest(keepTextbook: true)
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
    }

    private var currentLevelLabel: String {
        if let level = onboardingStore.userState.confirmedLevel {
            return level.rawValue
        }
        if let selected = onboardingStore.userState.selectedLevel {
            return selected.rawValue
        }
        return "未定级"
    }

    private var currentTextbookLabel: String {
        if let textbook = onboardingStore.userState.selectedTextbook {
            return textbook.rawValue
        }
        return "未选择"
    }
}

private enum ProfileAction: String, Identifiable {
    case modifyGoal
    case retest
    case fullReset

    var id: String { rawValue }
}

#Preview {
    ProfileView()
}
