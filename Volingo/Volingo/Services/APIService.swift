//
//  APIService.swift
//  Volingo
//
//  对接后端全部 8 个 API 端点
//

import Foundation

// MARK: - API 错误

enum APIServiceError: Error, LocalizedError {
    case invalidURL
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL 无效"
        case .httpError(let code, let msg):
            return "HTTP \(code): \(msg ?? "未知错误")"
        case .decodingError(let err):
            return "解码失败: \(err.localizedDescription)"
        case .networkError(let err):
            return "网络错误: \(err.localizedDescription)"
        }
    }
}

// MARK: - API Service

final class APIService {
    static let shared = APIService()

    #if DEBUG
    private let baseURL = "http://localhost:5174"
    #else
    private let baseURL = "https://api.volingo.app"
    #endif

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        #if DEBUG
        // 开发环境绕过系统代理，避免 localhost 请求被代理拦截返回 503
        config.connectionProxyDictionary = [:]
        #endif
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
    }

    // MARK: - 通用请求

    private func makeRequest(path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = method
        request.setValue(DeviceIdManager.shared.deviceId, forHTTPHeaderField: "X-Device-Id")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = body
        }
        return request
    }

    /// 发起请求并解码 JSON 响应
    private func fetch<T: Decodable>(_ type: T.Type, request: URLRequest) async throws -> T {
        logRequest(request)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            print("[API] ❌ 网络异常: \(error)")
            throw APIServiceError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[API] ❌ 响应不是 HTTPURLResponse")
            throw APIServiceError.networkError(URLError(.badServerResponse))
        }

        logResponse(httpResponse, data: data)

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = (try? decoder.decode(APIError.self, from: data))?.error
            throw APIServiceError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            return try decoder.decode(type, from: data)
        } catch {
            print("[API] ❌ 解码失败(\(T.self)): \(error)")
            throw APIServiceError.decodingError(error)
        }
    }

    /// 发起请求，期望 204 No Content
    private func fetchNoContent(request: URLRequest) async throws {
        logRequest(request)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            print("[API] ❌ 网络异常: \(error)")
            throw APIServiceError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[API] ❌ 响应不是 HTTPURLResponse")
            throw APIServiceError.networkError(URLError(.badServerResponse))
        }

        logResponse(httpResponse, data: data)

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = (try? decoder.decode(APIError.self, from: data))?.error
            throw APIServiceError.httpError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    // MARK: - 日志

    private func logRequest(_ request: URLRequest) {
        #if DEBUG
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "nil"
        print("[API] ➡️ \(method) \(url)")
        if let headers = request.allHTTPHeaderFields {
            print("[API]    Headers: \(headers)")
        }
        if let body = request.httpBody, let str = String(data: body, encoding: .utf8) {
            print("[API]    Body: \(str)")
        }
        #endif
    }

    private func logResponse(_ response: HTTPURLResponse, data: Data) {
        #if DEBUG
        let status = response.statusCode
        let url = response.url?.absoluteString ?? "nil"
        let bodyPreview = String(data: data.prefix(2000), encoding: .utf8) ?? "<binary \(data.count) bytes>"
        let icon = (200...299).contains(status) ? "✅" : "❌"
        print("[API] \(icon) \(status) \(url)")
        print("[API]    Response Headers: \(response.allHeaderFields)")
        print("[API]    Body(\(data.count)B): \(bodyPreview)")
        #endif
    }

    // MARK: - 1. 获取练习题组

    /// 获取选择题 / 填空题 / 翻译题 等非阅读题型
    func fetchQuestions<T: Codable>(
        questionType: String,
        textbookCode: String,
        count: Int = 5
    ) async throws -> QuestionsResponse<[T]> {
        let path = "/api/v1/practice/questions?questionType=\(questionType)&textbookCode=\(textbookCode)&count=\(count)"
        let request = makeRequest(path: path)
        return try await fetch(QuestionsResponse<[T]>.self, request: request)
    }

    /// 获取阅读理解题（passages 结构）
    func fetchReadingQuestions(
        textbookCode: String,
        count: Int = 3
    ) async throws -> ReadingQuestionsResponse {
        let path = "/api/v1/practice/questions?questionType=reading&textbookCode=\(textbookCode)&count=\(count)"
        let request = makeRequest(path: path)
        return try await fetch(ReadingQuestionsResponse.self, request: request)
    }

    // MARK: - 便捷方法：按题型获取

    func fetchMCQQuestions(textbookCode: String, count: Int = 5) async throws -> (questions: [APIMCQQuestion], remaining: Int) {
        let resp: QuestionsResponse<[APIMCQQuestion]> = try await fetchQuestions(questionType: "multipleChoice", textbookCode: textbookCode, count: count)
        return (resp.questions, resp.remaining)
    }

    func fetchClozeQuestions(textbookCode: String, count: Int = 5) async throws -> (questions: [APIClozeQuestion], remaining: Int) {
        let resp: QuestionsResponse<[APIClozeQuestion]> = try await fetchQuestions(questionType: "cloze", textbookCode: textbookCode, count: count)
        return (resp.questions, resp.remaining)
    }

    func fetchTranslationQuestions(textbookCode: String, count: Int = 5) async throws -> (questions: [APITranslationQuestion], remaining: Int) {
        let resp: QuestionsResponse<[APITranslationQuestion]> = try await fetchQuestions(questionType: "translation", textbookCode: textbookCode, count: count)
        return (resp.questions, resp.remaining)
    }

    func fetchRewritingQuestions(textbookCode: String, count: Int = 5) async throws -> (questions: [APIRewritingQuestion], remaining: Int) {
        let resp: QuestionsResponse<[APIRewritingQuestion]> = try await fetchQuestions(questionType: "rewriting", textbookCode: textbookCode, count: count)
        return (resp.questions, resp.remaining)
    }

    func fetchErrorCorrectionQuestions(textbookCode: String, count: Int = 5) async throws -> (questions: [APIErrorCorrectionQuestion], remaining: Int) {
        let resp: QuestionsResponse<[APIErrorCorrectionQuestion]> = try await fetchQuestions(questionType: "errorCorrection", textbookCode: textbookCode, count: count)
        return (resp.questions, resp.remaining)
    }

    func fetchOrderingQuestions(textbookCode: String, count: Int = 5) async throws -> (questions: [APIOrderingQuestion], remaining: Int) {
        let resp: QuestionsResponse<[APIOrderingQuestion]> = try await fetchQuestions(questionType: "sentenceOrdering", textbookCode: textbookCode, count: count)
        return (resp.questions, resp.remaining)
    }

    func fetchListeningQuestions(textbookCode: String, count: Int = 5) async throws -> (questions: [APIListeningQuestion], remaining: Int) {
        let resp: QuestionsResponse<[APIListeningQuestion]> = try await fetchQuestions(questionType: "listening", textbookCode: textbookCode, count: count)
        return (resp.questions, resp.remaining)
    }

    func fetchSpeakingQuestions(textbookCode: String, count: Int = 5) async throws -> (questions: [APISpeakingQuestion], remaining: Int) {
        let resp: QuestionsResponse<[APISpeakingQuestion]> = try await fetchQuestions(questionType: "speaking", textbookCode: textbookCode, count: count)
        return (resp.questions, resp.remaining)
    }

    func fetchWritingQuestions(textbookCode: String, count: Int = 5) async throws -> (questions: [APIWritingQuestion], remaining: Int) {
        let resp: QuestionsResponse<[APIWritingQuestion]> = try await fetchQuestions(questionType: "writing", textbookCode: textbookCode, count: count)
        return (resp.questions, resp.remaining)
    }

    func fetchVocabularyQuestions(textbookCode: String, count: Int = 5) async throws -> (questions: [APIVocabularyQuestion], remaining: Int) {
        let resp: QuestionsResponse<[APIVocabularyQuestion]> = try await fetchQuestions(questionType: "vocabulary", textbookCode: textbookCode, count: count)
        return (resp.questions, resp.remaining)
    }

    func fetchGrammarQuestions(textbookCode: String, count: Int = 5) async throws -> (questions: [APIGrammarQuestion], remaining: Int) {
        let resp: QuestionsResponse<[APIGrammarQuestion]> = try await fetchQuestions(questionType: "grammar", textbookCode: textbookCode, count: count)
        return (resp.questions, resp.remaining)
    }

    func fetchScenarioQuestions(scenarioType: String, textbookCode: String, count: Int = 5) async throws -> (questions: [APIScenarioQuestion], remaining: Int) {
        let resp: QuestionsResponse<[APIScenarioQuestion]> = try await fetchQuestions(questionType: scenarioType, textbookCode: textbookCode, count: count)
        return (resp.questions, resp.remaining)
    }

    // MARK: - 2. 今日推荐套餐

    func fetchTodayPackage(textbookCode: String) async throws -> TodayPackageResponse {
        let path = "/api/v1/practice/today-package?textbookCode=\(textbookCode)"
        let request = makeRequest(path: path)
        return try await fetch(TodayPackageResponse.self, request: request)
    }

    // MARK: - 3. 学习统计

    func fetchStats(days: Int = 365) async throws -> StatsResponse {
        let path = "/api/v1/user/stats?days=\(days)"
        let request = makeRequest(path: path)
        return try await fetch(StatsResponse.self, request: request)
    }

    // MARK: - 4. 提交答案

    func submitResults(_ results: [SubmitResultItem]) async throws {
        let body = try JSONEncoder().encode(SubmitRequest(results: results))
        let request = makeRequest(path: "/api/v1/practice/submit", method: "POST", body: body)
        try await fetchNoContent(request: request)
    }

    // MARK: - 5. 题目投诉

    func reportQuestion(questionId: String, reason: String, description: String? = nil) async throws -> ReportResponse {
        let body = try JSONEncoder().encode(ReportRequest(questionId: questionId, reason: reason, description: description))
        let request = makeRequest(path: "/api/v1/practice/report", method: "POST", body: body)
        return try await fetch(ReportResponse.self, request: request)
    }

    // MARK: - 6. 生词本 - 添加

    func addWord(_ word: WordbookAddRequest) async throws -> WordbookAddResponse {
        let body = try JSONEncoder().encode(word)
        let request = makeRequest(path: "/api/v1/wordbook/add", method: "POST", body: body)
        return try await fetch(WordbookAddResponse.self, request: request)
    }

    // MARK: - 7. 生词本 - 删除

    func deleteWord(wordId: String) async throws {
        let request = makeRequest(path: "/api/v1/wordbook/\(wordId)", method: "DELETE")
        try await fetchNoContent(request: request)
    }

    // MARK: - 8. 生词本 - 列表

    func fetchWordbook() async throws -> WordbookListResponse {
        let request = makeRequest(path: "/api/v1/wordbook/list")
        return try await fetch(WordbookListResponse.self, request: request)
    }
}
