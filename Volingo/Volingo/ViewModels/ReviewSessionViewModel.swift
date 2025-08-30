//
//  ReviewSessionViewModel.swift
//  Volingo
//
//  Created by jacob on 2025/8/30.
//

import Foundation
import SwiftUI

// MARK: - 复习结果数据结构
struct ReviewResults {
    let totalWords: Int
    let correctCount: Int
    let wrongCount: Int
    let skippedCount: Int
    
    var accuracy: Double {
        let attempted = correctCount + wrongCount
        guard attempted > 0 else { return 0 }
        return Double(correctCount) / Double(attempted)
    }
}

// MARK: - 复习会话 ViewModel
@MainActor
class ReviewSessionViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentIndex = 0
    @Published var isLoading = false
    @Published var hasAnswered = false
    @Published var reviewResults = ReviewResults(totalWords: 0, correctCount: 0, wrongCount: 0, skippedCount: 0)
    
    // MARK: - Private Properties
    private var wordsToReview: [SavedWord] = []
    private var answers: [String: Bool] = [:] // wordId -> isCorrect
    private var skipped: Set<String> = [] // wordId set
    private let wordbookService = WordbookService.shared
    
    // MARK: - Computed Properties
    var totalWords: Int {
        wordsToReview.count
    }
    
    var hasWords: Bool {
        currentIndex < totalWords
    }
    
    var currentWord: SavedWord? {
        guard hasWords else { return nil }
        return wordsToReview[currentIndex]
    }
    
    // MARK: - Initialization
    init(words: [SavedWord]) {
        self.wordsToReview = words
    }
    
    // MARK: - Public Methods
    
    /// 开始复习会话
    func startReview() {
        isLoading = true
        
        // 获取需要复习的单词
        do {
            wordsToReview = try getWordsForReview()
            isLoading = false
        } catch {
            print("获取复习单词失败: \(error)")
            wordsToReview = []
            isLoading = false
        }
        
        resetSession()
    }
    
    /// 回答当前单词
    func answerCurrentWord(isCorrect: Bool) {
        guard let word = currentWord else { return }
        
        answers[word.id] = isCorrect
        hasAnswered = true
        
        // 记录学习结果到服务
        recordLearningResult(wordId: word.id, isCorrect: isCorrect)
    }
    
    /// 跳过当前单词
    func skipCurrentWord() {
        guard let word = currentWord else { return }
        
        skipped.insert(word.id)
        moveToNext()
    }
    
    /// 移动到下一个单词
    func moveToNext() {
        currentIndex += 1
        hasAnswered = false
        
        // 如果复习完成，计算结果
        if !hasWords {
            calculateResults()
        }
    }
    
    /// 重新开始复习
    func restart() {
        resetSession()
        startReview()
    }
    
    // MARK: - Private Methods
    
    /// 重置会话状态
    private func resetSession() {
        currentIndex = 0
        hasAnswered = false
        answers.removeAll()
        skipped.removeAll()
        reviewResults = ReviewResults(totalWords: 0, correctCount: 0, wrongCount: 0, skippedCount: 0)
    }
    
    /// 获取需要复习的单词列表
    private func getWordsForReview() throws -> [SavedWord] {
        let allWords = try wordbookService.loadSavedWords()
        
        // 按照优先级筛选复习单词
        let selectedWords = selectWordsForReview(from: allWords)
        
        // 打乱顺序，让复习更有挑战性
        return selectedWords.shuffled()
    }
    
    /// 复习单词筛选逻辑
    private func selectWordsForReview(from allWords: [SavedWord]) -> [SavedWord] {
        let now = Date()
        var reviewWords: [SavedWord] = []
        
        // 1. 新词全部包含 (level 0-2，即"新词"状态)
        let newWords = allWords.filter { $0.masteryDescription == "新词" }
        reviewWords.append(contentsOf: newWords)
        
        // 2. 其他词按时间和熟悉程度筛选
        let otherWords = allWords.filter { $0.masteryDescription != "新词" }
        
        for word in otherWords {
            if shouldIncludeInReview(word: word, currentTime: now) {
                reviewWords.append(word)
            }
        }
        
        // 3. 按优先级排序
        reviewWords.sort { word1, word2 in
            // 新词优先级最高
            if word1.masteryDescription == "新词" && word2.masteryDescription != "新词" {
                return true
            }
            if word2.masteryDescription == "新词" && word1.masteryDescription != "新词" {
                return false
            }
            
            // 其他词按 level 排序，level 越小越优先
            return word1.level < word2.level
        }
        
        // 4. 限制复习数量，避免过载
        let maxReviewCount = calculateOptimalReviewCount(totalWords: allWords.count)
        return Array(reviewWords.prefix(maxReviewCount))
    }
    
    /// 判断单词是否应该包含在这次复习中
    private func shouldIncludeInReview(word: SavedWord, currentTime: Date) -> Bool {
        // 1. 检查是否到了复习时间
        if word.needsReview {
            return true
        }
        
        // 2. 对于学习中的词，给一些额外的复习机会
        if word.masteryDescription == "学习中" {
            // 如果距离添加时间较短，增加复习频率
            let daysSinceAdded = currentTime.timeIntervalSince(word.addedDate) / (24 * 60 * 60)
            if daysSinceAdded <= 7 && word.level <= 4 {
                // 一周内的学习中单词，有一定概率被选中
                return Double.random(in: 0...1) < 0.3
            }
        }
        
        // 3. 对于熟悉程度不够的词，增加复习频率
        if word.totalReviews > 0 {
            let correctRate = Double(word.correctCount) / Double(word.totalReviews)
            if correctRate < 0.7 {
                // 正确率低于70%的词，增加复习概率
                return Double.random(in: 0...1) < 0.4
            }
        }
        
        return false
    }
    
    /// 计算最佳复习数量
    private func calculateOptimalReviewCount(totalWords: Int) -> Int {
        switch totalWords {
        case 0...20:
            return totalWords // 单词少时全部复习
        case 21...50:
            return min(25, totalWords)
        case 51...100:
            return min(30, totalWords)
        default:
            return min(40, totalWords) // 最多40个词，避免复习疲劳
        }
    }
    
    /// 记录学习结果
    private func recordLearningResult(wordId: String, isCorrect: Bool) {
        do {
            let result = LearningResult(
                type: isCorrect ? .correct : .incorrect,
                responseTime: 0, // TODO: 可以记录实际答题时间
                timestamp: Date()
            )
            try wordbookService.recordLearningResult(wordId, result: result)
        } catch {
            print("记录学习结果失败: \(error)")
        }
    }
    
    /// 计算复习结果
    private func calculateResults() {
        let correctCount = answers.values.filter { $0 }.count
        let wrongCount = answers.values.filter { !$0 }.count
        let skippedCount = skipped.count
        
        reviewResults = ReviewResults(
            totalWords: totalWords,
            correctCount: correctCount,
            wrongCount: wrongCount,
            skippedCount: skippedCount
        )
    }
}

