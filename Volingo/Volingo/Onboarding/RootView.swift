//
//  RootView.swift
//  海豹英语
//
//  Created by jacob on 2026/2/8.
//

import SwiftUI

struct RootView: View {
    @StateObject private var store = UserStateStore()
    @StateObject private var authManager = AuthManager.shared

    var body: some View {
        Group {
            if authManager.isLoading {
                ProgressView("正在初始化…")
            } else if !authManager.isAuthenticated && store.userState.isOnboardingCompleted {
                // Email user token lost → prompt re-login
                EmailLoginView {
                    Task { await restoreFromCloudIfNeeded() }
                }
            } else if store.userState.isOnboardingCompleted {
                ContentView()
                    .environmentObject(store)
            } else {
                OnboardingFlowView()
                    .environmentObject(store)
            }
        }
        .task {
            // signIn() handles all auth paths:
            //   - Token valid (>7d) → isAuthenticated=true, currentUser may be nil (trust local)
            //   - Token refreshed  → isAuthenticated=true, currentUser populated from response
            //   - Device sign-in   → isAuthenticated=true, currentUser populated from response
            //   - Email user lost  → isAuthenticated=false, wait for manual re-login
            await authManager.signIn()

            // Only case we need cloud data: local has no onboarding, but cloud might.
            // This handles new device / reinstall for email users.
            await restoreFromCloudIfNeeded()
        }
        .onAppear {
            AnalyticsService.shared.trackAppLaunch(isReturningUser: store.userState.isOnboardingCompleted)
        }
    }

    /// If local has no onboarding but signIn returned a profile with onboarding done → restore.
    /// No extra network request needed — signIn already populated currentUser.
    private func restoreFromCloudIfNeeded() async {
        guard authManager.isAuthenticated,
              !store.userState.isOnboardingCompleted,
              let profile = authManager.currentUser,
              profile.onboardingCompleted else { return }

        let restored = store.restoreFromCloudProfile(profile)
        print("[RootView] 从云端恢复 onboarding: \(restored ? "成功" : "失败")")
    }
}

#Preview {
    RootView()
}
