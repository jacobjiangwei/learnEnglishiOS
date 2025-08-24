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
    
    /// 根据掌握程度获取单词
    func getWordsByMasteryLevel(_ level: MasteryLevel) throws -> [SavedWord] {
        let words = try loadSavedWords()
        return words.filter { $0.masteryLevel == level }
    }
    
    /// 获取需要复习的单词
    func getWordsNeedingReview() throws -> [SavedWord] {
        let words = try loadSavedWords()
        let now = Date()
        return words.filter { now >= $0.nextReviewDate }
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
            switch word.masteryLevel {
            case .new:
                newWords.append(word)
            case .mastered:
                // 已掌握的词，除非很久没复习，否则不推荐
                let daysSinceLastReview = currentTime.timeIntervalSince(word.lastReviewDate ?? word.addedDate) / (24 * 60 * 60)
                if daysSinceLastReview > 30 {
                    overdueWords.append(word)
                }
            default:
                let overdueTime = currentTime.timeIntervalSince(word.nextReviewDate)
                
                if overdueTime > 24 * 60 * 60 { // 逾期超过1天
                    overdueWords.append(word)
                } else if overdueTime > 0 { // 今天需要复习
                    todayWords.append(word)
                } else {
                    learningWords.append(word)
                }
            }
        }
        
        // 按紧急程度排序
        overdueWords.sort { word1, word2 in
            let overdue1 = currentTime.timeIntervalSince(word1.nextReviewDate)
            let overdue2 = currentTime.timeIntervalSince(word2.nextReviewDate)
            return overdue1 > overdue2
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
        let now = Date()
        
        // 更新学习记录
        word.totalReviews += 1
        word.lastReviewDate = now
        
        switch result.type {
        case .correct:
            word.correctCount += 1
            increaseReviewInterval(&word, currentTime: now)
            
        case .incorrect:
            word.wrongCount += 1
            decreaseReviewInterval(&word, currentTime: now)
            
        case .skipped:
            // 跳过不计入正确/错误，但计入总数
            // 保持当前间隔不变
            word.nextReviewDate = now.addingTimeInterval(word.reviewInterval)
        }
        
        // 重新评估掌握程度
        updateMasteryLevel(&word)
        
        words[index] = word
        try StorageService.shared.saveToFile(words, filename: "savedWords.json")
    }
    
    // MARK: - 间隔调整逻辑
    
    private func increaseReviewInterval(_ word: inout SavedWord, currentTime: Date) {
        // 计算用户的复习延迟情况
        let plannedTime = word.nextReviewDate
        let actualDelay = currentTime.timeIntervalSince(plannedTime)
        
        // 找到当前间隔在基础间隔中的位置
        let currentIntervalIndex = baseIntervals.firstIndex { $0 >= word.reviewInterval } ?? baseIntervals.count - 1
        
        if actualDelay <= 0 {
            // 用户按时或提前复习，正常增加间隔
            let nextIndex = min(currentIntervalIndex + 1, baseIntervals.count - 1)
            word.reviewInterval = baseIntervals[nextIndex]
        } else if actualDelay <= 24 * 60 * 60 {
            // 延迟1天内，稍微保守增加间隔
            let nextIndex = min(currentIntervalIndex + 1, baseIntervals.count - 1)
            word.reviewInterval = baseIntervals[nextIndex] * 0.8
        } else {
            // 延迟超过1天，间隔增加更保守
            word.reviewInterval = min(word.reviewInterval * 1.2, baseIntervals[currentIntervalIndex])
        }
        
        word.nextReviewDate = currentTime.addingTimeInterval(word.reviewInterval)
    }
    
    private func decreaseReviewInterval(_ word: inout SavedWord, currentTime: Date) {
        // 根据答错频率决定回退程度
        let accuracy = word.accuracyRate
        
        if accuracy < 0.3 {
            // 答对率很低，重置到最开始
            word.reviewInterval = baseIntervals[0]
        } else if accuracy < 0.5 {
            // 答对率较低，回退2级
            let currentIndex = baseIntervals.firstIndex { $0 >= word.reviewInterval } ?? 0
            let newIndex = max(0, currentIndex - 2)
            word.reviewInterval = baseIntervals[newIndex]
        } else {
            // 偶尔错误，回退1级
            let currentIndex = baseIntervals.firstIndex { $0 >= word.reviewInterval } ?? 0
            let newIndex = max(0, currentIndex - 1)
            word.reviewInterval = baseIntervals[newIndex]
        }
        
        word.nextReviewDate = currentTime.addingTimeInterval(word.reviewInterval)
    }
    
    // MARK: - 掌握程度评估
    
    private func updateMasteryLevel(_ word: inout SavedWord) {
        let accuracy = word.accuracyRate
        let reviewCount = word.totalReviews
        
        switch word.masteryLevel {
        case .new:
            // 新词 -> 学习中：只要开始学习就进入学习中
            if reviewCount > 0 {
                word.masteryLevel = .learning
            }
            
        case .learning:
            // 学习中 -> 复习中：答对率达到60%且复习次数>=3
            if accuracy >= 0.6 && reviewCount >= 3 {
                word.masteryLevel = .reviewing
            }
            
        case .reviewing:
            // 复习中 -> 已掌握：答对率达到85%且复习次数>=5
            if accuracy >= 0.85 && reviewCount >= 5 {
                word.masteryLevel = .mastered
            }
            // 复习中 -> 学习中：答对率下降到50%以下
            else if accuracy < 0.5 {
                word.masteryLevel = .learning
            }
            
        case .mastered:
            // 已掌握 -> 复习中：答对率下降到70%以下
            if accuracy < 0.7 {
                word.masteryLevel = .reviewing
            }
        }
    }
    
    // MARK: - 统计和分析
    
    /// 获取生词本统计信息
    func getWordbookStats() throws -> WordbookStats {
        let words = try loadSavedWords()
        let needReview = words.filter { $0.needsReview }.count
        let masteryDistribution = Dictionary(grouping: words) { $0.masteryLevel }
        
        return WordbookStats(
            totalWords: words.count,
            needReviewCount: needReview,
            newWords: masteryDistribution[.new]?.count ?? 0,
            learningWords: masteryDistribution[.learning]?.count ?? 0,
            reviewingWords: masteryDistribution[.reviewing]?.count ?? 0,
            masteredWords: masteryDistribution[.mastered]?.count ?? 0
        )
    }
    
    /// 分析用户学习模式
    func getUserLearningPattern() throws -> LearningPattern {
        let words = try loadSavedWords()
        
        // 分析用户的学习习惯
        let reviewTimes = words.compactMap { word -> TimeInterval? in
            guard let lastReview = word.lastReviewDate else { return nil }
            return lastReview.timeIntervalSince(word.nextReviewDate)
        }
        
        let averageDelay = reviewTimes.isEmpty ? 0 : reviewTimes.reduce(0, +) / Double(reviewTimes.count)
        let onTimeRate = Double(reviewTimes.filter { $0 <= 0 }.count) / Double(max(reviewTimes.count, 1))
        
        return LearningPattern(
            averageDelay: averageDelay,
            onTimeReviewRate: onTimeRate,
            totalWords: words.count,
            activeWords: words.filter { $0.masteryLevel != .mastered }.count
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