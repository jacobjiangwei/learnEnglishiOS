//
//  FSRSEngine.swift
//  Volingo
//
//  FSRS (Free Spaced Repetition Scheduler) 算法引擎
//  参考: https://github.com/open-spaced-repetition/swift-fsrs
//

import Foundation

// MARK: - 记忆状态
enum MemoryState: String, Codable {
    case new          // 新词，从未复习
    case learning     // 学习中（首次学习阶段）
    case review       // 复习（已进入长期记忆）
    case relearning   // 重新学习（答错后回退）
}

// MARK: - FSRS 评分
enum FSRSRating: Int, Codable {
    case again = 1  // 完全不记得 / 答错
    case hard  = 2  // 犹豫很久 / 连线配错1次
    case good  = 3  // 记得
    case easy  = 4  // 秒答
}

// MARK: - FSRS 记忆参数
struct FSRSMemory: Codable {
    var state: MemoryState = .new
    var stability: Double = 0.0       // 记忆稳定性（天）
    var difficulty: Double = 0.3      // 0~1，这个词对用户的难度
    var lastReviewDate: Date? = nil
    var nextReviewDate: Date? = nil
    var reps: Int = 0                 // 已复习次数
    var lapses: Int = 0               // 遗忘次数（答错回退次数）
}

// MARK: - FSRS 算法引擎
struct FSRSEngine {
    
    // 默认参数（基于 FSRS-5 论文推荐值）
    private static let w: [Double] = [
        0.4072, 1.1829, 3.1262, 15.4722,  // w0-w3: 初始 stability
        7.2102, 0.5316, 1.0651, 0.0589,    // w4-w7: difficulty
        1.5330, 0.1636, 1.0120,             // w8-w10: stability after success
        1.9395, 0.1100,                      // w11-w12: stability after failure
        0.0000, 0.3442, 2.1730, 0.2700,     // w13-w16: short-term scheduling
        2.2035                               // w17
    ]
    
    // 期望记忆保留率
    private static let requestRetention: Double = 0.9
    
    // MARK: - 核心调度函数
    
    /// 根据评分更新记忆状态，返回新的 FSRSMemory
    static func schedule(memory: FSRSMemory, rating: FSRSRating, now: Date = Date()) -> FSRSMemory {
        var m = memory
        
        switch m.state {
        case .new:
            m = scheduleNew(memory: m, rating: rating, now: now)
        case .learning, .relearning:
            m = scheduleLearning(memory: m, rating: rating, now: now)
        case .review:
            m = scheduleReview(memory: m, rating: rating, now: now)
        }
        
        m.lastReviewDate = now
        m.reps += 1
        
        return m
    }
    
    // MARK: - 新词调度
    
    private static func scheduleNew(memory: FSRSMemory, rating: FSRSRating, now: Date) -> FSRSMemory {
        var m = memory
        
        // 初始 difficulty
        m.difficulty = initDifficulty(rating: rating)
        
        // 初始 stability
        m.stability = initStability(rating: rating)
        
        switch rating {
        case .again:
            m.state = .learning
            m.nextReviewDate = now.addingTimeInterval(60) // 1 分钟后
        case .hard:
            m.state = .learning
            m.nextReviewDate = now.addingTimeInterval(5 * 60) // 5 分钟后
        case .good:
            m.state = .learning
            m.nextReviewDate = nextReviewDate(stability: m.stability, now: now)
        case .easy:
            m.state = .review
            m.nextReviewDate = nextReviewDate(stability: m.stability, now: now)
        }
        
        return m
    }
    
    // MARK: - Learning/Relearning 调度
    
    private static func scheduleLearning(memory: FSRSMemory, rating: FSRSRating, now: Date) -> FSRSMemory {
        var m = memory
        
        switch rating {
        case .again:
            m.stability = max(m.stability * 0.5, 0.5)
            m.difficulty = clampDifficulty(m.difficulty + 0.1)
            m.state = m.state == .learning ? .learning : .relearning
            m.nextReviewDate = now.addingTimeInterval(60) // 1 分钟后
            if m.state == .relearning {
                m.lapses += 1
            }
        case .hard:
            m.stability = max(m.stability * 1.2, 0.5)
            m.difficulty = clampDifficulty(m.difficulty + 0.05)
            m.nextReviewDate = now.addingTimeInterval(10 * 60) // 10 分钟后
        case .good:
            m.stability = max(m.stability * 2.5, 1.0)
            m.state = .review
            m.nextReviewDate = nextReviewDate(stability: m.stability, now: now)
        case .easy:
            m.stability = max(m.stability * 3.5, 2.0)
            m.difficulty = clampDifficulty(m.difficulty - 0.05)
            m.state = .review
            m.nextReviewDate = nextReviewDate(stability: m.stability, now: now)
        }
        
        return m
    }
    
    // MARK: - Review 调度
    
