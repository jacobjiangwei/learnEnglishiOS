//
//  OnboardingStore.swift
//  Volingo
//
//  Created by jacob on 2026/2/8.
//

import Foundation
import SwiftUI

final class OnboardingStore: ObservableObject {
    @Published private(set) var state: OnboardingState = OnboardingState()
    private let storageFile = "onboarding_state.json"

    init() {
        load()
    }

    func updateSelectedLevel(_ level: UserLevel) {
        state.selectedLevel = level
        save()
    }

    func complete(testScore: Double, confirmedLevel: UserLevel) {
        state.isCompleted = true
        state.testScore = testScore
        state.confirmedLevel = confirmedLevel
        state.completedAt = Date()
        save()
    }

    func reset() {
        state = OnboardingState()
        save()
    }

    private func load() {
        if let loaded: OnboardingState = try? StorageService.shared.loadFromFile(OnboardingState.self, filename: storageFile) {
            state = loaded
        }
    }

    private func save() {
        try? StorageService.shared.saveToFile(state, filename: storageFile)
    }
}
