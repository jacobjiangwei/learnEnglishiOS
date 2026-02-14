//
//  MockDataFactory.swift
//  Volingo
//
//  Created by jacob on 2026/2/13.
//

import Foundation

/// 所有题型的 Mock 数据工厂
/// 最终会替换为服务器 API / AI 出题
enum MockDataFactory {

    // MARK: - 选择题
    static func mcqQuestions() -> [MCQQuestion] {
        [
            MCQQuestion(difficulty: .easy,
                        stem: "What is the past tense of 'go'?",
                        options: ["goed", "went", "gone", "going"],
                        correctIndex: 1,
                        explanation: "'go' 的过去式是 'went'，属于不规则动词。"),
            MCQQuestion(difficulty: .easy,
                        stem: "She ___ to school every day.",
                        options: ["go", "goes", "going", "gone"],
                        correctIndex: 1,
                        explanation: "主语是第三人称单数 she，动词用 goes。"),
            MCQQuestion(difficulty: .medium,
                        stem: "Which sentence is correct?",
                        options: ["He don't like it.", "He doesn't likes it.", "He doesn't like it.", "He not like it."],
                        correctIndex: 2,
                        explanation: "否定句结构：主语 + doesn't + 动词原形。"),
            MCQQuestion(difficulty: .medium,
                        stem: "The word 'abandon' means ___.",
                        options: ["to keep", "to give up", "to find", "to carry"],
                        correctIndex: 1,
                        explanation: """
                        abandon 意为"放弃、抛弃"。
                        """),
            MCQQuestion(difficulty: .hard,
                        stem: "I wish I ___ harder for the exam.",
                        options: ["study", "studied", "had studied", "would study"],
                        correctIndex: 2,
                        explanation: "wish 后接过去完成时表示对过去的虚拟。"),
        ]
    }

    // MARK: - 填空题
    static func clozeQuestions() -> [ClozeQuestion] {
        [
            ClozeQuestion(difficulty: .easy,
                          sentence: "She is ___ student in our class.",
                          answer: "the best",
                          hint: "最好的（最高级）",
                          explanation: "最高级前加 the，good 的最高级是 best。"),
            ClozeQuestion(difficulty: .easy,
                          sentence: "I have ___ finished my homework.",
                          answer: "already",
                          hint: "已经",
                          explanation: """
                          already 用于肯定句中，表示"已经"。
                          """),
            ClozeQuestion(difficulty: .medium,
                          sentence: "He is looking forward to ___ you.",
                          answer: "meeting",
                          hint: "动名词形式",
                          explanation: "look forward to 后面接动名词（-ing 形式）。"),
            ClozeQuestion(difficulty: .medium,
                          sentence: "The movie was ___ interesting that everyone loved it.",
                          answer: "so",
                          hint: "如此…以至于",
                          explanation: """
                          so…that 结构表示"如此…以至于"。
                          """),
            ClozeQuestion(difficulty: .hard,
                          sentence: "Not until he arrived ___ the meeting begin.",
                          answer: "did",
                          hint: "倒装结构",
                          explanation: "Not until 放句首时，主句要部分倒装。"),
        ]
    }

