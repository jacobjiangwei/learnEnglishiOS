//
//  ReviewModels.swift
//  Volingo
//
//  复习题目模型 & 本地出题器
//

import Foundation

// MARK: - 题目类型
enum ReviewQuestionType: String, Codable {
    case engToChMCQ       // 英选中
    case chToEngMCQ       // 中选英
    case clozeFill        // 例句填空
    case listenSpell      // 听音拼写
    case matching         // 连线消消乐
}

// MARK: - 题目协议
protocol ReviewQuestion {
    var type: ReviewQuestionType { get }
    var targetWordIds: [String] { get }  // 涉及的 SavedWord IDs
}

// MARK: - 选择题
struct ReviewMCQQuestion: ReviewQuestion {
    let type: ReviewQuestionType        // .engToChMCQ or .chToEngMCQ
    let targetWordIds: [String]
    let wordId: String
    let prompt: String            // 题目显示文本
    let correctAnswer: String
    let options: [String]         // 4 个选项（含正确答案，已打乱）
}

// MARK: - 例句填空题
struct ReviewClozeQuestion: ReviewQuestion {
    let type: ReviewQuestionType = .clozeFill
    let targetWordIds: [String]
    let wordId: String
    let sentence: String          // 含 ______ 的句子
    let translation: String       // 中文翻译
    let answer: String            // 正确答案
}

// MARK: - 听音拼写题
struct ReviewSpellQuestion: ReviewQuestion {
    let type: ReviewQuestionType = .listenSpell
    let targetWordIds: [String]
    let wordId: String
    let wordToSpell: String       // 要拼写的单词
    let definition: String        // 中文释义（拼写后显示）
}

// MARK: - 连线消消乐题
struct ReviewMatchingQuestion: ReviewQuestion {
    let type: ReviewQuestionType = .matching
    let targetWordIds: [String]
    let pairs: [(id: String, english: String, chinese: String)]
}

// MARK: - 本地出题器
struct QuestionGenerator {
    
    // 预置干扰词库
    private static let fallbackTranslations: [String: [String]] = [
        "adj.": ["明显的","相关的","充足的","频繁的","谨慎的","模糊的","严格的","灵活的","脆弱的","特殊的",
                  "复杂的","简单的","重要的","困难的","独立的","必要的","合理的","敏感的","积极的","消极的"],
        "n.":   ["障碍","趋势","现象","本质","特征","结构","机制","策略","原则","概念",
                  "目标","环境","资源","方法","过程","结果","影响","因素","条件","标准"],
        "v.":   ["获取","维持","促进","削弱","忽略","探索","评估","揭示","转变","实现",
                  "处理","建立","提供","发展","改善","减少","增加","保护","支持","创造"],
        "adv.": ["显然","频繁地","逐渐地","大概","偶尔","彻底地","立即","相当","几乎","完全"]
    ]
    
    private static let fallbackEnglishWords: [String: [String]] = [
        "adj.": ["relevant","abundant","frequent","obvious","cautious","vague","strict","flexible",
                  "fragile","specific","complex","essential","reasonable","sensitive","independent"],
        "n.":   ["obstacle","tendency","phenomenon","essence","feature","structure","mechanism",
                  "strategy","principle","concept","objective","resource","method","factor","standard"],
        "v.":   ["obtain","maintain","promote","undermine","neglect","explore","evaluate","reveal",
                  "transform","accomplish","establish","provide","develop","improve","reduce"],
        "adv.": ["obviously","frequently","gradually","approximately","occasionally","thoroughly",
                  "immediately","considerably","almost","entirely"]
    ]
    
    // MARK: - 为一组待复习词生成一个 Session 的题目
    
    static func generateSession(words: [SavedWord], maxQuestions: Int = 15) -> [any ReviewQuestion] {
        guard !words.isEmpty else { return [] }
        
        var questions: [any ReviewQuestion] = [] as [any ReviewQuestion]
        var coveredWordIds = Set<String>()
        var remaining = Array(words)
        
        // 1. 如果词够多，先出一组连线消消乐
        if remaining.count >= 4 {
            let matchCount = min(6, remaining.count)
            let matchWords = Array(remaining.prefix(matchCount))
            let matchQ = generateMatchingQuestion(from: matchWords)
            questions.append(matchQ)
            coveredWordIds.formUnion(matchQ.targetWordIds)
            remaining.removeFirst(matchCount)
        }
        
        // 2. 为剩余词逐个出题（随机题型）
        for word in remaining {
            if questions.count >= maxQuestions { break }
            let q = generateSingleQuestion(for: word)
            questions.append(q)
            coveredWordIds.insert(word.id)
        }
        
        // 3. 如果还没到上限，且还有第二组连线的词
        if questions.count < maxQuestions && coveredWordIds.count >= 8 {
            // 从已覆盖的词中再挑一组连线
            let secondBatch = words.filter { coveredWordIds.contains($0.id) }.shuffled()
            if secondBatch.count >= 4 {
                let matchCount = min(6, secondBatch.count)
                let matchWords = Array(secondBatch.prefix(matchCount))
                questions.append(generateMatchingQuestion(from: matchWords))
            }
        }
        
        // 4. 补充未被覆盖的词
        let uncovered = words.filter { !coveredWordIds.contains($0.id) }
        for word in uncovered {
            if questions.count >= maxQuestions { break }
            questions.append(generateSingleQuestion(for: word))
        }
        
        return questions
    }
    
