//
//  AutocompleteService.swift
//  Volingo
//
//  Provides word auto-suggestions from a bundled SQLite database (words.db).
//  The database is read-only and loaded from the app bundle.
//

import Foundation
import SQLite3

class AutocompleteService {
    static let shared = AutocompleteService()
    private var database: OpaquePointer?
    
    private init() {
        openBundledDatabase()
    }
    
    deinit {
        if let db = database {
            sqlite3_close(db)
        }
    }
    
    // MARK: - 数据库
    
    private func openBundledDatabase() {
        guard let dbPath = Bundle.main.path(forResource: "words", ofType: "db") else {
            print("⚠️ 未找到 words.db，自动补全不可用")
            return
        }
        
        // 以只读方式打开
        if sqlite3_open_v2(dbPath, &database, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            print("❌ 无法打开 words.db: \(String(cString: sqlite3_errmsg(database)))")
            database = nil
            return
        }
        
        print("✅ 自动补全词库就绪")
    }
    
    // MARK: - 查询
    
    /// 根据前缀返回自动补全建议
    /// - Parameters:
    ///   - prefix: 用户输入的前缀
    ///   - limit: 最大返回数量（默认 10）
    /// - Returns: 匹配的单词列表（按字母序）
    func suggestions(for prefix: String, limit: Int = 10) -> [String] {
        guard let db = database else { return [] }
        
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, trimmed.count >= 1 else { return [] }
        
        // 前缀范围查询: word >= 'hel' AND word < 'hem'
        // 计算上界：最后一个字符 +1
        let upperBound = incrementLastChar(trimmed)
        
        let sql = "SELECT word FROM words WHERE word >= ? AND word < ? ORDER BY word LIMIT ?;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        
        _ = trimmed.withCString { cString in
            sqlite3_bind_text(statement, 1, cString, -1, SQLITE_TRANSIENT)
        }
        _ = upperBound.withCString { cString in
            sqlite3_bind_text(statement, 2, cString, -1, SQLITE_TRANSIENT)
        }
        sqlite3_bind_int(statement, 3, Int32(limit))
        
        var results: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 0) {
                results.append(String(cString: cString))
            }
        }
        
        return results
    }
    
    /// 检查单词是否存在于词库中
    func wordExists(_ word: String) -> Bool {
        guard let db = database else { return false }
        
        let sql = "SELECT 1 FROM words WHERE word = ? LIMIT 1;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return false }
        
        let lowered = word.lowercased()
        _ = lowered.withCString { cString in
            sqlite3_bind_text(statement, 1, cString, -1, SQLITE_TRANSIENT)
        }
        
        return sqlite3_step(statement) == SQLITE_ROW
    }
    
    // MARK: - 辅助
    
    /// 将字符串最后一个字符 +1，用于构造前缀查询上界
    /// "hel" → "hem", "ab" → "ac", "z" → "{"
    private func incrementLastChar(_ s: String) -> String {
        guard !s.isEmpty else { return s }
        var chars = Array(s)
        let last = chars.removeLast()
        let next = Character(UnicodeScalar(last.asciiValue! + 1))
        chars.append(next)
        return String(chars)
    }
}