    // MARK: - 阅读理解
    static func readingPassage() -> ReadingPassage {
        ReadingPassage(
            title: "The History of Tea",
            content: """
            Tea is one of the most popular drinks in the world. It was first discovered in China about 5,000 years ago. According to legend, Emperor Shen Nung was sitting under a tree when some leaves fell into his hot water. He tasted the water and found it delicious.

            Tea was brought to Europe in the 16th century by Portuguese traders. It quickly became popular in England, where people developed the tradition of afternoon tea. Today, tea is grown in many countries, including India, Kenya, and Sri Lanka.

            There are many types of tea, including green tea, black tea, and oolong tea. Each type has its own unique flavor and health benefits. Green tea, for example, is rich in antioxidants and is believed to help prevent certain diseases.
            """,
            questions: [
                ReadingQuestion(difficulty: .easy,
                                stem: "Where was tea first discovered?",
                                options: ["India", "China", "England", "Kenya"],
                                correctIndex: 1,
                                explanation: "文章第一段提到 'It was first discovered in China'。"),
                ReadingQuestion(difficulty: .medium,
                                stem: "Who brought tea to Europe?",
                                options: ["Chinese merchants", "Portuguese traders", "English sailors", "Indian farmers"],
                                correctIndex: 1,
                                explanation: "文章提到 'Tea was brought to Europe by Portuguese traders'。"),
                ReadingQuestion(difficulty: .medium,
                                stem: "What is special about green tea?",
                                options: ["It's the cheapest", "It's rich in antioxidants", "It's from England", "It has no flavor"],
                                correctIndex: 1,
                                explanation: "文章提到 'Green tea is rich in antioxidants'。"),
            ]
        )
    }

    // MARK: - 翻译题
    static func translationQuestions() -> [TranslationQuestion] {
        [
            TranslationQuestion(difficulty: .easy,
                                sourceText: "我每天早上七点起床。",
                                sourceLanguage: "zh",
                                referenceAnswer: "I get up at seven o'clock every morning.",
                                keywords: ["get up", "seven", "every morning"],
                                explanation: "get up 表示起床，时间用 at 介词。"),
            TranslationQuestion(difficulty: .medium,
                                sourceText: "如果明天不下雨，我们就去公园。",
                                sourceLanguage: "zh",
                                referenceAnswer: "If it doesn't rain tomorrow, we will go to the park.",
                                keywords: ["if", "doesn't rain", "will go"],
                                explanation: "条件句用一般现在时，主句用将来时。"),
            TranslationQuestion(difficulty: .hard,
                                sourceText: "He has been working here for ten years.",
                                sourceLanguage: "en",
                                referenceAnswer: "他已经在这里工作了十年了。",
                                keywords: ["已经", "十年"],
                                explanation: "现在完成进行时表示从过去持续到现在的动作。"),
        ]
    }

    // MARK: - 句型改写
    static func rewritingQuestions() -> [RewritingQuestion] {
        [
            RewritingQuestion(difficulty: .easy,
                              originalSentence: "She is a good singer.",
                              instruction: "改为感叹句",
                              referenceAnswer: "What a good singer she is!",
                              explanation: "What + a/an + 形容词 + 名词 + 主语 + 谓语!"),
            RewritingQuestion(difficulty: .medium,
                              originalSentence: "Tom wrote this letter.",
                              instruction: "改为被动语态",
                              referenceAnswer: "This letter was written by Tom.",
                              explanation: "被动语态：主语 + was/were + 过去分词 + by + 执行者。"),
            RewritingQuestion(difficulty: .hard,
                              originalSentence: "The man who is standing there is my teacher.",
                              instruction: "用分词短语简化定语从句",
                              referenceAnswer: "The man standing there is my teacher.",
                              explanation: "定语从句可简化为现在分词短语作后置定语。"),
        ]
    }

    // MARK: - 纠错题
    static func errorCorrectionQuestions() -> [ErrorCorrectionQuestion] {
        [
            ErrorCorrectionQuestion(difficulty: .easy,
                                    sentence: "She don't like apples.",
                                    errorRange: "don't",
                                    correction: "doesn't",
                                    explanation: "主语 she 是第三人称单数，否定用 doesn't。"),
            ErrorCorrectionQuestion(difficulty: .medium,
                                    sentence: "I have went to Beijing twice.",
                                    errorRange: "went",
                                    correction: "been",
                                    explanation: "have been to 表示去过某地。"),
            ErrorCorrectionQuestion(difficulty: .hard,
                                    sentence: "The number of students are increasing.",
                                    errorRange: "are",
                                    correction: "is",
                                    explanation: "the number of 作主语时谓语用单数。"),
        ]
    }

