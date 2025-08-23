//
//  Services.swift
//  Volingo
//
//  Created by jacob on 2025/8/10.
//

import Foundation
import SQLite3

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - 词典服务
class DictionaryService {
    static let shared = DictionaryService()
    private var database: OpaquePointer?
    private let databaseName = "learnEnglishDict.db"
    
    private init() {
        openDatabase()
    }
    
    deinit {
        closeDatabase()
    }
    
    // MARK: - 数据库连接管理
    private func openDatabase() {
        guard let databasePath = getDatabasePath() else {
            print("❌ 无法找到数据库文件路径")
            return
        }
        
        if sqlite3_open(databasePath.cString(using: .utf8), &database) != SQLITE_OK {
            print("❌ 无法打开数据库: \(String(cString: sqlite3_errmsg(database)))")
            database = nil
        } else {
            print("✅ 数据库连接成功")
        }
    }
    
    private func closeDatabase() {
        if sqlite3_close(database) != SQLITE_OK {
            print("❌ 无法关闭数据库: \(String(cString: sqlite3_errmsg(database)))")
        }
        database = nil
    }
    
    private func getDatabasePath() -> String? {
        // 首先尝试从Bundle中获取数据库文件
        if let bundlePath = Bundle.main.path(forResource: "learnEnglishDict", ofType: "db") {
            return bundlePath
        }
        
        // 如果Bundle中没有，尝试从Services目录获取（开发环境）
        let currentPath = "/Users/jacob/work/learnEnglishiOS/Volingo/Volingo/Services/learnEnglishDict.db"
        if FileManager.default.fileExists(atPath: currentPath) {
            return currentPath
        }
        
        return nil
    }
    
    // MARK: - 单词查询功能
    func searchWord(_ query: String) async throws -> [Word] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let words = try self.performWordSearch(query)
                    continuation.resume(returning: words)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func performWordSearch(_ query: String) throws -> [Word] {
        guard let database = self.database else {
            throw WordSearchError.databaseNotFound
        }
        
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !searchQuery.isEmpty else {
            throw WordSearchError.invalidQuery
        }
        
        // SQL查询语句 - 支持精确匹配和前缀匹配
        let sql = """
            SELECT word, json_data, A1, A2, B1, B2, C1, Middle_School, High_School, 
                   CET4, CET6, Graduate_Exam, TOEFL, SAT
            FROM dictionary 
            WHERE word = ? OR word LIKE ? 
            ORDER BY 
                CASE WHEN word = ? THEN 0 ELSE 1 END,
                LENGTH(word),
                word
            LIMIT 50;
            """
        
        var statement: OpaquePointer?
        var words: [Word] = []
        
        defer {
            sqlite3_finalize(statement)
        }
        
        if sqlite3_prepare_v2(database, sql, -1, &statement, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(database))
            throw WordSearchError.databaseError(errorMessage)
        }
        
        // 绑定查询参数
        let likePattern = "\(searchQuery)%"

        searchQuery.withCString { cString in
            sqlite3_bind_text(statement, 1, cString, -1, SQLITE_TRANSIENT)
        }
        likePattern.withCString { cString in
            sqlite3_bind_text(statement, 2, cString, -1, SQLITE_TRANSIENT)
        }
        searchQuery.withCString { cString in
            sqlite3_bind_text(statement, 3, cString, -1, SQLITE_TRANSIENT)
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let record = parseWordRecord(from: statement) {
                do {
                    let word = try parseWordFromJSON(record: record)
                    words.append(word)
                } catch {
                    print("⚠️ 解析单词数据失败: \(record.word), 错误: \(error)")
                    continue
                }
            }
        }
        
