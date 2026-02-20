import Foundation
import SwiftUI

// MARK: - 词典 ViewModel
class DictionaryViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [Word] = []
    @Published var suggestions: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedWord: Word?
    @Published var savedWordIds: Set<String> = []
    @Published var wordbookStats = WordbookStats(
        totalWords: 0, needReviewCount: 0,
        newWords: 0, learningWords: 0, reviewingWords: 0, masteredWords: 0
    )
    
    private let dictionaryService = DictionaryService.shared
    private let autocompleteService = AutocompleteService.shared
    
    init() {
        loadSavedWordIds()
        refreshWordbookStats()
    }
    
    // MARK: - 自动补全
    
    /// 根据当前输入更新建议列表
    func updateSuggestions() {
        // 正在加载或已有选中词时不显示建议
        guard selectedWord == nil, !isLoading else {
            suggestions = []
            return
        }
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            suggestions = []
            return
        }
        suggestions = autocompleteService.suggestions(for: text, limit: 8)
    }
    
    /// 选中某个建议词，触发查词
    func selectSuggestion(_ word: String) {
        searchText = word
        suggestions = []
        searchWord(word)
    }
    
    /// 刷新生词本统计
    func refreshWordbookStats() {
        do {
            wordbookStats = try WordbookService.shared.getWordbookStats()
            loadSavedWordIds()
        } catch {
            print("刷新生词本统计失败: \(error)")
        }
    }
    
    // MARK: - 搜索功能
    
    /// 执行单词搜索
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
                    self.suggestions = []
                    // 只有一个结果时自动展示详情并加入生词本
                    if let word = results.first, results.count == 1 {
                        self.selectedWord = word
                        if !self.isWordInWordbook(word) {
                            self.addToWordbook(word)
                        }
                    }
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
    
    /// 获取单词详细信息
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
    
    // MARK: - 生词本操作
    
    /// 添加到生词本
    func addToWordbook(_ word: Word) {
        do {
            try WordbookService.shared.addWordFromDictionary(word)
            savedWordIds.insert(word.word.lowercased())
            refreshWordbookStats()
        } catch {
            errorMessage = "添加到生词本失败: \(error.localizedDescription)"
        }
    }
    
    /// 从生词本移除
    func removeFromWordbook(_ word: Word) {
        do {
            let savedWords = try WordbookService.shared.loadSavedWords()
            if let savedWord = savedWords.first(where: { $0.word.word.lowercased() == word.word.lowercased() }) {
                try WordbookService.shared.deleteWord(savedWord.id)
                savedWordIds.remove(word.word.lowercased())
                refreshWordbookStats()
            }
        } catch {
            errorMessage = "从生词本移除失败: \(error.localizedDescription)"
        }
    }
    
    /// 检查单词是否已在生词本中
    func isWordInWordbook(_ word: Word) -> Bool {
        return savedWordIds.contains(word.word.lowercased())
    }
    
    // MARK: - 私有方法
    
    /// 加载已保存的单词ID
    private func loadSavedWordIds() {
        do {
            let savedWords = try WordbookService.shared.loadSavedWords()
            savedWordIds = Set(savedWords.map { $0.word.word.lowercased() })
        } catch {
            print("加载生词本失败: \(error)")
        }
    }
    
    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }
}