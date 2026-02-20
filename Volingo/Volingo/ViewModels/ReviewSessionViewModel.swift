//
//  ReviewSessionViewModel.swift
//  Volingo
//

import Foundation
import SwiftUI

// MARK: - Session 结果
struct SessionResults {
    let totalWords: Int
    let correctCount: Int
    let wrongCount: Int
    let duration: TimeInterval
    
    var accuracy: Double {
        let total = correctCount + wrongCount
        guard total > 0 else { return 0 }
        return Double(correctCount) / Double(total)
    }
    
    var durationText: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes)分\(seconds)秒"
    }
}

// MARK: - ReviewSessionViewModel
@MainActor
class ReviewSessionViewModel: ObservableObject {
    
    // MARK: - 状态
    enum SessionState {
        case loading
        case question          // 当前正在答题
        case completed         // Session 结束
    }
    
    @Published var state: SessionState = .loading
    @Published var questions: [any ReviewQuestion] = []
    @Published var currentIndex: Int = 0
    @Published var sessionResults: SessionResults = SessionResults(totalWords: 0, correctCount: 0, wrongCount: 0, duration: 0)
    
    // 答题反馈
    @Published var lastAnswerCorrect: Bool = false
    @Published var lastCorrectAnswer: String = ""
    @Published var toastItem: ToastItem? = nil
    @Published var showWrongAnswer: Bool = false
    
    // 连线消消乐状态
    @Published var matchingRemainingPairs: [(id: String, english: String, chinese: String)] = []
    @Published var matchingShuffledChinese: [String] = []
    @Published var matchingSelectedEnglish: String? = nil
    @Published var matchingSelectedChinese: String? = nil
    @Published var matchingErrorFlash: Bool = false
    @Published var matchingResults: [String: Int] = [:]  // wordId -> 配错次数
    
    // 内部
    private let wordbookService = WordbookService.shared
    private var wordsToReview: [SavedWord] = []
    private var startTime: Date = Date()
    private var correctCount = 0
    private var wrongCount = 0
    private var wordRatings: [String: FSRSRating] = [:]  // wordId -> 最终评分
    private var retryQueue: [SavedWord] = []  // 答错的词，换题型再出一次
    
