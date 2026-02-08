//
//  UserStateStore.swift
//  Volingo
//
//  Created by jacob on 2026/2/8.
//

import Foundation
import SwiftUI

final class UserStateStore: ObservableObject {
    @Published private(set) var userState: UserState = UserState()
    private let storageFile = "user_state.json"

    init() {
        load()
    }

    func updateSelectedLevel(_ level: UserLevel) {
        userState.selectedLevel = level
        save()
    }

    func completeOnboarding(testScore: Double, confirmedLevel: UserLevel) {
        userState.isOnboardingCompleted = true
        userState.lastAssessmentScore = testScore
        userState.confirmedLevel = confirmedLevel
        userState.lastAssessmentAt = Date()
        save()
    }

    func resetOnboarding() {
        userState.isOnboardingCompleted = false
        userState.selectedLevel = nil
        userState.confirmedLevel = nil
        userState.lastAssessmentScore = nil
        userState.lastAssessmentAt = nil
        save()
    }

    func updatePreferences(_ preferences: LearningPreferences) {
        userState.preferences = preferences
        save()
    }

    private func load() {
        if let loaded: UserState = try? StorageService.shared.loadFromFile(UserState.self, filename: storageFile) {
            userState = loaded
        }
    }

    private func save() {
        try? StorageService.shared.saveToFile(userState, filename: storageFile)
    }
}