    // MARK: - 为单个词随机出一道题
    
    static func generateSingleQuestion(for word: SavedWord, preferredType: ReviewQuestionType? = nil) -> any ReviewQuestion {
        let type: ReviewQuestionType
        if let preferred = preferredType {
            type = preferred
        } else {
            // 根据记忆状态选题型
            switch word.memory.state {
            case .new, .relearning:
                type = [ReviewQuestionType.engToChMCQ, .chToEngMCQ].randomElement()!
            case .learning:
                type = [ReviewQuestionType.engToChMCQ, .chToEngMCQ, .clozeFill].randomElement()!
            case .review:
                type = [ReviewQuestionType.engToChMCQ, .chToEngMCQ, .clozeFill, .listenSpell].randomElement()!
            }
        }
        
        switch type {
        case .engToChMCQ:
            return generateEngToChMCQ(for: word)
        case .chToEngMCQ:
            return generateChToEngMCQ(for: word)
        case .clozeFill:
            // 需要例句，没有则fallback到选择题
            if word.word.senses.first?.examples.first != nil {
                return generateClozeQuestion(for: word)
            } else {
                return generateEngToChMCQ(for: word)
            }
        case .listenSpell:
            return generateSpellQuestion(for: word)
        case .matching:
            // 单词级别不会生成连线题
            return generateEngToChMCQ(for: word)
        }
    }
    
    // MARK: - 英选中
    
    static func generateEngToChMCQ(for word: SavedWord) -> ReviewMCQQuestion {
        let correct = word.definition
        var distractors: [String] = []
        
        // 优先级1: 近义词/反义词的翻译 (暂时用 antonyms 文本，将来用 RelatedWord.translation)
        // 优先级2: 预置词库
        let pos = word.word.senses.first?.pos ?? "v."
        let posKey = normalizePOS(pos)
        let pool = fallbackTranslations[posKey] ?? fallbackTranslations["v."]!
        
        distractors = pool.filter { $0 != correct }.shuffled()
        
        let options = ([correct] + Array(distractors.prefix(3))).shuffled()
        
        return ReviewMCQQuestion(
            type: .engToChMCQ,
            targetWordIds: [word.id],
            wordId: word.id,
            prompt: word.word.word,
            correctAnswer: correct,
            options: options
        )
    }
    
    // MARK: - 中选英
    
    static func generateChToEngMCQ(for word: SavedWord) -> ReviewMCQQuestion {
        let correct = word.word.word
        var distractors: [String] = []
        
        // 近义词
        for syn in word.word.synonyms.prefix(2) {
            distractors.append(syn)
        }
        
        // 补充预置词库
        let pos = word.word.senses.first?.pos ?? "v."
        let posKey = normalizePOS(pos)
        let pool = fallbackEnglishWords[posKey] ?? fallbackEnglishWords["v."]!
        let remaining = pool.filter { $0.lowercased() != correct.lowercased() && !distractors.contains($0) }.shuffled()
        distractors.append(contentsOf: remaining)
        
        let options = ([correct] + Array(distractors.prefix(3))).shuffled()
        
        return ReviewMCQQuestion(
            type: .chToEngMCQ,
            targetWordIds: [word.id],
            wordId: word.id,
            prompt: word.definition,
            correctAnswer: correct,
            options: options
        )
    }
    
    // MARK: - 例句填空
    
    static func generateClozeQuestion(for word: SavedWord) -> ReviewClozeQuestion {
        let example = word.word.senses.first?.examples.first
        let en = example?.en ?? "The word is \(word.word.word)."
        let zh = example?.zh ?? word.definition
        
        // 替换目标词为空格（不区分大小写）
        let blanked = en.replacingOccurrences(
            of: word.word.word,
            with: "______",
            options: .caseInsensitive
        )
        
        return ReviewClozeQuestion(
            targetWordIds: [word.id],
            wordId: word.id,
            sentence: blanked,
            translation: zh,
            answer: word.word.word
        )
    }
    
    // MARK: - 听音拼写
    
    static func generateSpellQuestion(for word: SavedWord) -> ReviewSpellQuestion {
        return ReviewSpellQuestion(
            targetWordIds: [word.id],
            wordId: word.id,
            wordToSpell: word.word.word,
            definition: word.definition
        )
    }
    
    // MARK: - 连线消消乐
    
    static func generateMatchingQuestion(from words: [SavedWord]) -> ReviewMatchingQuestion {
        let pairs = words.map { (id: $0.id, english: $0.word.word, chinese: $0.definition) }
        let ids = words.map { $0.id }
        return ReviewMatchingQuestion(targetWordIds: ids, pairs: pairs)
    }
    
    // MARK: - 辅助
    
    private static func normalizePOS(_ pos: String) -> String {
        let lower = pos.lowercased()
        if lower.contains("adj") { return "adj." }
        if lower.contains("adv") { return "adv." }
        if lower.contains("n") { return "n." }
        return "v."
    }
}
