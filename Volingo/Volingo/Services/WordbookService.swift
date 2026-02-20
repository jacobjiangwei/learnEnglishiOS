import Foundation

class WordbookService {
    static let shared = WordbookService()
    private init() {}
    
    // MARK: - CRUD
    
    func loadSavedWords() throws -> [SavedWord] {
        do {
            return try StorageService.shared.loadFromFile([SavedWord].self, filename: "savedWords.json")
        } catch {
            return []
        }
    }
    
    func addWordFromDictionary(_ word: Word) throws {
        var words = try loadSavedWords()
        guard !words.contains(where: { $0.word.word.lowercased() == word.word.lowercased() }) else { return }
        words.append(SavedWord(from: word))
        try StorageService.shared.saveToFile(words, filename: "savedWords.json")
    }
    
    func deleteWord(_ wordId: String) throws {
        var words = try loadSavedWords()
        words.removeAll { $0.id == wordId }
        try StorageService.shared.saveToFile(words, filename: "savedWords.json")
    }
    
    // MARK: - FSRS 复习
    
    /// 获取今日待复习词列表（FSRS 调度）
    func getWordsToReview() throws -> [SavedWord] {
        let allWords = try loadSavedWords()
        let reviewable = FSRSEngine.getWordsToReview(from: allWords)
        return reviewable.compactMap { $0 as? SavedWord }
    }
    
    /// 记录复习结果（FSRS 评分）
    func recordReview(_ wordId: String, rating: FSRSRating) throws {
        var words = try loadSavedWords()
        guard let index = words.firstIndex(where: { $0.id == wordId }) else { return }
        words[index].recordReview(rating: rating)
        try StorageService.shared.saveToFile(words, filename: "savedWords.json")
    }
    
    // MARK: - 统计
    
    func getWordbookStats() throws -> WordbookStats {
        let words = try loadSavedWords()
        let needReview = words.filter { $0.needsReview }.count
        return WordbookStats(totalWords: words.count, needReviewCount: needReview)
    }
}