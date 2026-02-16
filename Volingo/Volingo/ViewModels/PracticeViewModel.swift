//
//  PracticeViewModel.swift
//  Volingo
//
//  从 API 加载题目并转换为 View 层模型
//

import Foundation
import SwiftUI

extension Notification.Name {
    static let practiceResultsSubmitted = Notification.Name("practiceResultsSubmitted")
}

// MARK: - 加载状态

enum LoadingState<T> {
    case idle
    case loading
    case loaded(T)
    case error(String)
}

// MARK: - Practice ViewModel

@MainActor
class PracticeViewModel: ObservableObject {
    @Published var mcqQuestions: LoadingState<[MCQQuestion]> = .idle
    @Published var clozeQuestions: LoadingState<[ClozeQuestion]> = .idle
    @Published var readingPassage: LoadingState<ReadingPassage> = .idle
    @Published var translationItems: LoadingState<[TextInputItem]> = .idle
    @Published var rewritingItems: LoadingState<[TextInputItem]> = .idle
    @Published var writingItems: LoadingState<[TextInputItem]> = .idle
    @Published var errorCorrectionQuestions: LoadingState<[ErrorCorrectionQuestion]> = .idle
    @Published var orderingQuestions: LoadingState<[OrderingQuestion]> = .idle
    @Published var listeningQuestions: LoadingState<[ListeningQuestion]> = .idle
    @Published var speakingQuestions: LoadingState<[SpeakingQuestion]> = .idle
    @Published var vocabularyQuestions: LoadingState<[MCQQuestion]> = .idle
    @Published var grammarQuestions: LoadingState<[MCQQuestion]> = .idle
    @Published var scenarioQuestions: LoadingState<[ScenarioQuestion]> = .idle

    /// 本次练习中所有获取到的题目 ID，用于批量提交
    @Published var questionIds: [(id: String, isCorrect: Bool)] = []

    private let api = APIService.shared

    // MARK: - 加载方法

    func loadQuestions(type: QuestionType, textbookCode: String) {
        Task {
            await doLoad(type: type, textbookCode: textbookCode)
        }
    }

    private func doLoad(type: QuestionType, textbookCode: String) async {
        switch type {
        case .multipleChoice:
            await loadMCQ(textbookCode: textbookCode)
        case .cloze:
            await loadCloze(textbookCode: textbookCode)
        case .reading:
            await loadReading(textbookCode: textbookCode)
        case .translation:
            await loadTranslation(textbookCode: textbookCode)
        case .rewriting:
            await loadRewriting(textbookCode: textbookCode)
        case .errorCorrection:
            await loadErrorCorrection(textbookCode: textbookCode)
        case .sentenceOrdering:
            await loadOrdering(textbookCode: textbookCode)
        case .listening:
            await loadListening(textbookCode: textbookCode)
        case .speaking:
            await loadSpeaking(textbookCode: textbookCode)
        case .writing:
            await loadWriting(textbookCode: textbookCode)
        case .vocabulary:
            await loadVocabulary(textbookCode: textbookCode)
        case .grammar:
            await loadGrammar(textbookCode: textbookCode)
        case .scenarioDaily, .scenarioCampus, .scenarioWorkplace, .scenarioTravel:
            await loadScenario(type: type, textbookCode: textbookCode)
        case .quickSprint, .randomChallenge, .timedDrill:
            // 轻量类复用选择题
            await loadMCQ(textbookCode: textbookCode)
        case .errorReview:
            // 错题复练复用选择题（后续可改为专用接口）
            await loadMCQ(textbookCode: textbookCode)
        }
    }

    // MARK: - 提交答案

    func submitResults() async {
        guard !questionIds.isEmpty else { return }
        let results = questionIds.map { SubmitResultItem(questionId: $0.id, isCorrect: $0.isCorrect) }
        do {
            try await api.submitResults(results)
            NotificationCenter.default.post(name: .practiceResultsSubmitted, object: nil)
        } catch {
            print("提交答案失败: \(error)")
        }
    }

    func recordAnswer(questionId: String, isCorrect: Bool) {
        questionIds.append((id: questionId, isCorrect: isCorrect))
    }

    // MARK: - 各题型加载

    /// 如果数组为空，显示"暂无题目"而非空白界面
    private func guardEmpty<T>(_ items: [T]) throws -> [T] {
        if items.isEmpty { throw EmptyQuestionsError() }
        return items
    }

