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
    @Published var onboardingEntry: OnboardingEntry = .full
    private let storageFile = "user_state.json"

    init() {
        load()
    }

    func updateSelectedLevel(_ level: UserLevel) {
        userState.selectedLevel = level
        save()
    }

    func updateSelectedTextbook(_ textbook: TextbookOption) {
        userState.selectedTextbook = textbook
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
        userState.selectedTextbook = nil
        userState.selectedSemester = nil
        userState.confirmedLevel = nil
        userState.lastAssessmentScore = nil
        userState.lastAssessmentAt = nil
        onboardingEntry = .full
        save()
    }

    func startModifyGoal() {
        onboardingEntry = .selectLevel
        userState.isOnboardingCompleted = false
        userState.selectedLevel = nil
        userState.selectedTextbook = nil
        userState.selectedSemester = nil
        userState.confirmedLevel = nil
        userState.lastAssessmentScore = nil
        userState.lastAssessmentAt = nil
        save()
    }

    func startRetest(keepTextbook: Bool = true) {
        onboardingEntry = .retest
        userState.isOnboardingCompleted = false
        if let confirmed = userState.confirmedLevel {
            userState.selectedLevel = confirmed
        }
        if !keepTextbook {
            userState.selectedTextbook = nil
        }
        userState.confirmedLevel = nil
        userState.lastAssessmentScore = nil
        userState.lastAssessmentAt = nil
        save()
    }

    func completeOnboardingWithoutTest(selectedLevel: UserLevel, textbook: TextbookOption?) {
        userState.isOnboardingCompleted = true
        userState.selectedLevel = selectedLevel
        userState.confirmedLevel = selectedLevel
        userState.selectedTextbook = textbook
        userState.lastAssessmentScore = nil
        userState.lastAssessmentAt = nil
        onboardingEntry = .full
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

    func updateSelectedSemester(_ semester: Semester) {
        userState.selectedSemester = semester
        save()
    }

    /// 当前教材编码，用于 API 请求（如 "juniorPEP-7a"）
    var currentTextbookCode: String? {
        guard let textbook = userState.selectedTextbook,
              let level = userState.confirmedLevel ?? userState.selectedLevel else {
            return userState.selectedTextbook?.seriesCode
        }
        let term = userState.selectedSemester ?? .first
        return textbook.code(for: level, term: term)
    }
}
