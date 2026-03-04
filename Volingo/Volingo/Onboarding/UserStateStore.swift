//
//  UserStateStore.swift
//  海豹英语
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

    // MARK: - New field setters

    func updateGrade(_ grade: UserLevel) {
        userState.grade = grade.apiKey
        // Clear publisher/semester if non-school grade
        if !grade.isSchoolGrade {
            userState.publisher = nil
            userState.semester = nil
        }
        save()
    }

    func updatePublisher(_ publisher: Publisher) {
        userState.publisher = publisher.rawValue
        save()
    }

    func updateSemester(_ semester: Semester) {
        userState.semester = semester.rawValue
        save()
    }

    func updateCurrentUnit(_ unit: Int) {
        userState.currentUnit = unit
        save()
    }

    // MARK: - Onboarding lifecycle

    func completeOnboarding(grade: UserLevel, publisher: Publisher?, semester: Semester?, currentUnit: Int = 1) {
        userState.isOnboardingCompleted = true
        userState.grade = grade.apiKey
        userState.publisher = publisher?.rawValue
        userState.semester = semester?.rawValue
        userState.currentUnit = currentUnit
        onboardingEntry = .full
        save()
    }

    func resetOnboarding() {
        userState.isOnboardingCompleted = false
        userState.grade = nil
        userState.publisher = nil
        userState.semester = nil
        userState.currentUnit = nil
        onboardingEntry = .full
        save()
    }

    func startModifyGoal() {
        onboardingEntry = .selectLevel
        userState.isOnboardingCompleted = false
        userState.grade = nil
        userState.publisher = nil
        userState.semester = nil
        userState.currentUnit = nil
        save()
    }

    func updatePreferences(_ preferences: LearningPreferences) {
        userState.preferences = preferences
        save()
    }

    // MARK: - Cloud sync

    /// Restore state from cloud profile after login.
    /// Returns `true` if onboarding was fully restored (user can skip onboarding).
    @discardableResult
    func restoreFromCloudProfile(_ profile: AuthUserProfile) -> Bool {
        // Cloud must have onboardingCompleted + grade to restore
        guard profile.onboardingCompleted,
              let grade = profile.grade,
              UserLevel.from(apiKey: grade) != nil else {
            return false
        }

        userState.grade = grade
        userState.publisher = profile.publisher
        userState.semester = profile.semester
        userState.currentUnit = profile.currentUnit
        userState.isOnboardingCompleted = true
        save()
        return true
    }

    /// 当前教材编码，用于 API 请求（如 "juniorPEP-7a"）
    var currentTextbookCode: String? {
        userState.textbookCode
    }

    // MARK: - Private

    private func load() {
        if let loaded: UserState = try? StorageService.shared.loadFromFile(UserState.self, filename: storageFile) {
            userState = loaded
        }
    }

    private func save() {
        try? StorageService.shared.saveToFile(userState, filename: storageFile)
    }
}