    private static func scheduleReview(memory: FSRSMemory, rating: FSRSRating, now: Date) -> FSRSMemory {
        var m = memory
        
        // 计算实际经过天数
        let elapsedDays: Double
        if let lastReview = m.lastReviewDate {
            elapsedDays = max(now.timeIntervalSince(lastReview) / 86400.0, 0)
        } else {
            elapsedDays = 0
        }
        
        // 当前记忆保留率
        let retrievability = pow(1 + elapsedDays / (9 * m.stability), -1)
        
        switch rating {
        case .again:
            m.lapses += 1
            m.difficulty = clampDifficulty(m.difficulty + 0.1)
            // stability 重置（遗忘后重新学习）
            m.stability = max(
                w[11] * pow(m.difficulty, -w[12]) * (pow(m.stability + 1, w[13]) - 1) * exp((1 - retrievability) * w[14]),
                0.5
            )
            m.state = .relearning
            m.nextReviewDate = now.addingTimeInterval(60) // 1 分钟后重新学习
            
        case .hard:
            m.difficulty = clampDifficulty(m.difficulty + 0.05)
            let newStability = m.stability * successStabilityFactor(
                difficulty: m.difficulty,
                stability: m.stability,
                retrievability: retrievability,
                rating: .hard
            )
            m.stability = max(newStability, m.stability + 0.1) // 至少微增
            m.nextReviewDate = nextReviewDate(stability: m.stability, now: now)
            
        case .good:
            let newStability = m.stability * successStabilityFactor(
                difficulty: m.difficulty,
                stability: m.stability,
                retrievability: retrievability,
                rating: .good
            )
            m.stability = max(newStability, m.stability + 0.5)
            m.nextReviewDate = nextReviewDate(stability: m.stability, now: now)
            
        case .easy:
            m.difficulty = clampDifficulty(m.difficulty - 0.05)
            let newStability = m.stability * successStabilityFactor(
                difficulty: m.difficulty,
                stability: m.stability,
                retrievability: retrievability,
                rating: .easy
            )
            m.stability = max(newStability, m.stability + 1.0)
            m.nextReviewDate = nextReviewDate(stability: m.stability, now: now)
        }
        
        return m
    }
    
    // MARK: - 辅助计算
    
    /// 初始 difficulty
    private static func initDifficulty(rating: FSRSRating) -> Double {
        let d = w[4] - exp(w[5] * Double(rating.rawValue - 1)) + 1
        return clampDifficulty(d / 10.0) // 归一化到 0~1
    }
    
    /// 初始 stability
    private static func initStability(rating: FSRSRating) -> Double {
        return max(w[rating.rawValue - 1], 0.5)
    }
    
    /// 成功后的 stability 增长因子
    private static func successStabilityFactor(
        difficulty: Double,
        stability: Double,
        retrievability: Double,
        rating: FSRSRating
    ) -> Double {
        let hardPenalty: Double = (rating == .hard) ? w[15] : 1.0
        let easyBonus: Double = (rating == .easy) ? w[16] : 1.0
        
        return 1 + exp(w[8]) *
            (11 - difficulty * 10) *
            pow(stability, -w[9]) *
            (exp((1 - retrievability) * w[10]) - 1) *
            hardPenalty *
            easyBonus
    }
    
    /// 根据 stability 计算下次复习日期
    private static func nextReviewDate(stability: Double, now: Date) -> Date {
        let intervalDays = max(stability, 0.5) // 最少半天
        let cappedDays = min(intervalDays, 365) // 最长 1 年
        return now.addingTimeInterval(cappedDays * 86400)
    }
    
    /// 限制 difficulty 在 0~1 之间
    private static func clampDifficulty(_ d: Double) -> Double {
        return max(0.0, min(1.0, d))
    }
    
    // MARK: - 查询工具
    
    /// 获取今日待复习词列表
    static func getWordsToReview(from words: [any FSRSReviewable], now: Date = Date()) -> [any FSRSReviewable] {
        return words.filter { word in
            guard let nextReview = word.fsrsMemory.nextReviewDate else {
                // 从未复习过的新词，应该复习
                return true
            }
            return nextReview <= now
        }
        .sorted { a, b in
            // 超期越久越优先
            let aOverdue = overdueWeight(for: a.fsrsMemory, now: now)
            let bOverdue = overdueWeight(for: b.fsrsMemory, now: now)
            return aOverdue > bOverdue
        }
    }
    
    /// 计算超期权重（用于排序）
    private static func overdueWeight(for memory: FSRSMemory, now: Date) -> Double {
        guard let nextReview = memory.nextReviewDate else { return 1000 } // 新词最高优先
        let overdueDays = now.timeIntervalSince(nextReview) / 86400.0
        return overdueDays
    }
}

// MARK: - 可复习协议
protocol FSRSReviewable {
    var fsrsMemory: FSRSMemory { get }
}