// MARK: - 复习策略扩展
extension ReviewSessionViewModel {
    
    /// 智能复习推荐
    /// 基于用户的学习模式和单词状态，动态调整复习策略
    func getSmartReviewRecommendation() -> ReviewRecommendation {
        do {
            let allWords = try wordbookService.loadSavedWords()
            let selectedWords = selectWordsForReview(from: allWords)
            
            let newWordsCount = selectedWords.filter { $0.masteryDescription == "新词" }.count
            let reviewWordsCount = selectedWords.count - newWordsCount
            
            let estimatedMinutes = calculateEstimatedTime(wordCount: selectedWords.count)
            
            return ReviewRecommendation(
                totalWords: selectedWords.count,
                newWords: newWordsCount,
                reviewWords: reviewWordsCount,
                estimatedMinutes: estimatedMinutes,
                difficulty: calculateDifficulty(for: selectedWords)
            )
        } catch {
            return ReviewRecommendation(totalWords: 0, newWords: 0, reviewWords: 0, estimatedMinutes: 0, difficulty: .easy)
        }
    }
    
    private func calculateEstimatedTime(wordCount: Int) -> Int {
        // 每个单词平均需要30-45秒，包含思考和反馈时间
        return Int(Double(wordCount) * 0.75) // 约45秒每词
    }
    
    private func calculateDifficulty(for words: [SavedWord]) -> ReviewDifficulty {
        let averageLevel = words.reduce(0) { $0 + $1.level } / max(words.count, 1)
        
        switch averageLevel {
        case 0...2: return .easy
        case 3...5: return .medium
        default: return .hard
        }
    }
}

// MARK: - 辅助数据结构
struct ReviewRecommendation {
    let totalWords: Int
    let newWords: Int
    let reviewWords: Int
    let estimatedMinutes: Int
    let difficulty: ReviewDifficulty
}

enum ReviewDifficulty {
    case easy, medium, hard
    
    var description: String {
        switch self {
        case .easy: return "简单"
        case .medium: return "适中"
        case .hard: return "困难"
        }
    }
    
    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
}
