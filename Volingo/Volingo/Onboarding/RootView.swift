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
                // Auto sign-in in progress
                ProgressView("正在初始化…")
            } else if store.userState.isOnboardingCompleted {
                // Onboarding done → main app
                ContentView()
                    .environmentObject(store)
            } else {
                // Onboarding not done
                OnboardingFlowView()
                    .environmentObject(store)
            }
        }
        .task {
            await authManager.autoSignIn()
        }
        .onAppear {
            AnalyticsService.shared.trackAppLaunch(isReturningUser: store.userState.isOnboardingCompleted)
        }
    }
}

#Preview {
    RootView()
}
