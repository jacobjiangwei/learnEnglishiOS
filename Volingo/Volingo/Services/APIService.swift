//
//  APIService.swift
//  海豹英语
//
//  对接后端全部 8 个 API 端点
//

import Foundation

// MARK: - API 错误

enum APIServiceError: Error, LocalizedError {
    case invalidURL
    case httpError(statusCode: Int, message: String?, code: String?)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL 无效"
        case .httpError(let code, let msg, _):
            return "HTTP \(code): \(msg ?? "未知错误")"
        case .decodingError(let err):
            return "解码失败: \(err.localizedDescription)"
        case .networkError(let err):
            return "网络错误: \(err.localizedDescription)"
        }
    }

    /// Machine-readable error code from backend
    var errorCode: String? {
        if case .httpError(_, _, let code) = self { return code }
        return nil
    }

    /// User-facing Chinese error message based on error code
    var localizedChineseMessage: String {
        if case .httpError(_, _, let code) = self {
            return Self.chineseMessage(for: code)
        }
        switch self {
        case .networkError:
            return "网络连接失败，请检查网络后重试"
        default:
            return "请求失败，请稍后重试"
        }
    }

    /// Maps backend error codes to Chinese user-facing messages
    static func chineseMessage(for code: String?) -> String {
        switch code {
        case "invalid_login_code":      return "验证码错误或已过期"
        case "invalid_code":            return "验证码错误"
        case "code_expired":            return "验证码已过期，请重新发送"
        case "no_pending_verification": return "请先发送验证码"
        case "email_already_bound":     return "邮箱已绑定，无需重复操作"
        case "not_email_user":          return "当前不是邮箱账户，无法登出"
        case "user_not_found":          return "用户不存在"
        case "invalid_refresh_token":   return "登录已过期，请重新登录"
        default:                        return "请求失败，请稍后重试"
        }
    }
}

// MARK: - API Service

final class APIService {
    static let shared = APIService()

    private static let prodURL = "https://api.haibaoenglishlearning.com"
    private static let devURL = "http://localhost:5174"

    /// 后端地址：
    /// - 海豹英语-Prod scheme → 环境变量 USE_PROD_API=1 → 生产地址（可断点调试）
    /// - 海豹英语 scheme (Debug) → localhost
    /// - Release (Archive/TestFlight) → 生产地址
    private let baseURL: String = {
        #if DEBUG
        if ProcessInfo.processInfo.environment["USE_PROD_API"] == "1" {
            return prodURL
        }
        return devURL
        #else
        return prodURL
        #endif
    }()

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

