import Foundation
import SwiftUI

// MARK: - 词典 ViewModel
class DictionaryViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [Word] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedWord: Word?
    @Published var savedWordIds: Set<String> = [] // 保存已收藏单词的ID集合
    
    private let dictionaryService = DictionaryService.shared
    
    init() {
        loadSavedWordIds()
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
            // 可以添加成功提示
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