//
//  ProfileView.swift
//  Volingo
//
//  Created by jacob on 2025/8/10.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var onboardingStore: UserStateStore
    @State private var showResetAlert = false

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
                        showResetAlert = true
                    }

                    Button("重新定级测试") {
                        showResetAlert = true
                    }
                    .foregroundColor(.orange)
                }

                Section(header: Text("账号")) {
                    Text("游客模式")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("我的")
            .alert("重新定级?", isPresented: $showResetAlert) {
                Button("取消", role: .cancel) {}
                Button("确认", role: .destructive) {
                    onboardingStore.resetOnboarding()
                }
            } message: {
                Text("将重新进入 Onboarding 并进行等级测试。")
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
}

#Preview {
    ProfileView()
}
