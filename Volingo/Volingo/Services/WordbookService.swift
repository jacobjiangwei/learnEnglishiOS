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
    
    /// 批量添加单词（如从阅读文本中提取的生词）
    func addWordsFromText(_ unknownWords: [String]) async throws {
        var words = try loadSavedWords()
        let existingWords = Set(words.map { $0.word.word.lowercased() })
        
        for unknownWord in unknownWords {
            if !existingWords.contains(unknownWord.lowercased()) {
                // 从词典服务查询单词
                if let searchResults = try? await DictionaryService.shared.searchWord(unknownWord),
                   let word = searchResults.first {
                    let savedWord = SavedWord(from: word)
                    words.append(savedWord)
                }
            }
        }
        
        try StorageService.shared.saveToFile(words, filename: "savedWords.json")
    }
    
    /// 更新单词信息
    func updateWord(_ savedWord: SavedWord) throws {
        var words = try loadSavedWords()
        if let index = words.firstIndex(where: { $0.id == savedWord.id }) {
            words[index] = savedWord
            try StorageService.shared.saveToFile(words, filename: "savedWords.json")
        }
    }
    
    /// 删除单词
    func deleteWord(_ wordId: String) throws {
        var words = try loadSavedWords()
        words.removeAll { $0.id == wordId }
        try StorageService.shared.saveToFile(words, filename: "savedWords.json")
    }
    
    /// 搜索生词本中的单词
    func searchSavedWords(_ query: String) throws -> [SavedWord] {
        let words = try loadSavedWords()
        let lowercaseQuery = query.lowercased()
        
        return words.filter { savedWord in
            savedWord.word.word.lowercased().contains(lowercaseQuery) ||
            savedWord.definition.lowercased().contains(lowercaseQuery)
        }
    }
    
    /// 根据掌握程度描述获取单词
    func getWordsByMasteryDescription(_ description: String) throws -> [SavedWord] {
        let words = try loadSavedWords()
        return words.filter { $0.masteryDescription == description }
    }
    
    /// 获取需要复习的单词
    func getWordsNeedingReview() throws -> [SavedWord] {
        let words = try loadSavedWords()
        return words.filter { $0.needsReview }
    }
    
    /// 获取需要练习的单词（按紧急程度排序）
    func getWordsNeedingPractice() -> [SavedWord] {
        do {
            let words = try loadSavedWords()
            return words.filter { $0.needsReview }
                       .sorted { $0.reviewUrgency > $1.reviewUrgency }
        } catch {
            return []
        }
    }
    
    // MARK: - 智能复习推荐
    
    // 基础复习间隔（小时）- 艾宾浩斯遗忘曲线改良版
    private let baseIntervals: [TimeInterval] = [
        1,      // 1小时
        4,      // 4小时  
        12,     // 12小时
        24,     // 1天
        72,     // 3天
        168,    // 1周
        336,    // 2周
        720     // 1月
    ].map { $0 * 60 * 60 } // 转换为秒
    
    /// 获取推荐复习的单词列表
    func getRecommendedReviewWords(limit: Int = 20) throws -> [SavedWord] {
        let allWords = try loadSavedWords()
        let now = Date()
        
        // 分类单词
        let categorized = categorizeWordsByUrgency(allWords, currentTime: now)
        
        var recommended: [SavedWord] = []
        
        // 1. 优先推荐新词（总是可学习）
        recommended.append(contentsOf: Array(categorized.newWords.prefix(5)))
        
        // 2. 逾期很久的词（超过计划时间1天以上）
        recommended.append(contentsOf: Array(categorized.overdueWords.prefix(8)))
        
        // 3. 今天应该复习的词
        recommended.append(contentsOf: Array(categorized.todayWords.prefix(7)))
        
        // 4. 如果还没满，补充一些学习中的词
        let remaining = max(0, limit - recommended.count)
        if remaining > 0 {
            let additionalWords = categorized.learningWords
                .filter { word in !recommended.contains { $0.id == word.id } }
                .prefix(remaining)
            recommended.append(contentsOf: additionalWords)
        }
        
        return Array(recommended.prefix(limit))
    }
    
    /// 按紧急程度分类单词
    private func categorizeWordsByUrgency(_ words: [SavedWord], currentTime: Date) -> WordCategories {
        var newWords: [SavedWord] = []
        var overdueWords: [SavedWord] = []
        var todayWords: [SavedWord] = []
        var learningWords: [SavedWord] = []
        
        for word in words {
            // 基于level判断单词状态
            switch word.level {
            case 0:
                newWords.append(word)
            case 9...10:
                // 已精通的词，除非很久没复习，否则不推荐
                let daysSinceAdded = currentTime.timeIntervalSince(word.addedDate) / (24 * 60 * 60)
                if daysSinceAdded > 30 {
                    overdueWords.append(word)
                }
            default:
                let overdueTime = currentTime.timeIntervalSince(word.nextReviewDate)
                
                if (overdueTime > 24 * 60 * 60) { // 逾期超过1天
                    overdueWords.append(word)
                } else if (overdueTime > 0) { // 今天需要复习
                    todayWords.append(word)
                } else {
                    learningWords.append(word)
                }
            }
        }
        
        // 按紧急程度排序
        overdueWords.sort { word1, word2 in
            word1.reviewUrgency > word2.reviewUrgency
        }
        
        return WordCategories(
            newWords: newWords,
            overdueWords: overdueWords,
            todayWords: todayWords,
            learningWords: learningWords
        )
    }
    
    // MARK: - 学习会话管理
    
    /// 开始学习会话
    func startLearningSession(wordIds: [String]) throws -> LearningSession {
        let words = try loadSavedWords()
        let sessionWords = words.filter { wordIds.contains($0.id) }
        
        return LearningSession(
            id: UUID().uuidString,
            words: sessionWords,
            startTime: Date(),
            currentIndex: 0
        )
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
            learningWords: (levelDistribution["初学"]?.count ?? 0) + (levelDistribution["学习中"]?.count ?? 0),
            reviewingWords: levelDistribution["熟悉"]?.count ?? 0,
            masteredWords: (levelDistribution["掌握"]?.count ?? 0) + (levelDistribution["精通"]?.count ?? 0)
        )
    }
    
    /// 分析用户学习模式
    func getUserLearningPattern() throws -> LearningPattern {
        let words = try loadSavedWords()
        
        // 分析用户的学习习惯
        let reviewTimes = words.compactMap { word -> TimeInterval? in
            let overdue = Date().timeIntervalSince(word.nextReviewDate)
            return overdue > 0 ? overdue : nil
        }
        
        let averageDelay = reviewTimes.isEmpty ? 0 : reviewTimes.reduce(0, +) / Double(reviewTimes.count)
        let onTimeRate = Double(words.filter { !$0.needsReview }.count) / Double(max(words.count, 1))
        
        return LearningPattern(
            averageDelay: averageDelay,
            onTimeReviewRate: onTimeRate,
            totalWords: words.count,
            activeWords: words.filter { $0.level < 9 }.count // level < 9 表示还在学习中
        )
    }
    
    /// 获取推荐学习会话
    func getRecommendedStudySession() throws -> StudySessionRecommendation {
        let recommended = try getRecommendedReviewWords(limit: 50)
        let pattern = try getUserLearningPattern()
        
        // 根据用户习惯推荐学习量
        let recommendedCount: Int
        if pattern.onTimeReviewRate > 0.8 {
            recommendedCount = min(25, recommended.count) // 积极用户
        } else if pattern.onTimeReviewRate > 0.5 {
            recommendedCount = min(15, recommended.count) // 普通用户
        } else {
            recommendedCount = min(10, recommended.count) // 不规律用户
        }
        
        return StudySessionRecommendation(
            recommendedWords: Array(recommended.prefix(recommendedCount)),
            estimatedMinutes: recommendedCount * 2, // 每词约2分钟
            urgentWords: recommended.filter { word in
                Date().timeIntervalSince(word.nextReviewDate) > 24 * 60 * 60
            }.count
        )
    }
}