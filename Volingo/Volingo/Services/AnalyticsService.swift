//
//  AnalyticsService.swift
//  Volingo
//
//  Created by jacob on 2026/2/15.
//

import Foundation
import FirebaseAnalytics

/// Centralized analytics tracking service.
/// All events are anonymous — no PII collected.
final class AnalyticsService {
    static let shared = AnalyticsService()
    private init() {}
    
    // MARK: - App Lifecycle
    
    func trackAppLaunch(isReturningUser: Bool) {
        Analytics.logEvent("app_launched", parameters: [
            "is_returning_user": isReturningUser
        ])
    }
    
    // MARK: - Onboarding
    
    func trackOnboardingStep(_ step: String) {
        Analytics.logEvent("onboarding_step_viewed", parameters: [
            "step": step
        ])
    }
    
    func trackOnboardingLevelSelected(_ level: String) {
        Analytics.logEvent("onboarding_level_selected", parameters: [
            "level": level
        ])
    }
    
    func trackOnboardingTextbookSelected(_ textbook: String) {
        Analytics.logEvent("onboarding_textbook_selected", parameters: [
            "textbook": textbook
        ])
    }
    
    func trackOnboardingTestCompleted(score: Double, recommendedLevel: String) {
        Analytics.logEvent("onboarding_test_completed", parameters: [
            "score": score,
            "recommended_level": recommendedLevel
        ])
    }
    
    func trackOnboardingCompleted() {
        Analytics.logEvent("onboarding_completed", parameters: nil)
    }
    
    // MARK: - Tab Navigation
    
    func trackTabSwitched(_ tabName: String) {
        Analytics.logEvent("tab_switched", parameters: [
            "tab_name": tabName
        ])
    }
    
    // MARK: - Screen Views
    
    func trackScreenView(_ screenName: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName
        ])
    }
    
    // MARK: - Practice
    
    func trackPracticeStarted(questionType: String, textbookCode: String) {
        Analytics.logEvent("practice_started", parameters: [
            "question_type": questionType,
            "textbook_code": textbookCode
        ])
    }
    
    func trackQuestionAnswered(questionType: String, isCorrect: Bool, textbookCode: String) {
        Analytics.logEvent("question_answered", parameters: [
            "question_type": questionType,
            "correct": isCorrect,
            "textbook_code": textbookCode
        ])
    }
    
    func trackPracticeCompleted(questionType: String, correctCount: Int, totalCount: Int) {
        Analytics.logEvent("practice_completed", parameters: [
            "question_type": questionType,
            "correct_count": correctCount,
            "total_count": totalCount,
            "accuracy": totalCount > 0 ? Double(correctCount) / Double(totalCount) : 0
        ])
    }
    
    // MARK: - Today Package
    
    func trackTodayPackageStarted(textbookCode: String) {
        Analytics.logEvent("today_package_started", parameters: [
            "textbook_code": textbookCode
        ])
    }
    
    func trackTodayPackageItemTapped(questionType: String) {
        Analytics.logEvent("today_package_item_tapped", parameters: [
            "question_type": questionType
        ])
    }
    
    // MARK: - Review
    
    func trackReviewStarted(wordCount: Int) {
        Analytics.logEvent("review_started", parameters: [
            "word_count": wordCount
        ])
    }
    
    func trackReviewCompleted(accuracy: Double, correctCount: Int, totalCount: Int) {
        Analytics.logEvent("review_completed", parameters: [
            "accuracy": accuracy,
            "correct_count": correctCount,
            "total_count": totalCount
        ])
    }
    
    // MARK: - Dictionary
    
    func trackWordSearched(_ word: String) {
        Analytics.logEvent("word_searched", parameters: [
            "word": word
        ])
    }
    
    func trackWordSaved(_ word: String) {
        Analytics.logEvent("word_saved", parameters: [
            "word": word
        ])
    }
    
    // MARK: - Question Report
    
    func trackQuestionReported(questionId: String, reason: String) {
        Analytics.logEvent("question_reported", parameters: [
            "question_id": questionId,
            "reason": reason
        ])
    }
    
    // MARK: - Training Category
    
    func trackTrainingCategoryTapped(_ category: String) {
        Analytics.logEvent("training_category_tapped", parameters: [
            "category": category
        ])
    }
    
    // MARK: - User Properties
    
    func setUserTextbook(_ textbookCode: String) {
        Analytics.setUserProperty(textbookCode, forName: "textbook_code")
    }
    
    func setUserLevel(_ level: String) {
        Analytics.setUserProperty(level, forName: "user_level")
    }
}