        return words
    }
    
    func getWordDetails(_ wordQuery: String) async throws -> Word? {
        let results = try await searchWord(wordQuery)
        return results.first { $0.word.lowercased() == wordQuery.lowercased() }
    }
    
    // MARK: - 数据解析
    private func parseWordRecord(from statement: OpaquePointer?) -> WordDatabaseRecord? {
        guard let statement = statement else { return nil }
        
        guard let wordCString = sqlite3_column_text(statement, 0),
              let jsonCString = sqlite3_column_text(statement, 1) else {
            return nil
        }
        
        let word = String(cString: wordCString)
        let jsonData = String(cString: jsonCString)
        
        // 解析词汇级别
        let levels = WordLevels(
            a1: sqlite3_column_int(statement, 2) != 0,
            a2: sqlite3_column_int(statement, 3) != 0,
            b1: sqlite3_column_int(statement, 4) != 0,
            b2: sqlite3_column_int(statement, 5) != 0,
            c1: sqlite3_column_int(statement, 6) != 0,
            middleSchool: sqlite3_column_int(statement, 7) != 0,
            highSchool: sqlite3_column_int(statement, 8) != 0,
            cet4: sqlite3_column_int(statement, 9) != 0,
            cet6: sqlite3_column_int(statement, 10) != 0,
            graduateExam: sqlite3_column_int(statement, 11) != 0,
            toefl: sqlite3_column_int(statement, 12) != 0,
            sat: sqlite3_column_int(statement, 13) != 0
        )
        
        return WordDatabaseRecord(word: word, jsonData: jsonData, levels: levels)
    }
    
    private func parseWordFromJSON(record: WordDatabaseRecord) throws -> Word {
        guard let jsonData = record.jsonData.data(using: .utf8) else {
            throw WordSearchError.decodingError("无法转换JSON数据")
        }
        
        do {
            let decoder = JSONDecoder()
            var word = try decoder.decode(Word.self, from: jsonData)
            
            // 添加词汇级别信息
            let wordWithLevels = Word(
                word: word.word,
                lemma: word.lemma,
                isDerived: word.isDerived,
                phonetic: word.phonetic,
                senses: word.senses,
                exchange: word.exchange,
                synonyms: word.synonyms.filter { !$0.isEmpty },
                antonyms: word.antonyms.filter { !$0.isEmpty },
                levels: record.levels
            )
            
            return wordWithLevels
        } catch {
            throw WordSearchError.decodingError("JSON解析失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 辅助功能
    func searchWordsByLevel(_ level: String, limit: Int = 100) async throws -> [Word] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let words = try self.performLevelSearch(level, limit: limit)
                    continuation.resume(returning: words)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func performLevelSearch(_ level: String, limit: Int) throws -> [Word] {
        guard let database = self.database else {
            throw WordSearchError.databaseNotFound
        }
        
        let sql = """
            SELECT word, json_data, A1, A2, B1, B2, C1, Middle_School, High_School, 
                   CET4, CET6, Graduate_Exam, TOEFL, SAT
            FROM dictionary 
            WHERE \(level) = 1
            ORDER BY word
            LIMIT ?;
            """
        
        var statement: OpaquePointer?
        var words: [Word] = []
        
        defer {
            sqlite3_finalize(statement)
        }
        
        if sqlite3_prepare_v2(database, sql, -1, &statement, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(database))
            throw WordSearchError.databaseError(errorMessage)
        }
        
        sqlite3_bind_int(statement, 1, Int32(limit))
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let record = parseWordRecord(from: statement) {
                do {
                    let word = try parseWordFromJSON(record: record)
                    words.append(word)
                } catch {
                    continue
                }
            }
        }
        
        return words
    }
}

// MARK: - 生词本服务
class WordbookService {
    static let shared = WordbookService()
    private init() {}
    
    // TODO: 实现本地 JSON 文件存储
    func saveWord(_ word: Word) throws {
        // 保存单词到本地 JSON 文件
    }
    
    func loadSavedWords() throws -> [SavedWord] {
        // 从本地 JSON 文件加载生词
        return []
    }
    
    func updateWord(_ savedWord: SavedWord) throws {
        // 更新生词信息
    }
    
    func deleteWord(_ wordId: String) throws {
        // 删除生词
    }
}

// MARK: - 网络服务
class NetworkService {
    static let shared = NetworkService()
    private init() {}
    
    // TODO: 实现网络请求逻辑
    func analyzeWriting(_ text: String) async throws -> [WritingFeedback] {
        // 发送写作文本到后台分析
        return []
    }
    
    func uploadAudio(_ audioData: Data) async throws -> AudioAnalysisResult {
        // 上传音频进行语音评分
        return AudioAnalysisResult(score: 0, feedback: "")
    }
    
    func syncUserData(_ userProfile: UserProfile) async throws {
        // 同步用户数据到云端
    }
}

struct AudioAnalysisResult {
    let score: Double
    let feedback: String
}

// MARK: - 存储服务
class StorageService {
    static let shared = StorageService()
    private init() {}
    
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    // TODO: 实现本地文件存储逻辑
    func saveToFile<T: Codable>(_ object: T, filename: String) throws {
        // 保存对象到文件
    }
    
    func loadFromFile<T: Codable>(_ type: T.Type, filename: String) throws -> T {
        // 从文件加载对象
        throw StorageError.fileNotFound
    }
    
    func deleteFile(_ filename: String) throws {
        // 删除文件
    }
}

enum StorageError: Error {
    case fileNotFound
    case encodingFailed
    case decodingFailed
}
