//
//  RootView.swift
//  Volingo
//
//  Created by jacob on 2026/2/8.
//

import SwiftUI

struct RootView: View {
    @StateObject private var store = UserStateStore()

    var body: some View {
        Group {
            if store.userState.isOnboardingCompleted {
                ContentView()
                    .environmentObject(store)
            } else {
                OnboardingFlowView()
                    .environmentObject(store)
            }
        }
    }
}

#Preview {
    RootView()
}
