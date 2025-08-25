import Foundation
import SwiftUI

// MARK: - 生词本 ViewModel
class WordbookViewModel: ObservableObject {
    @Published var savedWords: [SavedWord] = []
    @Published var filteredWords: [SavedWord] = []
    @Published var selectedMasteryDescription: String? = nil
    @Published var searchText = ""
    @Published var showingWordDetail = false
    @Published var selectedWord: SavedWord?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 统计数据
    @Published var wordbookStats: WordbookStats = WordbookStats(
        totalWords: 0,
        needReviewCount: 0,
        newWords: 0,
        learningWords: 0,
        reviewingWords: 0,
        masteredWords: 0
    )
    
    private let wordbookService = WordbookService.shared
    
    init() {
        loadData()
    }
    
    // MARK: - 数据加载
    
    /// 加载生词本数据
    func loadData() {
        isLoading = true
        do {
            savedWords = try wordbookService.loadSavedWords()
            wordbookStats = try wordbookService.getWordbookStats()
            applyFilters()
            isLoading = false
        } catch {
            errorMessage = "加载生词本失败: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// 应用筛选条件
    func applyFilters() {
        var words = savedWords
        
        // 按掌握程度筛选
        if let description = selectedMasteryDescription {
            words = words.filter { $0.masteryDescription == description }
        }
        
        // 按搜索文本筛选
        if !searchText.isEmpty {
            let lowercaseSearch = searchText.lowercased()
            words = words.filter { savedWord in
                savedWord.word.word.lowercased().contains(lowercaseSearch) ||
                savedWord.definition.lowercased().contains(lowercaseSearch)
            }
        }
        
        filteredWords = words.sorted { $0.addedDate > $1.addedDate }
    }
    
    // MARK: - 单词管理
    
    /// 删除单词
    func deleteWord(_ savedWord: SavedWord) {
        do {
            try wordbookService.deleteWord(savedWord.id)
            loadData() // 重新加载数据
        } catch {
            errorMessage = "删除单词失败: \(error.localizedDescription)"
        }
    }
    
    /// 获取推荐复习的单词
    func getRecommendedReviewWords() -> [SavedWord] {
        do {
            return try wordbookService.getRecommendedReviewWords(limit: 20)
        } catch {
            return []
        }
    }
    
    /// 记录学习结果
    func recordLearningResult(wordId: String, isCorrect: Bool) {
        do {
            let result = LearningResult(
                type: isCorrect ? .correct : .incorrect,
                responseTime: 0, // 暂时设为0，后续可以记录实际响应时间
                timestamp: Date()
            )
            try wordbookService.recordLearningResult(wordId, result: result)
            loadData() // 重新加载以更新统计信息
        } catch {
            errorMessage = "记录学习结果失败: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 工具方法
    
    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }
    
    /// 获取按掌握程度分组的单词
    func getWordsByMasteryDescription() -> [String: [SavedWord]] {
        return Dictionary(grouping: savedWords) { $0.masteryDescription }
    }
    
    /// 刷新数据（用于从其他页面返回时更新）
    func refreshData() {
        loadData()
    }
}