    // MARK: - 排序题
    static func orderingQuestions() -> [OrderingQuestion] {
        [
            OrderingQuestion(difficulty: .easy,
                             shuffledParts: ["every day", "to school", "I", "go"],
                             correctOrder: [2, 3, 1, 0],
                             explanation: "正确语序：I go to school every day."),
            OrderingQuestion(difficulty: .medium,
                             shuffledParts: ["how to", "can you", "tell me", "get there"],
                             correctOrder: [1, 2, 0, 3],
                             explanation: "正确语序：Can you tell me how to get there?"),
            OrderingQuestion(difficulty: .hard,
                             shuffledParts: ["important", "it", "that", "is", "English", "we", "learn"],
                             correctOrder: [1, 3, 0, 2, 5, 6, 4],
                             explanation: "正确语序：It is important that we learn English."),
        ]
    }

    // MARK: - 听力题
    static func listeningQuestions() -> [ListeningQuestion] {
        [
            ListeningQuestion(difficulty: .easy,
                              audioURL: nil,
                              transcript: "Woman: Excuse me, how can I get to the library?\nMan: Go straight and turn left at the second corner.",
                              stem: "Where does the woman want to go?",
                              options: ["The hospital", "The library", "The school", "The park"],
                              correctIndex: 1,
                              explanation: "女士问 'how can I get to the library'。"),
            ListeningQuestion(difficulty: .medium,
                              audioURL: nil,
                              transcript: "Man: What time does the movie start?\nWoman: It starts at 7:30, but we should get there by 7:00.",
                              stem: "What time should they arrive?",
                              options: ["6:30", "7:00", "7:30", "8:00"],
                              correctIndex: 1,
                              explanation: "女士建议 7:00 到达。"),
            ListeningQuestion(difficulty: .hard,
                              audioURL: nil,
                              transcript: "Woman: I'm thinking about taking a cooking class.\nMan: I took one last year and learned a lot.",
                              stem: "What can we learn about the man?",
                              options: ["He teaches cooking.", "He took a cooking class before.", "He doesn't like cooking.", "He's taking a class now."],
                              correctIndex: 1,
                              explanation: "男士说 'I took one last year'。"),
        ]
    }

    // MARK: - 口语题
    static func speakingQuestions() -> [SpeakingQuestion] {
        [
            SpeakingQuestion(difficulty: .easy,
                             prompt: "请朗读以下句子：",
                             referenceText: "The weather is very nice today. I want to go to the park with my friends.",
                             category: .readAloud),
            SpeakingQuestion(difficulty: .medium,
                             prompt: "描述你看到的画面（想象一家繁忙的餐厅）：",
                             referenceText: "In this picture, I can see a busy restaurant. There are many people sitting at tables, eating and talking. A waiter is carrying food to a table.",
                             category: .describe),
            SpeakingQuestion(difficulty: .hard,
                             prompt: "你的朋友问你最喜欢的书是什么，请回答：",
                             referenceText: "My favorite book is Harry Potter. It's about a young wizard who goes to a magic school. I like it because the story is exciting and the characters are interesting.",
                             category: .respond),
        ]
    }

    // MARK: - 写作题
    static func writingQuestions() -> [WritingQuestion] {
        [
            WritingQuestion(difficulty: .easy,
                            prompt: "用英语写 3 个句子，描述你最喜欢的食物。",
                            category: .sentence,
                            wordLimit: 15...40,
                            referenceAnswer: "My favorite food is pizza. I like it because it has cheese and vegetables. I usually eat pizza on weekends with my family."),
            WritingQuestion(difficulty: .medium,
                            prompt: "写一段话描述你上个周末做了什么。(50-80 词)",
                            category: .paragraph,
                            wordLimit: 50...80,
                            referenceAnswer: "Last weekend, I had a wonderful time. On Saturday morning, I went to the library with my friends. We read books and studied for our exams. In the afternoon, we played basketball. On Sunday, I stayed at home and helped my mother cook dinner."),
            WritingQuestion(difficulty: .hard,
                            prompt: "给你的笔友写一封邮件，介绍一个中国节日。(80-120 词)",
                            category: .application,
                            wordLimit: 80...120,
                            referenceAnswer: "Dear Tom,\n\nI'd like to tell you about the Spring Festival, the most important festival in China. Before the festival, we clean our houses and put up red decorations. On New Year's Eve, the whole family gets together for a big dinner. Children receive red envelopes with money inside.\n\nBest wishes,\nLi Hua"),
        ]
    }

