import Foundation

class WordbookService {
    static let shared = WordbookService()
    private init() {}
    
    // MARK: - 基本CRUD操作
    
    /// 加载所有保存的单词
    func loadSavedWords() throws -> [SavedWord] {
        do {
            return try StorageService.shared.loadFromFile([SavedWord].self, filename: "savedWords.json")
        } catch {
            return []
        }
    }
    
    /// 从词典查询结果添加单词到生词本
    func addWordFromDictionary(_ word: Word) throws {
        var words = try loadSavedWords()
        
        // 检查是否已存在
        if (!words.contains(where: { $0.word.word.lowercased() == word.word.lowercased() })) {
            let savedWord = SavedWord(from: word)
            words.append(savedWord)
            try StorageService.shared.saveToFile(words, filename: "savedWords.json")
        }
    }
    
    /// 删除单词
    func deleteWord(_ wordId: String) throws {
        var words = try loadSavedWords()
        words.removeAll { $0.id == wordId }
        try StorageService.shared.saveToFile(words, filename: "savedWords.json")
    }
    

    
    /// 获取推荐复习的单词列表
    func getRecommendedReviewWords(limit: Int = 20) throws -> [SavedWord] {
        let allWords = try loadSavedWords()
        
        // 简化逻辑：按复习紧急程度排序，取前 limit 个
        return allWords
            .filter { $0.needsReview }
            .sorted { $0.reviewUrgency > $1.reviewUrgency }
            .prefix(limit)
            .map { $0 }
    }
    
    /// 记录学习结果
    func recordLearningResult(_ wordId: String, result: LearningResult) throws {
        var words = try loadSavedWords()
        guard let index = words.firstIndex(where: { $0.id == wordId }) else { return }
        
        var word = words[index]
        
        // 使用新的API记录结果
        switch result.type {
        case .correct:
            word.recordCorrect()
        case .incorrect:
            word.recordWrong()
        case .skipped:
            // 跳过不计入正确/错误
            break
        }
        
        words[index] = word
        try StorageService.shared.saveToFile(words, filename: "savedWords.json")
    }
    
    // MARK: - 统计和分析
    
    /// 获取生词本统计信息
    func getWordbookStats() throws -> WordbookStats {
        let words = try loadSavedWords()
        let needReview = words.filter { $0.needsReview }.count
        
        // 基于level分组统计
        let levelDistribution = Dictionary(grouping: words) { word in
            word.masteryDescription
        }
        
        return WordbookStats(
            totalWords: words.count,
            needReviewCount: needReview,
            newWords: levelDistribution["新词"]?.count ?? 0,
            learningWords: levelDistribution["学习中"]?.count ?? 0,
            reviewingWords: levelDistribution["熟悉"]?.count ?? 0,
            masteredWords: levelDistribution["掌握"]?.count ?? 0
        )
    }
    

}