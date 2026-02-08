//
//  RootView.swift
//  Volingo
//
//  Created by jacob on 2026/2/8.
//

import SwiftUI

struct RootView: View {
    @StateObject private var store = OnboardingStore()

    var body: some View {
        Group {
            if store.state.isCompleted {
                ContentView()
            } else {
                OnboardingFlowView()
            }
        }
    }
}

#Preview {
    RootView()
}