    private struct EmptyQuestionsError: LocalizedError {
        var errorDescription: String? { "暂无可用题目，请稍后再试" }
    }

    private func loadMCQ(textbookCode: String) async {
        mcqQuestions = .loading
        do {
            let (apiQuestions, _) = try await api.fetchMCQQuestions(textbookCode: textbookCode)
            let questions = try guardEmpty(apiQuestions).map { q in
                MCQQuestion(
                    id: q.id,
                    stem: q.stem,
                    options: q.options,
                    correctIndex: q.correctIndex,
                    explanation: q.explanation
                )
            }
            mcqQuestions = .loaded(questions)
        } catch {
            mcqQuestions = .error(error.localizedDescription)
        }
    }

    private func loadCloze(textbookCode: String) async {
        clozeQuestions = .loading
        do {
            let (apiQuestions, _) = try await api.fetchClozeQuestions(textbookCode: textbookCode)
            let questions = try guardEmpty(apiQuestions).map { q in
                ClozeQuestion(
                    id: q.id,
                    sentence: q.sentence,
                    answer: q.correctAnswer,
                    hint: q.hints?.first,
                    explanation: q.explanation ?? ""
                )
            }
            clozeQuestions = .loaded(questions)
        } catch {
            clozeQuestions = .error(error.localizedDescription)
        }
    }

    private func loadReading(textbookCode: String) async {
        readingPassage = .loading
        do {
            let resp = try await api.fetchReadingQuestions(textbookCode: textbookCode)
            guard let first = resp.passages?.first else {
                readingPassage = .error("暂无可用的阅读题")
                return
            }
            let questions = first.questions.map { q in
                ReadingQuestion(
                    id: q.id,
                    stem: q.stem,
                    options: q.options,
                    correctIndex: q.correctIndex,
                    explanation: q.explanation ?? ""
                )
            }
            let passage = ReadingPassage(
                id: first.id,
                title: first.title,
                content: first.content,
                questions: questions
            )
            readingPassage = .loaded(passage)
        } catch {
            readingPassage = .error(error.localizedDescription)
        }
    }

    private func loadTranslation(textbookCode: String) async {
        translationItems = .loading
        do {
            let (apiQuestions, _) = try await api.fetchTranslationQuestions(textbookCode: textbookCode)
            let items = try guardEmpty(apiQuestions).map { q in
                TextInputItem(
                    id: q.id,
                    sourceText: q.sourceText,
                    instruction: q.direction == "zhToEn" ? "请翻译成英文" : "请翻译成中文",
                    referenceAnswer: q.referenceAnswer,
                    keywords: q.keywords,
                    explanation: q.explanation ?? "",
                    isSelfEvaluated: true
                )
            }
            translationItems = .loaded(items)
        } catch {
            translationItems = .error(error.localizedDescription)
        }
    }

    private func loadRewriting(textbookCode: String) async {
        rewritingItems = .loading
        do {
            let (apiQuestions, _) = try await api.fetchRewritingQuestions(textbookCode: textbookCode)
            let items = try guardEmpty(apiQuestions).map { q in
                TextInputItem(
                    id: q.id,
                    sourceText: q.originalSentence,
                    instruction: q.instruction,
                    referenceAnswer: q.referenceAnswer,
                    keywords: [],
                    explanation: q.explanation ?? ""
                )
            }
            rewritingItems = .loaded(items)
        } catch {
            rewritingItems = .error(error.localizedDescription)
        }
    }

    private func loadWriting(textbookCode: String) async {
        writingItems = .loading
        do {
            let (apiQuestions, _) = try await api.fetchWritingQuestions(textbookCode: textbookCode)
            let items = try guardEmpty(apiQuestions).map { q in
                TextInputItem(
                    id: q.id,
                    sourceText: q.prompt,
                    instruction: "字数要求：\(q.wordLimit.min)-\(q.wordLimit.max) 词",
                    referenceAnswer: q.referenceAnswer,
                    keywords: [],
                    explanation: "参考范文已展示。请对照学习。",
                    isSelfEvaluated: true
                )
            }
            writingItems = .loaded(items)
        } catch {
            writingItems = .error(error.localizedDescription)
        }
    }

    private func loadErrorCorrection(textbookCode: String) async {
        errorCorrectionQuestions = .loading
        do {
            let (apiQuestions, _) = try await api.fetchErrorCorrectionQuestions(textbookCode: textbookCode)
            let questions = try guardEmpty(apiQuestions).map { q in
                ErrorCorrectionQuestion(
                    id: q.id,
                    sentence: q.sentence,
                    errorRange: q.errorRange,
                    correction: q.correction,
                    explanation: q.explanation ?? ""
                )
            }
            errorCorrectionQuestions = .loaded(questions)
        } catch {
            errorCorrectionQuestions = .error(error.localizedDescription)
        }
    }

