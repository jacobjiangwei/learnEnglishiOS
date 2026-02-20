import Foundation
import SwiftUI

// MARK: - 生词本 ViewModel
class WordbookViewModel: ObservableObject {
    @Published var savedWords: [SavedWord] = []
    @Published var filteredWords: [SavedWord] = []
    @Published var searchText = ""
    @Published var showingWordDetail = false
    @Published var selectedWord: SavedWord?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 统计数据
    @Published var wordbookStats: WordbookStats = WordbookStats(totalWords: 0, needReviewCount: 0)
    
    private let wordbookService = WordbookService.shared
    
    init() {
        loadData()
    }
    
    // MARK: - 数据加载
    
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
    
    func applyFilters() {
        var words = savedWords
        
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
    
    func deleteWord(_ savedWord: SavedWord) {
        do {
            try wordbookService.deleteWord(savedWord.id)
            loadData()
        } catch {
            errorMessage = "删除单词失败: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 工具方法
    
    func clearError() {
        errorMessage = nil
    }
    
    func refreshData() {
        loadData()
    }
}