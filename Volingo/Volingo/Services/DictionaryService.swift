//
//  DictionaryService.swift
//  海豹英语
//
//  Rewritten for new architecture: local SQLite cache (wordCache.db) + backend API + AI fallback.
//  Old learnEnglishDict.db has been removed.
//

import Foundation
import SQLite3

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - 词典服务（新架构）
// 查词流程: ① 本地 wordCache.db → ② 后端 API → ③ 写入本地缓存
class DictionaryService {
    static let shared = DictionaryService()
    private var database: OpaquePointer?
    private let cacheDbName = "wordCache.db"
    
    private init() {
        openOrCreateCacheDatabase()
    }
    
    deinit {
        if let db = database {
            sqlite3_close(db)
        }
    }
    
    // MARK: - 缓存数据库管理
    
    /// 获取 Documents 目录下的缓存数据库路径（可写）
    private func getCacheDatabasePath() -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent(cacheDbName).path
    }
    
    /// 打开或创建本地缓存数据库
    private func openOrCreateCacheDatabase() {
        let path = getCacheDatabasePath()
        
        if sqlite3_open(path, &database) != SQLITE_OK {
            print("❌ 无法打开/创建缓存数据库: \(String(cString: sqlite3_errmsg(database)))")
            database = nil
            return
        }
        
        // 创建缓存表（如果不存在）
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS word_cache (
                word TEXT PRIMARY KEY,
                json_data TEXT NOT NULL,
                cached_at TEXT NOT NULL DEFAULT (datetime('now'))
            );
            """
        
        if sqlite3_exec(database, createTableSQL, nil, nil, nil) != SQLITE_OK {
            print("❌ 创建缓存表失败: \(String(cString: sqlite3_errmsg(database)))")
        } else {
            print("✅ 词典缓存数据库就绪")
        }
    }
    
    // MARK: - 查词（核心方法）
    
    /// 查询单词：本地缓存优先 → 后端 API 兜底
    func searchWord(_ query: String) async throws -> [Word] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }
        
        // ① 先查本地缓存
        if let cached = lookupCache(trimmed) {
            return [cached]
        }
        
        // ② 本地未命中，调后端 API
        let word = try await fetchFromBackend(trimmed)
        
        // ③ 写入本地缓存（永久保存）
        saveToCache(word)
        
        return [word]
    }
    
    /// 获取单词详情（精确匹配）
    func getWordDetails(_ wordQuery: String) async throws -> Word? {
        let results = try await searchWord(wordQuery)
        return results.first { $0.word.lowercased() == wordQuery.lowercased() }
    }
    
    // MARK: - 本地缓存操作
    
    /// 从本地 SQLite 缓存查询
    private func lookupCache(_ word: String) -> Word? {
        guard let db = database else { return nil }
        
        let sql = "SELECT json_data FROM word_cache WHERE word = ? LIMIT 1;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        
        _ = word.withCString { cString in
            sqlite3_bind_text(statement, 1, cString, -1, SQLITE_TRANSIENT)
        }
        
        guard sqlite3_step(statement) == SQLITE_ROW,
              let jsonCString = sqlite3_column_text(statement, 0) else {
            return nil
        }
        
        let jsonString = String(cString: jsonCString)
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        
        return try? JSONDecoder().decode(Word.self, from: jsonData)
    }
    
    /// 将词条写入本地缓存（永久保存）
    private func saveToCache(_ word: Word) {
        guard let db = database else { return }
        guard let jsonData = try? JSONEncoder().encode(word),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        let sql = "INSERT OR REPLACE INTO word_cache (word, json_data) VALUES (?, ?);"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        
        let wordKey = word.word.lowercased()
        _ = wordKey.withCString { cString in
            sqlite3_bind_text(statement, 1, cString, -1, SQLITE_TRANSIENT)
        }
        _ = jsonString.withCString { cString in
            sqlite3_bind_text(statement, 2, cString, -1, SQLITE_TRANSIENT)
        }
        
        if sqlite3_step(statement) != SQLITE_DONE {
            print("⚠️ 缓存写入失败: \(String(cString: sqlite3_errmsg(db)))")
        }
    }
    
    // MARK: - 后端 API 调用
    
    /// 从后端 API 获取词条 (GET /api/v1/dictionary/{word})
    private func fetchFromBackend(_ word: String) async throws -> Word {
        return try await APIService.shared.lookupWord(word)
    }
    
    // MARK: - 缓存管理
    
    /// 清除所有本地缓存
    func clearCache() {
        guard let db = database else { return }
        sqlite3_exec(db, "DELETE FROM word_cache;", nil, nil, nil)
        print("🗑️ 词典缓存已清除")
    }
    
    /// 获取缓存词条数量
    func getCachedWordCount() -> Int {
        guard let db = database else { return 0 }
        
        let sql = "SELECT COUNT(*) FROM word_cache;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        
        return Int(sqlite3_column_int(statement, 0))
    }
}