    private func loadOrdering(textbookCode: String) async {
        orderingQuestions = .loading
        do {
            let (apiQuestions, _) = try await api.fetchOrderingQuestions(textbookCode: textbookCode)
            let questions = try guardEmpty(apiQuestions).map { q in
                OrderingQuestion(
                    id: q.id,
                    shuffledParts: q.shuffledParts,
                    correctOrder: q.correctOrder,
                    explanation: q.explanation ?? ""
                )
            }
            orderingQuestions = .loaded(questions)
        } catch {
            orderingQuestions = .error(error.localizedDescription)
        }
    }

    private func loadListening(textbookCode: String) async {
        listeningQuestions = .loading
        do {
            let (apiQuestions, _) = try await api.fetchListeningQuestions(textbookCode: textbookCode)
            let questions = try guardEmpty(apiQuestions).map { q in
                ListeningQuestion(
                    id: q.id,
                    audioURL: q.audioURL,
                    transcript: q.transcript,
                    stem: q.stem,
                    options: q.options,
                    correctIndex: q.correctIndex,
                    explanation: q.explanation ?? ""
                )
            }
            listeningQuestions = .loaded(questions)
        } catch {
            listeningQuestions = .error(error.localizedDescription)
        }
    }

    private func loadSpeaking(textbookCode: String) async {
        speakingQuestions = .loading
        do {
            let (apiQuestions, _) = try await api.fetchSpeakingQuestions(textbookCode: textbookCode)
            let questions = try guardEmpty(apiQuestions).map { q in
                SpeakingQuestion(
                    id: q.id,
                    prompt: q.prompt,
                    referenceText: q.referenceText,
                    category: SpeakingCategory.from(apiKey: q.category)
                )
            }
            speakingQuestions = .loaded(questions)
        } catch {
            speakingQuestions = .error(error.localizedDescription)
        }
    }

    private func loadVocabulary(textbookCode: String) async {
        vocabularyQuestions = .loading
        do {
            let (apiQuestions, _) = try await api.fetchVocabularyQuestions(textbookCode: textbookCode)
            // 词汇题复用 MCQQuestion 视图
            let questions = try guardEmpty(apiQuestions).map { q in
                MCQQuestion(
                    id: q.id,
                    stem: q.stem,
                    options: q.options,
                    correctIndex: q.correctIndex,
                    explanation: q.explanation ?? ""
                )
            }
            vocabularyQuestions = .loaded(questions)
        } catch {
            vocabularyQuestions = .error(error.localizedDescription)
        }
    }

    private func loadGrammar(textbookCode: String) async {
        grammarQuestions = .loading
        do {
            let (apiQuestions, _) = try await api.fetchGrammarQuestions(textbookCode: textbookCode)
            // 语法题复用 MCQQuestion 视图
            let questions = try guardEmpty(apiQuestions).map { q in
                MCQQuestion(
                    id: q.id,
                    stem: q.stem,
                    options: q.options,
                    correctIndex: q.correctIndex,
                    explanation: q.explanation ?? ""
                )
            }
            grammarQuestions = .loaded(questions)
        } catch {
            grammarQuestions = .error(error.localizedDescription)
        }
    }

    private func loadScenario(type: QuestionType, textbookCode: String) async {
        scenarioQuestions = .loading
        do {
            let apiKey = type.apiKey
            let (apiQuestions, _) = try await api.fetchScenarioQuestions(scenarioType: apiKey, textbookCode: textbookCode)
            let questions = try guardEmpty(apiQuestions).map { q in
                ScenarioQuestion(
                    id: q.id,
                    type: type,
                    scenarioTitle: q.scenarioTitle,
                    context: q.context,
                    dialogueLines: q.dialogueLines.map {
                        DialogueLine(id: UUID().uuidString, speaker: $0.speaker, text: $0.text)
                    },
                    userPrompt: q.userPrompt,
                    options: q.options,
                    correctIndex: q.correctIndex,
                    referenceResponse: q.referenceResponse
                )
            }
            scenarioQuestions = .loaded(questions)
        } catch {
            scenarioQuestions = .error(error.localizedDescription)
        }
    }
}