    var currentQuestion: (any ReviewQuestion)? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }
    
    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentIndex) / Double(questions.count)
    }
    
    var progressText: String {
        "\(min(currentIndex + 1, questions.count))/\(questions.count)"
    }
    
    // MARK: - 开始
    
    func startSession() {
        state = .loading
        startTime = Date()
        correctCount = 0
        wrongCount = 0
        wordRatings.removeAll()
        retryQueue.removeAll()
        matchingResults.removeAll()
        
        do {
            wordsToReview = try wordbookService.getWordsToReview()
            if wordsToReview.isEmpty {
                // 没有需要复习的词
                finishSession()
                return
            }
            questions = QuestionGenerator.generateSession(words: wordsToReview)
            currentIndex = 0
            state = .question
        } catch {
            print("加载复习词失败: \(error)")
            finishSession()
        }
    }
    
    // MARK: - 选择题作答
    
    func answerMCQ(selected: String) {
        guard let q = currentQuestion as? ReviewMCQQuestion else { return }
        guard toastItem == nil && !showWrongAnswer else { return }
        let correct = selected == q.correctAnswer
        lastAnswerCorrect = correct
        lastCorrectAnswer = q.correctAnswer
        
        if correct {
            correctCount += 1
            updateRating(wordId: q.wordId, rating: .good)
            showCorrectAndAdvance()
        } else {
            wrongCount += 1
            updateRating(wordId: q.wordId, rating: .again)
            enqueueRetry(wordId: q.wordId)
            withAnimation(.spring(duration: 0.3)) { showWrongAnswer = true }
        }
    }
    
    // MARK: - 填空题作答
    
    func answerCloze(typed: String) {
        guard let q = currentQuestion as? ReviewClozeQuestion else { return }
        guard toastItem == nil && !showWrongAnswer else { return }
        let correct = typed.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == q.answer.lowercased()
        lastAnswerCorrect = correct
        lastCorrectAnswer = q.answer
        
        if correct {
            correctCount += 1
            updateRating(wordId: q.wordId, rating: .good)
            showCorrectAndAdvance()
        } else {
            wrongCount += 1
            updateRating(wordId: q.wordId, rating: .again)
            enqueueRetry(wordId: q.wordId)
            withAnimation(.spring(duration: 0.3)) { showWrongAnswer = true }
        }
    }
    
    // MARK: - 拼写题作答
    
    func answerSpell(typed: String) {
        guard let q = currentQuestion as? ReviewSpellQuestion else { return }
        guard toastItem == nil && !showWrongAnswer else { return }
        let correct = typed.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == q.wordToSpell.lowercased()
        lastAnswerCorrect = correct
        lastCorrectAnswer = q.wordToSpell
        
        if correct {
            correctCount += 1
            updateRating(wordId: q.wordId, rating: .good)
            showCorrectAndAdvance()
        } else {
            wrongCount += 1
            updateRating(wordId: q.wordId, rating: .again)
            enqueueRetry(wordId: q.wordId)
            withAnimation(.spring(duration: 0.3)) { showWrongAnswer = true }
        }
    }
    
    // MARK: - 连线消消乐
    
    func setupMatching() {
        guard let q = currentQuestion as? ReviewMatchingQuestion else { return }
        matchingRemainingPairs = q.pairs
        matchingShuffledChinese = q.pairs.map { $0.chinese }.shuffled()
        matchingSelectedEnglish = nil
        matchingSelectedChinese = nil
        matchingErrorFlash = false
        matchingResults.removeAll()
        for pair in q.pairs {
            matchingResults[pair.id] = 0
        }
    }
    
    func selectMatchingEnglish(_ english: String) {
        matchingSelectedEnglish = english
        tryMatch()
    }
    
    func selectMatchingChinese(_ chinese: String) {
        matchingSelectedChinese = chinese
        tryMatch()
    }
    
    private func tryMatch() {
        guard let eng = matchingSelectedEnglish, let ch = matchingSelectedChinese else { return }
        
        // 查找是否正确配对
        if let _ = matchingRemainingPairs.first(where: { $0.english == eng && $0.chinese == ch }) {
            // 正确配对 → 消除
            matchingRemainingPairs.removeAll { $0.english == eng }
            matchingShuffledChinese.removeAll { $0 == ch }
            matchingSelectedEnglish = nil
            matchingSelectedChinese = nil
            
            // 检查是否全部消除
            if matchingRemainingPairs.isEmpty {
                // 连线完成，计算每个词的评分
                finishMatching()
            }
        } else {
            // 配错
            matchingErrorFlash = true
            // 找到这个英文对应的 id，记录错误次数
            if let pair = matchingRemainingPairs.first(where: { $0.english == eng }) {
                matchingResults[pair.id, default: 0] += 1
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.matchingErrorFlash = false
                self?.matchingSelectedEnglish = nil
                self?.matchingSelectedChinese = nil
            }
        }
    }
    
    private func finishMatching() {
        guard let q = currentQuestion as? ReviewMatchingQuestion else { return }
        
        for pair in q.pairs {
            let errors = matchingResults[pair.id] ?? 0
            let rating: FSRSRating
            switch errors {
            case 0: rating = .easy
            case 1: rating = .good
            case 2: rating = .hard
            default: rating = .again
            }
            
            if rating == .again {
                wrongCount += 1
                enqueueRetry(wordId: pair.id)
            } else {
                correctCount += 1
            }
            updateRating(wordId: pair.id, rating: rating)
        }
        
        // 直接进入下一题（连线无需单独反馈页）
        moveToNext()
    }
    
    // MARK: - 反馈动画
    
    private func showCorrectAndAdvance() {
        toastItem = ToastItem(style: .success, title: "正确!", duration: 0.8)
    }
    
    /// Toast 自动消失后调用
    func onCorrectToastDismissed() {
        moveToNext()
    }
    
    func dismissWrongAndContinue() {
        withAnimation(.spring(duration: 0.25)) { showWrongAnswer = false }
        moveToNext()
    }
    
    // MARK: - 导航
    
    func moveToNext() {
        currentIndex += 1
        
        // 如果所有题做完了，看看有没有 retry 队列
        if currentIndex >= questions.count {
            if !retryQueue.isEmpty {
                // 为答错的词换题型再出一题
                var retryQuestions: [any ReviewQuestion] = []
                for word in retryQueue {
                    // 用不同的题型
                    let preferredType: ReviewQuestionType = [.engToChMCQ, .chToEngMCQ, .clozeFill].randomElement()!
                    retryQuestions.append(QuestionGenerator.generateSingleQuestion(for: word, preferredType: preferredType))
                }
                questions.append(contentsOf: retryQuestions)
                retryQueue.removeAll()
            }
        }
        
        if currentIndex >= questions.count {
            finishSession()
        } else {
            state = .question
        }
    }
    
    // MARK: - 结束
    
    private func finishSession() {
        let duration = Date().timeIntervalSince(startTime)
        let allWordIds = Set(wordRatings.keys)
        
        // 持久化 FSRS 评分
        for (wordId, rating) in wordRatings {
            try? wordbookService.recordReview(wordId, rating: rating)
        }
        
        sessionResults = SessionResults(
            totalWords: allWordIds.count,
            correctCount: correctCount,
            wrongCount: wrongCount,
            duration: duration
        )
        state = .completed
    }
    
    // MARK: - 辅助
    
    private func updateRating(wordId: String, rating: FSRSRating) {
        // 取最差评分（一个词如果在连线和单独题中都出现）
        if let existing = wordRatings[wordId] {
            if rating.rawValue < existing.rawValue {
                wordRatings[wordId] = rating
            }
        } else {
            wordRatings[wordId] = rating
        }
    }
    
    private func enqueueRetry(wordId: String) {
        guard let word = wordsToReview.first(where: { $0.id == wordId }) else { return }
        // 避免重复加入
        if !retryQueue.contains(where: { $0.id == wordId }) {
            retryQueue.append(word)
        }
    }
}