    // MARK: - 词汇题（复用 MCQ 结构）
    static func vocabularyQuestions() -> [MCQQuestion] {
        [
            MCQQuestion(difficulty: .easy,
                        stem: "'Beautiful' 的反义词是什么？",
                        options: ["pretty", "ugly", "handsome", "lovely"],
                        correctIndex: 1,
                        explanation: "beautiful（美丽的）的反义词是 ugly（丑陋的）。"),
            MCQQuestion(difficulty: .easy,
                        stem: "Which word means '勇敢的'?",
                        options: ["afraid", "brave", "shy", "lazy"],
                        correctIndex: 1,
                        explanation: """
                        brave 意为"勇敢的"。
                        """),
            MCQQuestion(difficulty: .medium,
                        stem: "She speaks English ___ (fluent).",
                        options: ["fluent", "fluently", "fluence", "fluenting"],
                        correctIndex: 1,
                        explanation: "修饰动词 speaks 需要用副词 fluently。"),
            MCQQuestion(difficulty: .medium,
                        stem: "The plural of 'child' is ___.",
                        options: ["childs", "childes", "children", "childrens"],
                        correctIndex: 2,
                        explanation: "child 的复数是不规则变化 children。"),
            MCQQuestion(difficulty: .hard,
                        stem: "'Ubiquitous' most likely means ___.",
                        options: ["rare", "everywhere", "dangerous", "expensive"],
                        correctIndex: 1,
                        explanation: """
                        ubiquitous 意为"无处不在的"。
                        """),
        ]
    }

    // MARK: - 语法题（复用 MCQ 结构）
    static func grammarQuestions() -> [MCQQuestion] {
        [
            MCQQuestion(difficulty: .easy,
                        stem: "I ___ my homework when my mom came home.",
                        options: ["do", "did", "was doing", "have done"],
                        correctIndex: 2,
                        explanation: "过去进行时表示过去某个时刻正在进行的动作。"),
            MCQQuestion(difficulty: .easy,
                        stem: "___ you ever been to Japan?",
                        options: ["Do", "Did", "Have", "Are"],
                        correctIndex: 2,
                        explanation: "现在完成时用 Have you ever + 过去分词。"),
            MCQQuestion(difficulty: .medium,
                        stem: "The book ___ by J.K. Rowling is very popular.",
                        options: ["write", "wrote", "written", "writing"],
                        correctIndex: 2,
                        explanation: "过去分词 written 作后置定语。"),
            MCQQuestion(difficulty: .medium,
                        stem: "If I ___ you, I would study harder.",
                        options: ["am", "was", "were", "be"],
                        correctIndex: 2,
                        explanation: "虚拟语气中，if 从句用 were（不论人称）。"),
            MCQQuestion(difficulty: .hard,
                        stem: "Not only ___ hard, but also he is very kind.",
                        options: ["he works", "does he work", "he work", "working he"],
                        correctIndex: 1,
                        explanation: "Not only 位于句首时需要部分倒装。"),
        ]
    }

