//
//  ViewModels.swift
//  Volingo
//
//  Created by jacob on 2025/8/10.
//

import Foundation
import SwiftUI

// MARK: - 词典 ViewModel
class DictionaryViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [Word] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedWord: Word?
    @Published var savedWordIds: Set<String> = [] // 新增：保存已收藏单词的ID集合
    
    private let dictionaryService = DictionaryService.shared
    
    init() {
        loadSavedWordIds()
    }
    
    // 执行单词搜索
    func searchWord(_ query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let results = try await dictionaryService.searchWord(query)
                
                await MainActor.run {
                    self.searchResults = results
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.searchResults = []
                    self.isLoading = false
                }
            }
        }
    }
    
    // 获取单词详细信息
    func getWordDetails(_ word: String) {
        Task {
            do {
                let wordDetails = try await dictionaryService.getWordDetails(word)
                
                await MainActor.run {
                    self.selectedWord = wordDetails
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // 添加到生词本
    func addToWordbook(_ word: Word) {
        do {
            try WordbookService.shared.addWordFromDictionary(word)
            savedWordIds.insert(word.word.lowercased())
            // 可以添加成功提示
        } catch {
            errorMessage = "添加到生词本失败: \(error.localizedDescription)"
        }
    }
    
    // 从生词本移除
    func removeFromWordbook(_ word: Word) {
        do {
            let savedWords = try WordbookService.shared.loadSavedWords()
            if let savedWord = savedWords.first(where: { $0.word.word.lowercased() == word.word.lowercased() }) {
                try WordbookService.shared.deleteWord(savedWord.id)
                savedWordIds.remove(word.word.lowercased())
            }
        } catch {
            errorMessage = "从生词本移除失败: \(error.localizedDescription)"
        }
    }
    
    // 检查单词是否已在生词本中
    func isWordInWordbook(_ word: Word) -> Bool {
        return savedWordIds.contains(word.word.lowercased())
    }
    
    // 加载已保存的单词ID
    private func loadSavedWordIds() {
        do {
            let savedWords = try WordbookService.shared.loadSavedWords()
            savedWordIds = Set(savedWords.map { $0.word.word.lowercased() })
        } catch {
            print("加载生词本失败: \(error)")
        }
    }
    
    // 清除错误信息
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - 生词本 ViewModel
class WordbookViewModel: ObservableObject {
    @Published var savedWords: [SavedWord] = []
    @Published var todayReviewWords: [SavedWord] = []
    @Published var studyProgress: StudyProgress = StudyProgress()
    
    // TODO: 实现生词本管理逻辑
    func loadSavedWords() {
        // 加载生词本
    }
    
    func updateMasteryLevel(_ wordId: String, level: MasteryLevel) {
        // 更新掌握程度
    }
    
    func getTodayReviewList() -> [SavedWord] {
        // 获取今日复习列表
        return []
    }
}

struct StudyProgress {
    var totalWords: Int = 0
    var masteredWords: Int = 0
    var currentStreak: Int = 0
}

// MARK: - 情景对话 ViewModel
class ScenarioViewModel: ObservableObject {
    @Published var scenarios: [Scenario] = []
    @Published var currentScenario: Scenario?
    @Published var isPlaying = false
    @Published var currentDialogueIndex = 0
    
    // TODO: 实现情景对话逻辑
    func loadScenarios() {
        // 加载情景对话数据
    }
    
    func playDialogue(_ dialogue: Dialogue) {
        // 播放对话音频
    }
    
    func startRecording() {
        // 开始录音
    }
    
    func stopRecording() {
        // 停止录音并发送评分
    }
}

// MARK: - 写作训练 ViewModel
class WritingViewModel: ObservableObject {
    @Published var currentExercise: WritingExercise?
    @Published var userInput = ""
    @Published var feedback: [WritingFeedback] = []
    @Published var isAnalyzing = false
    
    // TODO: 实现写作训练逻辑
    func startNewExercise(prompt: String) {
        // 开始新的写作练习
    }
    
    func analyzeText(_ text: String) {
        // 分析文本并提供反馈
    }
    
    func applyFeedback(_ feedback: WritingFeedback) {
        // 应用写作建议
    }
}

// MARK: - 用户 ViewModel
class ProfileViewModel: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var isLoggedIn = false
    @Published var learningStats: LearningStats = LearningStats()
    
    // TODO: 实现用户管理逻辑
    func signIn() {
        // Sign in with Apple
    }
    
    func signOut() {
        // 登出
    }
    
    func updateLearningGoal(_ goal: LearningGoal) {
        // 更新学习目标
    }
    
    func loadLearningStats() {
        // 加载学习统计
    }
}

struct LearningStats {
    var totalStudyDays: Int = 0
    var totalWordsLearned: Int = 0
    var averageSessionTime: TimeInterval = 0
    var weeklyProgress: [Int] = Array(repeating: 0, count: 7)
}