    private func makeRequest(path: String, method: String = "GET", body: Data? = nil, skipAuth: Bool = false) -> URLRequest {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !skipAuth, let token = AuthTokenStore.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = body
        }
        return request
    }

    /// 发起请求并解码 JSON 响应
    private func fetch<T: Decodable>(_ type: T.Type, request: URLRequest) async throws -> T {
        let (decoded, _) = try await fetchWithRawData(type, request: request)
        return decoded
    }

    /// 发起请求，返回解码结果 + 原始 Data（用于本地存储历史）
    private func fetchWithRawData<T: Decodable>(_ type: T.Type, request: URLRequest) async throws -> (T, Data) {
        let start = CFAbsoluteTimeGetCurrent()

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logRoundTrip(request: request, error: error, duration: CFAbsoluteTimeGetCurrent() - start)
            throw APIServiceError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            logRoundTrip(request: request, error: URLError(.badServerResponse), duration: CFAbsoluteTimeGetCurrent() - start)
            throw APIServiceError.networkError(URLError(.badServerResponse))
        }

        logRoundTrip(request: request, response: httpResponse, data: data, duration: CFAbsoluteTimeGetCurrent() - start)

        guard (200...299).contains(httpResponse.statusCode) else {
            let apiError = try? decoder.decode(APIError.self, from: data)
            throw APIServiceError.httpError(statusCode: httpResponse.statusCode, message: apiError?.message, code: apiError?.code)
        }

        do {
            let decoded = try decoder.decode(type, from: data)
            return (decoded, data)
        } catch {
            #if DEBUG
            print("[API] ❌ 解码失败(\(T.self)): \(error)")
            #endif
            throw APIServiceError.decodingError(error)
        }
    }

    /// 发起请求，期望 204 No Content
    private func fetchNoContent(request: URLRequest) async throws {
        let start = CFAbsoluteTimeGetCurrent()

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logRoundTrip(request: request, error: error, duration: CFAbsoluteTimeGetCurrent() - start)
            throw APIServiceError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            logRoundTrip(request: request, error: URLError(.badServerResponse), duration: CFAbsoluteTimeGetCurrent() - start)
            throw APIServiceError.networkError(URLError(.badServerResponse))
        }

        logRoundTrip(request: request, response: httpResponse, data: data, duration: CFAbsoluteTimeGetCurrent() - start)

        guard (200...299).contains(httpResponse.statusCode) else {
            let apiError = try? decoder.decode(APIError.self, from: data)
            throw APIServiceError.httpError(statusCode: httpResponse.statusCode, message: apiError?.message, code: apiError?.code)
        }
    }

    // MARK: - 日志（响应回来后一次性输出）

    private func logRoundTrip(request: URLRequest, response: HTTPURLResponse? = nil, data: Data? = nil, error: Error? = nil, duration: CFAbsoluteTime) {
        #if DEBUG
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? ""
        let query = request.url?.query.map { "?\($0)" } ?? ""
        let ms = String(format: "%.0fms", duration * 1000)

        var lines: [String] = []
        lines.append("┌─[API] \(method) \(path)\(query)")

        // Request headers（只打有意义的）
        if let auth = request.value(forHTTPHeaderField: "Authorization"), auth.hasPrefix("Bearer ") {
            let token = String(auth.dropFirst(7))
            let preview = token.prefix(8) + "…" + token.suffix(8)
            lines.append("│  ➡️ 🔑 Authorization: Bearer \(preview)")
        } else {
            lines.append("│  ➡️ 🔓 No Authorization header")
        }

        // Request body
        if let body = request.httpBody, let str = String(data: body, encoding: .utf8) {
            let preview = str.count > 200 ? String(str.prefix(200)) + "…" : str
            lines.append("│  ➡️ 📦 \(preview)")
        }

        // Response
        if let response, let data {
            let status = response.statusCode
            let icon = (200...299).contains(status) ? "✅" : "❌"
            let size = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
            let contentType = response.value(forHTTPHeaderField: "Content-Type") ?? ""
            lines.append("│  ⬅️ \(icon) \(status) · \(size) · \(contentType)")

            // Response body（最多打印 2000 字符，方便调试 JSON 格式）
            if let body = String(data: data, encoding: .utf8) {
                let preview = body.count > 2000 ? String(body.prefix(2000)) + "\n│  … (truncated)" : body
                lines.append("│  ⬅️ 📦 \(preview)")
            }
        }

        // Error
        if let error {
            lines.append("│  ⬅️ ❌ \(error.localizedDescription)")
        }

        lines.append("└─[\(ms)]")
        print(lines.joined(separator: "\n"))
        #endif
    }

    // MARK: - 1. 获取练习题组

    /// 获取选择题 / 填空题 / 翻译题 等非阅读题型
    func fetchQuestions<T: Codable>(
        questionType: String,
        textbookCode: String,
        count: Int = 5
    ) async throws -> (questions: [T], remaining: Int, rawData: Data) {
        let path = "/api/v1/practice/questions?questionType=\(questionType)&textbookCode=\(textbookCode)&count=\(count)"
        let request = makeRequest(path: path)
        let (resp, data) = try await fetchWithRawData(QuestionsResponse<[T]>.self, request: request)
        return (resp.questions, resp.remaining ?? 0, data)
    }

    /// 获取阅读理解题（passages 结构）
    func fetchReadingQuestions(
        textbookCode: String,
        count: Int = 3
    ) async throws -> (response: ReadingQuestionsResponse, rawData: Data) {
        let path = "/api/v1/practice/questions?questionType=reading&textbookCode=\(textbookCode)&count=\(count)"
        let request = makeRequest(path: path)
        return try await fetchWithRawData(ReadingQuestionsResponse.self, request: request)
    }

    // MARK: - 便捷方法：按题型获取

    func fetchMCQQuestions(textbookCode: String, count: Int = 5) async throws -> (questions: [APIMCQQuestion], remaining: Int, rawData: Data) {
        return try await fetchQuestions(questionType: "multipleChoice", textbookCode: textbookCode, count: count)
    }

    func fetchClozeQuestions(textbookCode: String, count: Int = 5) async throws -> (questions: [APIClozeQuestion], remaining: Int, rawData: Data) {
        return try await fetchQuestions(questionType: "cloze", textbookCode: textbookCode, count: count)
    }

    func fetchTranslationQuestions(textbookCode: String, count: Int = 5) async throws -> (questions: [APITranslationQuestion], remaining: Int, rawData: Data) {
        return try await fetchQuestions(questionType: "translation", textbookCode: textbookCode, count: count)
    }

    func fetchRewritingQuestions(textbookCode: String, count: Int = 5) async throws -> (questions: [APIRewritingQuestion], remaining: Int, rawData: Data) {
        return try await fetchQuestions(questionType: "rewriting", textbookCode: textbookCode, count: count)
    }

    func fetchErrorCorrectionQuestions(textbookCode: String, count: Int = 5) async throws -> (questions: [APIErrorCorrectionQuestion], remaining: Int, rawData: Data) {
        return try await fetchQuestions(questionType: "errorCorrection", textbookCode: textbookCode, count: count)
    }

    func fetchOrderingQuestions(textbookCode: String, count: Int = 5) async throws -> (questions: [APIOrderingQuestion], remaining: Int, rawData: Data) {
        return try await fetchQuestions(questionType: "sentenceOrdering", textbookCode: textbookCode, count: count)
    }

    func fetchListeningQuestions(textbookCode: String, count: Int = 5) async throws -> (questions: [APIListeningQuestion], remaining: Int, rawData: Data) {
        return try await fetchQuestions(questionType: "listening", textbookCode: textbookCode, count: count)
    }

    func fetchSpeakingQuestions(textbookCode: String, count: Int = 5) async throws -> (questions: [APISpeakingQuestion], remaining: Int, rawData: Data) {
        return try await fetchQuestions(questionType: "speaking", textbookCode: textbookCode, count: count)
    }

    func fetchVocabularyQuestions(textbookCode: String, count: Int = 5) async throws -> (questions: [APIVocabularyQuestion], remaining: Int, rawData: Data) {
        return try await fetchQuestions(questionType: "vocabulary", textbookCode: textbookCode, count: count)
    }

    func fetchGrammarQuestions(textbookCode: String, count: Int = 5) async throws -> (questions: [APIGrammarQuestion], remaining: Int, rawData: Data) {
        return try await fetchQuestions(questionType: "grammar", textbookCode: textbookCode, count: count)
    }

    func fetchScenarioQuestions(scenarioType: String, textbookCode: String, count: Int = 5) async throws -> (questions: [APIScenarioQuestion], remaining: Int, rawData: Data) {
        return try await fetchQuestions(questionType: scenarioType, textbookCode: textbookCode, count: count)
    }

    // MARK: - 2. 今日推荐套餐

    func fetchTodayPackage(textbookCode: String) async throws -> (response: TodayPackageResponse, rawData: Data) {
        let path = "/api/v1/practice/today-package?textbookCode=\(textbookCode)"
        let request = makeRequest(path: path)
        return try await fetchWithRawData(TodayPackageResponse.self, request: request)
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

    func reportQuestion(questionId: String, reason: String? = nil, description: String? = nil, questionType: String? = nil) async throws -> ReportResponse {
        let body = try JSONEncoder().encode(ReportRequest(questionId: questionId, reason: reason, description: description, questionType: questionType))
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

    // MARK: - 9. 词典查询

    /// 查询单词 (GET /api/v1/dictionary/{word})
    /// 后端会先查 Cosmos DB 缓存，未命中则 AI 生成
    func lookupWord(_ word: String) async throws -> Word {
        let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word
        let request = makeRequest(path: "/api/v1/dictionary/\(encoded)")
        return try await fetch(Word.self, request: request)
    }

    // MARK: - Auth Endpoints

    /// POST /api/v1/auth/device — auto sign-in with device ID (zero friction)
    func deviceSignIn(deviceId: String) async throws -> AuthResponse {
        struct DeviceSignInBody: Encodable {
            let deviceId: String
        }
        let body = try JSONEncoder().encode(DeviceSignInBody(deviceId: deviceId))
        let request = makeRequest(path: "/api/v1/auth/device", method: "POST", body: body, skipAuth: true)
        return try await fetch(AuthResponse.self, request: request)
    }

    /// POST /api/v1/auth/refresh — exchange refresh token for new token pair
    func refreshAuthToken(refreshToken: String) async throws -> AuthResponse {
        struct RefreshBody: Encodable { let refreshToken: String }
        let body = try JSONEncoder().encode(RefreshBody(refreshToken: refreshToken))
        let request = makeRequest(path: "/api/v1/auth/refresh", method: "POST", body: body, skipAuth: true)
        return try await fetch(AuthResponse.self, request: request)
    }

    /// POST /api/v1/auth/logout — revoke current refresh token
    func logout() async throws {
        let request = makeRequest(path: "/api/v1/auth/logout", method: "POST")
        try await fetchNoContent(request: request)
    }

    /// GET /api/v1/auth/me — fetch current user profile
    func fetchCurrentUser() async throws -> AuthUserProfile {
        let request = makeRequest(path: "/api/v1/auth/me")
        return try await fetch(AuthUserProfile.self, request: request)
    }

    // MARK: - Email Auth Endpoints

    /// POST /api/v1/auth/bind-email — send verification code to bind email
    func bindEmail(email: String) async throws {
        struct Body: Encodable { let email: String }
        let body = try JSONEncoder().encode(Body(email: email))
        let request = makeRequest(path: "/api/v1/auth/bind-email", method: "POST", body: body)
        try await fetchNoContent(request: request)
    }

    /// POST /api/v1/auth/verify-email — verify code to complete email binding
    func verifyEmail(code: String) async throws -> AuthResponse {
        struct Body: Encodable { let code: String }
        let body = try JSONEncoder().encode(Body(code: code))
        let request = makeRequest(path: "/api/v1/auth/verify-email", method: "POST", body: body)
        return try await fetch(AuthResponse.self, request: request)
    }

    /// POST /api/v1/auth/send-login-code — send passwordless login code
    func sendLoginCode(email: String) async throws {
        struct Body: Encodable { let email: String; let deviceId: String }
        let body = try JSONEncoder().encode(Body(email: email, deviceId: DeviceIdManager.shared.deviceId))
        let request = makeRequest(path: "/api/v1/auth/send-login-code", method: "POST", body: body, skipAuth: true)
        try await fetchNoContent(request: request)
    }

    /// POST /api/v1/auth/verify-login-code — verify code for passwordless login
    func verifyLoginCode(email: String, code: String) async throws -> AuthResponse {
        struct Body: Encodable { let email: String; let code: String; let deviceId: String }
        let body = try JSONEncoder().encode(Body(email: email, code: code, deviceId: DeviceIdManager.shared.deviceId))
        let request = makeRequest(path: "/api/v1/auth/verify-login-code", method: "POST", body: body, skipAuth: true)
        return try await fetch(AuthResponse.self, request: request)
    }

    /// POST /api/v1/auth/email-logout — logout from email account, revert to device user
    func emailLogout() async throws {
        let request = makeRequest(path: "/api/v1/auth/email-logout", method: "POST")
        try await fetchNoContent(request: request)
    }

    /// PATCH /api/v1/auth/profile — update user profile (level, textbook, semester)
    func updateProfile(level: String?, textbookCode: String?, semester: String?) async throws {
        struct Body: Encodable { let level: String?; let textbookCode: String?; let semester: String? }
        let body = try JSONEncoder().encode(Body(level: level, textbookCode: textbookCode, semester: semester))
        let request = makeRequest(path: "/api/v1/auth/profile", method: "PATCH", body: body)
        // We don't need the response — fire and forget from the caller's perspective
        let _: AuthUserProfile = try await fetch(AuthUserProfile.self, request: request)
    }
}