    // MARK: - 场景题
    static func scenarioQuestions(for type: QuestionType) -> [ScenarioQuestion] {
        switch type {
        case .scenarioDaily:
            return [
                ScenarioQuestion(
                    type: .scenarioDaily, difficulty: .easy,
                    scenarioTitle: "在咖啡店点单",
                    context: "你走进一家咖啡店，想要点一杯拿铁和一块蛋糕。",
                    dialogueLines: [
                        DialogueLine(speaker: "Staff", text: "Welcome! What can I get for you today?"),
                    ],
                    userPrompt: "你想要一杯拿铁和一块巧克力蛋糕：",
                    options: ["I'd like a latte and a chocolate cake, please.", "Give me coffee now.", "I want eat cake.", "Coffee chocolate."],
                    correctIndex: 0,
                    referenceResponse: "I'd like a latte and a chocolate cake, please."),
            ]
        case .scenarioCampus:
            return [
                ScenarioQuestion(
                    type: .scenarioCampus, difficulty: .easy,
                    scenarioTitle: "向老师请假",
                    context: "你明天需要去看医生，想向老师请一天假。",
                    dialogueLines: [
                        DialogueLine(speaker: "You", text: "Excuse me, Ms. Wang. May I talk to you?"),
                        DialogueLine(speaker: "Teacher", text: "Sure. What's the matter?"),
                    ],
                    userPrompt: "你需要请假一天去看医生：",
                    options: ["I need to take a day off tomorrow because I have a doctor's appointment.", "I no come tomorrow.", "Tomorrow I go hospital.", "Day off please doctor."],
                    correctIndex: 0,
                    referenceResponse: "I need to take a day off tomorrow because I have a doctor's appointment."),
            ]
        case .scenarioWorkplace:
            return [
                ScenarioQuestion(
                    type: .scenarioWorkplace, difficulty: .medium,
                    scenarioTitle: "工作面试自我介绍",
                    context: "你正在参加一个英语面试，面试官让你做自我介绍。",
                    dialogueLines: [
                        DialogueLine(speaker: "Interviewer", text: "Please tell me about yourself."),
                    ],
                    userPrompt: "请做一个简短的自我介绍：",
                    options: ["My name is Li Ming. I graduated from Beijing University with a degree in Computer Science.", "I am Li Ming. I like computer.", "Hello I student.", "Me work computer before."],
                    correctIndex: 0,
                    referenceResponse: "My name is Li Ming. I graduated from Beijing University with a degree in Computer Science. I have three years of experience in software development."),
            ]
        case .scenarioTravel:
            return [
                ScenarioQuestion(
                    type: .scenarioTravel, difficulty: .easy,
                    scenarioTitle: "在机场办理登机",
                    context: "你到了机场柜台，需要办理登机手续。",
                    dialogueLines: [
                        DialogueLine(speaker: "Agent", text: "Good morning! May I see your passport?"),
                        DialogueLine(speaker: "You", text: "Here you go."),
                        DialogueLine(speaker: "Agent", text: "Would you like a window seat or an aisle seat?"),
                    ],
                    userPrompt: "你想要靠窗的座位：",
                    options: ["A window seat, please.", "I want sit window.", "Window.", "Seat near wall please."],
                    correctIndex: 0,
                    referenceResponse: "A window seat, please. Thank you."),
            ]
        default:
            return []
        }
    }

    // MARK: - TextInputItem 适配器

    static func translationItems() -> [TextInputItem] {
        translationQuestions().map { q in
            TextInputItem(
                sourceText: q.sourceText,
                instruction: q.sourceLanguage == "zh" ? "请翻译成英文" : "请翻译成中文",
                referenceAnswer: q.referenceAnswer,
                keywords: q.keywords,
                explanation: q.explanation)
        }
    }

    static func rewritingItems() -> [TextInputItem] {
        rewritingQuestions().map { q in
            TextInputItem(
                sourceText: q.originalSentence,
                instruction: q.instruction,
                referenceAnswer: q.referenceAnswer,
                keywords: [],
                explanation: q.explanation)
        }
    }

    static func writingItems() -> [TextInputItem] {
        writingQuestions().map { q in
            TextInputItem(
                sourceText: q.prompt,
                instruction: "字数要求：\(q.wordLimit.lowerBound)-\(q.wordLimit.upperBound) 词",
                referenceAnswer: q.referenceAnswer,
                keywords: [],
                explanation: "参考范文已展示。请对照学习。")
        }
    }
}
