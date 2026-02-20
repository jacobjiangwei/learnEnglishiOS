# 生词本复习系统设计

> 核心问题：怎么让用户高效复习生词，而不是无聊地翻卡片？

---

## 一、出题机制：本地为主，AI 为辅

### 1.1 先回答关键问题

**Q: AI 会给每个词都调 API 生成题目吗？**
A: **不会**。绝大多数题目是**本地从已有词条数据直接生成**的，不需要任何网络请求。

**Q: 几十个、几百个生词都能用 AI 出题吗？**
A: AI 出题不是实时的，也不是逐词的。AI 只在特定场景下**批量预生成**一些高质量填空题缓存起来，详情见 1.3。

### 1.2 本地出题器（主力，100% 本地可运行）

每个词在本地缓存中已有丰富数据（来自词典查询）：

```
Word 已有数据:
├── word: "reluctant"
├── phonetic: "/rɪˈlʌktənt/"
├── senses: [{ pos: "adj.", definitions: [...], translations: ["不情愿的"], examples: [...] }]
├── synonyms: [
│     { word: "unwilling", translation: "不愿意的" },
│     { word: "hesitant", translation: "犹豫的" }
│   ]
├── antonyms: [
│     { word: "willing", translation: "愿意的" },
│     { word: "eager", translation: "急切的" }
│   ]
├── relatedPhrases: [{ phrase: "reluctant to do", meaning: "不愿做某事" }]
└── exchange: { comparative: "more reluctant", superlative: "most reluctant" }
```

利用这些**已有数据**，本地可以直接生成 **4 种题型**，**零网络开销**：

---

#### 题型 A: 英选中（看英文选中文）— 选择题

```
reluctant 的意思是？
A) 不情愿的    ← translations[0] (正确)
B) 急切的      ← antonyms[1].translation (词条自带)
C) 愿意的      ← antonyms[0].translation (词条自带)
D) 明显的      ← 预置词库 adj 组 (兜底)
```

#### 题型 B: 中选英（看中文选英文）— 选择题

```
"不情愿的" 对应哪个单词？
A) reluctant    ← 正确
B) hesitant     ← 近义词 synonyms[0].word
C) relevant     ← 形近词 (words.db 查询)
D) resilient    ← 形近词 (words.db 查询)
```

#### 选择题干扰项来源

**原则: 干扰项从词条自身数据 + 预置词库生成，不依赖生词本大小。**
**即使生词本只有 1 个词，也能出高质量的题。**

> **前提**: 词条的 synonyms/antonyms 需要带中文翻译。
> 当前结构是 `synonyms: ["unwilling", "hesitant"]`（纯英文），
> 需要改为 `synonyms: [{"word": "unwilling", "translation": "不愿意的"}, ...]`。
> 词条自身就自包含所有出题数据，不需要额外查询。
>
> **改动范围**: 后端 AI prompt 加上"请给同义词/反义词附带中文翻译"即可，
> iOS Word 模型加两个字段，旧缓存通过 decodeIfPresent 兼容。

```
英选中（选中文）的干扰项:
  1. 该词近义词/反义词自带的中文翻译 (词条内嵌，无需查询)
  2. 预置干扰词库 (按词性分组，~200个翻译，打包在 App 内)
  3. 生词本中其他词的翻译 (锦上添花)

中选英（选英文）的干扰项:
  1. 该词的近义词 (天然最佳干扰)
  2. 形近词 (从 words.db 查同首字母+相似长度)
  3. 预置干扰词库 (按词性分组，~200个英文词)
  4. 生词本中其他词
```

---

#### 题型 C: 例句填空

```
完成句子:
"She was ______ to admit her mistake."

答案: reluctant
```
**生成方式**: 直接取词条中已有的 example，把目标词替换为空格。
每个词有 2-4 个例句，够用。

---

#### 题型 D: 听音拼写

```
🔊 [自动播放发音]

请拼写你听到的单词: ________
                    (自动弹出英文键盘)

用户输入: r-e-l-u-c-t-a-n-t ✅
```

**交互细节**:
- 进入时自动播放一次 TTS 发音
- 自动弹出英文键盘（`keyboardType = .asciiCapable`）
- 用户可以点击 🔊 重复播放
- 忽略大小写比较
- 提交后显示正确拼写 + 中文释义

---

#### 题型 E: 连线消消乐（组队复习，需 ≥ 4 个生词）

**这是最高效的题型——一次复习 5-6 个词，而且所有数据都来自生词本本身，不需要任何干扰项。**

```
┌─────────────────────────────────┐
│  连线配对                        │
│                                  │
│  reluctant  ●        ● 抛弃      │
│                                  │
│  abandon    ●        ● 不情愿的   │
│                                  │
│  embrace    ●        ● 模糊的    │
│                                  │
│  resilient  ●        ● 拥抱      │
│                                  │
│  ambiguous  ●        ● 有韧性的   │
│                                  │
└─────────────────────────────────┘
```

**交互方式**: 
1. 左边 5-6 个英文单词，右边对应的中文翻译（打乱顺序）
2. 用户点击左边一个词 → 点击右边一个翻译 → 配对
3. 配对正确 → 两个都消除，带动画
4. 配对错误 → 短暂闪红，不消除，继续
5. 全部消除 → 完成，展示结果

**数据来源**:
- 英文 = 从待复习词中取 5-6 个词的 `word`
- 中文 = 对应词的 `senses[0].translations[0]`（主要释义）
- **完全不需要任何额外数据**，纯生词本内部数据

**FSRS 评分规则**:
- 一次配对成功 → Good
- 配错后第二次配对成功 → Hard
- 配错 2 次以上 → Again

**触发条件**: 待复习词 ≥ 4 个时可用。如果不到 4 个，跳过此题型。

**优势**:
- 一题复习 5-6 个词，效率最高
- 不需要造干扰项，零 edge case
- 交互有趣（消除动画），比选择题更有参与感
- 天然适合"组队复习"——同一批生词相互对照，加深印象

---

### 1.3 AI 出题（增值，Phase B）

AI 出题解决的问题是：**本地例句填空用同一个例句翻来覆去，用户会记住句子而不是记住词**。

#### AI 怎么用：预生成 + 缓存，不是实时调用

```
时机: 用户把词加入生词本时（或空闲时后台批量）
方式: 不是逐词，而是攒一批（5-10个词），一次 API 调用

请求:
POST /api/v1/review/generate-batch
Body: {
  "words": ["reluctant", "abandon", "embrace", "resilient", "ambiguous"],
  "count": 2  // 每个词生成 2 道填空题
}

响应:
{
  "questions": [
    {
      "targetWord": "reluctant",
      "type": "cloze",
      "stem": "The team was _____ to adopt the new strategy without more data.",
      "answer": "reluctant",
      "explanation": "reluctant 意为'不情愿的'，此处搭配 be reluctant to do"
    },
    {
      "targetWord": "abandon",
      "type": "cloze",
      "stem": "Faced with mounting losses, the company decided to _____ the project.",
      "answer": "abandon",
      "explanation": "abandon the project 意为'放弃项目'"
    },
    // ... 每个词 2 道题，5个词 = 10道题，一次 API 调用搞定
  ]
}
```

**关键设计**:
- **批量**: 5-10 个词一次调用，不是每个词调一次
- **预生成**: 加入生词本时后台生成，不是复习时实时生成
- **缓存**: 生成的题目存在本地 SQLite，可以反复使用
- **懒加载**: 不是所有词都生成 AI 题，只给复习过 2+ 次还没掌握的词生成
- **成本可控**: 5 个词一次 ≈ 500 tokens ≈ $0.003，100 个生词 = $0.06

#### AI 题什么时候触发？

```
规则:
1. 某个词已本地复习 3+ 次、仍在 learning 状态 → 对该词触发 AI 出题
2. 攒满 5 个需要 AI 出题的词 → 批量调一次 API
3. 无网络 → 跳过 AI 题，只用本地题，完全不影响复习
```

---

### 1.4 题型总览

```
┌──────────┬───────────┬───────────────┬──────────────┐
│ 题型      │ 一题复习   │ 数据来源       │ 最低生词数    │
├──────────┼───────────┼───────────────┼──────────────┤
│ A 英选中  │ 1 个词     │ 词条自身+词库   │ 1            │
│ B 中选英  │ 1 个词     │ 词条自身+词库   │ 1            │
│ C 例句填空│ 1 个词     │ 词条自带例句    │ 1            │
│ D 听音拼写│ 1 个词     │ TTS + 词条     │ 1            │
│ E 连线消消乐│ 5-6 个词 │ 生词本内部     │ 4            │
│ F AI填空  │ 1 个词     │ AI 预生成缓存  │ 1 (Phase B)  │
└──────────┴───────────┴───────────────┴──────────────┘
```

---

## 二、FSRS 记忆算法

### 2.1 为什么不用现在的系统

当前系统的问题（`Models.swift` 中 `SavedWord`）：

```swift
// 当前: level = correctCount - wrongCount
// 问题1: 答对10次答错8次 = level 2，但其实用户可能已经记住了（只是错过几次）
// 问题2: nextReviewDate = addedDate + interval，不是基于上次复习时间
// 问题3: 没有区分"刚答对"和"思考很久才答对"
```

**核心问题**: 生词本多了以后，必须有算法决定"今天复习哪些词"。
现有系统无法做好这个决策——它只有一个粗糙的 level，无法准确预测哪些词即将遗忘。

### 2.2 FSRS 是什么

FSRS (Free Spaced Repetition Scheduler) 是目前学术界最优的间隔重复算法，
Anki 从 v23.10 开始采用。核心只有 4 个参数：

```
WordMemory {
    state: .new | .learning | .review | .relearning
    stability: Float     // 记忆稳定性（天）— 预计多少天后记忆降到 90%
    difficulty: Float    // 0.0~1.0 这个词对该用户的难度
    lastReview: Date     // 上次复习时间
    reps: Int            // 已复习次数
    lapses: Int          // 遗忘次数
}
```

每次复习后，根据答题结果自动评分：

```
┌──────────┬──────────────────────────┬──────────────────┐
│ 评分      │ 触发条件                  │ 算法效果          │
├──────────┼──────────────────────────┼──────────────────┤
│ Again    │ 答错                      │ stability 重置    │
│ Hard     │ 答对但犹豫（连线配错1次）   │ stability 小幅增  │
│ Good     │ 答对                      │ stability 正常增  │
│ Easy     │ 秒答 / 连线一次配对成功    │ stability 大幅增  │
└──────────┴──────────────────────────┴──────────────────┘
```

**不需要用户手动自评** — 系统根据答题表现自动判定评分。

FSRS 根据评分更新 stability 和 difficulty：

```
答 Again → stability 重置为 0.5 天，lapses+1，进入 relearning
答 Hard  → stability × 1.2，difficulty 微增
答 Good  → stability × 2.5（正常增长）
答 Easy  → stability × 3.5+，difficulty 微减
```

下次复习时间 = lastReview + stability 天

**示例**:
```
Day 1: 新学 "reluctant"，stability=0.5
       复习，答 Good → stability=1.3天 → 明天复习
Day 2: 复习，答 Good → stability=3.2天 → 5天后复习
Day 7: 复习，答 Easy → stability=11天 → 18天后复习
Day 25: 复习，答 Hard → stability=13天 → 38天后复习
Day 38: 复习，答 Again → stability=0.5，lapses+1 → 重新来
```

### 2.3 FSRS 如何决定"今天复习哪些词"

```
用户有 200 个生词，FSRS 每天做这件事:

for word in allSavedWords:
    // 每个词都有一个 nextReviewDate
    if word.nextReviewDate <= today:
        加入今日待复习列表

// 按紧急程度排序: 超期越久的越优先
待复习列表.sort(by: 超期天数, 降序)

// 限制每日复习量上限 (可设置，默认 20-30 个词)
今日复习 = 待复习列表.prefix(dailyLimit)
```

**结果**: 200 个生词中，每天可能只有 8-15 个到期。
已掌握的词间隔会自动拉长（1天→3天→1周→2周→1月→3月），不会反复出现。

### 2.4 实现复杂度

FSRS 核心算法大约 100 行 Swift 代码，纯数学计算，不需要网络。
开源参考: https://github.com/open-spaced-repetition/swift-fsrs

---

## 三、复习 Session 流程

### 3.1 核心理念：5 分钟一个 Session，自动出题

用户不需要选题型、选数量。点"开始复习"就行，系统自动搞定一切。

### 3.2 Session 配置

```
每个 Session:
├── 时长目标: ~5 分钟
├── 题量: 约 10-15 题 (取决于题型混合)
├── 词量: 约 8-12 个词 (连线一题覆盖 5-6 个)
└── 自动结束: 所有待复习词做完 或 达到题量上限
```

### 3.3 动态出题策略

系统自动选择题型配比，用户无需操心：

```
Session 开始:
  1. FSRS 筛选出今日待复习词列表 (如 12 个)
  2. 动态组题:

  ┌─────────────────────────────────────────────────┐
  │ 第 1 题: 连线消消乐                               │
  │   → 取 5 个词，组成一组连线题                      │
  │   → 一次覆盖 5 个词的"认不认识"                    │
  │                                                    │
  │ 第 2 题: 例句填空 (reluctant)                      │
  │   → 针对第 1 题中答错/犹豫的词，加深复习            │
  │                                                    │
  │ 第 3 题: 英选中 (ambiguous)                        │
  │   → 同上，挑出薄弱词                               │
  │                                                    │
  │ 第 4 题: 连线消消乐                               │
  │   → 取剩余 5 个词 + 前面答错的 1-2 个词             │
  │                                                    │
  │ 第 5 题: 听音拼写 (abandon)                        │
  │   → 随机挑一个 review 状态的词，测试深度记忆         │
  │                                                    │
  │ 第 6 题: 中选英 (resilient)                        │
  │   → 随机挑一个 learning 状态的词                    │
  │                                                    │
  │ 第 7 题: 例句填空 (embrace)                        │
  │   → AI 缓存的新例句 (如果有的话)                    │
  │                                                    │
  │ ... 直到所有待复习词至少出现过一次                    │
  │                                                    │
  │ Session 结束                                       │
  └─────────────────────────────────────────────────┘
```

### 3.4 题型配比规则

```
┌────────────────────┬────────┬───────────────────────────────┐
│ 题型                │ 占比    │ 触发条件                       │
├────────────────────┼────────┼───────────────────────────────┤
│ 连线消消乐          │ ~30%   │ 待复习 ≥ 4 个词时优先安排       │
│ 英选中 / 中选英     │ ~30%   │ 始终可用，new/relearning 状态偏多│
│ 例句填空            │ ~25%   │ learning/review 状态偏多        │
│ 听音拼写            │ ~15%   │ review 状态的词（已有一定基础）   │
└────────────────────┴────────┴───────────────────────────────┘

特殊规则:
- 答错的词会在后续题目中以另一种题型再次出现
- 连线中配错的词，会单独出一道选择题或填空题加固
- 同一个词在一个 Session 内不会以同一题型出现两次
```

### 3.5 FSRS 评分自动化

**用户不需要手动打 Again/Hard/Good/Easy**，系统根据表现自动评分：

```
┌────────────┬──────────────────────────────────┬──────────┐
│ 题型        │ 表现                              │ 评分      │
├────────────┼──────────────────────────────────┼──────────┤
│ 英选中/中选英│ 选错                             │ Again    │
│             │ 选对                              │ Good     │
│             │                                   │          │
│ 例句填空    │ 答错 或 放弃                       │ Again    │
│             │ 答对                              │ Good     │
│             │                                   │          │
│ 听音拼写    │ 拼错                              │ Again    │
│             │ 拼对                              │ Good     │
│             │                                   │          │
│ 连线消消乐  │ 一次配对成功                       │ Easy     │
│             │ 配错 1 次后成功                    │ Good     │
│             │ 配错 2 次后成功                    │ Hard     │
│             │ 配错 3+ 次                        │ Again    │
└────────────┴──────────────────────────────────┴──────────┘
```

### 3.6 Session 结束页

```
┌────────────────────────────────┐
│  🎉 复习完成!                   │
│                                 │
│  本次复习: 12 个词  ⏱ 4分32秒   │
│  正确率: 83%                     │
│                                 │
│  📈 记忆变化:                    │
│  ├── 2 个词升级为 "稳固"         │
│  ├── 8 个词正常推进               │
│  └── 2 个词需要重新学习           │
│                                 │
│  ⏰ 下次复习: 明天 3 个词         │
│                                 │
│  [返回生词本]                    │
└────────────────────────────────┘
```

### 3.7 答错的词怎么处理

答错的词在**当前 Session 内会再出现一次**（换一种题型），确保学会了再走：

```
第 1 题: 连线消消乐 → reluctant 配错了
第 2 题: (reluctant 单独出现，换题型)
         reluctant 的意思是？→ 英选中
         → 答对 → FSRS 标记 Hard (因为连线配错过)
第 3 题: 听音拼写 (abandon) → ...
```

---

## 四、数据模型变更

### 4.1 SavedWord 改造

```swift
// 改前 (当前):
struct SavedWord {
    let id: String
    let word: Word
    let addedDate: Date
    var correctCount: Int = 0
    var wrongCount: Int = 0
    // level = correctCount - wrongCount (有bug)
}

// 改后:
struct SavedWord {
    let id: String
    let word: Word
    let addedDate: Date

    // FSRS 记忆参数
    var memoryState: MemoryState = .new
    var stability: Double = 0.0       // 天
    var difficulty: Double = 0.3      // 0~1
    var lastReviewDate: Date? = nil
    var nextReviewDate: Date? = nil
    var reps: Int = 0                 // 复习次数
    var lapses: Int = 0               // 遗忘次数

    // 统计 (保留，向后兼容)
    var correctCount: Int = 0
    var wrongCount: Int = 0
}

enum MemoryState: String, Codable {
    case new          // 新词，从未复习
    case learning     // 学习中（首次学习阶段）
    case review       // 复习（已进入长期记忆）
    case relearning   // 重新学习（答错后回退）
}
```

### 4.2 Word 模型变更（synonyms/antonyms 带翻译）

```swift
// 改前:
synonyms: [String]       // ["unwilling", "hesitant"]
antonyms: [String]       // ["willing", "eager"]

// 改后:
synonyms: [RelatedWord]  // [{ word: "unwilling", translation: "不愿意的" }, ...]
antonyms: [RelatedWord]  // [{ word: "willing", translation: "愿意的" }, ...]

struct RelatedWord: Codable {
    let word: String
    let translation: String   // 中文翻译，用于出干扰项
}
```

需要改动:
- 后端 AI prompt: 让 GPT-4o 给近反义词附带中文翻译
- 后端 DictionaryDocument: synonyms/antonyms 改为对象数组
- iOS Word 模型: 加 RelatedWord 结构，旧缓存用 decodeIfPresent 兼容

### 4.3 AI 缓存题目模型 (本地 SQLite，Phase B)

```
Table: cached_questions
├── id: TEXT PRIMARY KEY
├── target_word: TEXT         -- 目标单词
├── type: TEXT                -- "cloze"
├── stem: TEXT                -- 题干 (如 "The team was _____ to...")
├── answer: TEXT              -- 正确答案
├── explanation: TEXT         -- 解析
├── used_count: INT           -- 已使用次数
├── created_at: TEXT
└── INDEX on target_word
```

---

## 五、实现分阶段

### Phase A: 纯本地复习（不需要后端，可独立上线）

| # | 任务 | 说明 | 预估 |
|---|------|------|------|
| 1 | FSRS 算法引擎 | 纯 Swift，~100行核心代码 | 小 |
| 2 | 改造 SavedWord | 加 FSRS 字段，迁移旧数据 | 小 |
| 3 | 本地出题器 | 英选中/中选英/例句填空/听音拼写/连线消消乐 | 中 |
| 4 | 复习 Session UI | 动态出题→答题→自动评分→下一题→结束统计 | 中 |
| 5 | 连线消消乐 UI | 左右配对+消除动画+配错闪红 | 中 |
| 6 | 生词本入口 | 显示"今日待复习 N 个" + "开始复习"按钮 | 小 |

Phase A 完成后就是一个**完整可用的复习系统**，100% 离线可运行。

### Phase B: AI 增强（需要后端）

| # | 任务 | 说明 | 预估 |
|---|------|------|------|
| 7 | synonyms/antonyms 带翻译 | 后端 prompt + 模型改动 | 小 |
| 8 | 后端 AI 出题 API | POST /api/v1/review/generate-batch | 中 |
| 9 | iOS AI 题缓存 | 本地 SQLite 存 AI 填空题 | 小 |

### Phase C: 体验优化

| # | 任务 | 说明 | 预估 |
|---|------|------|------|
| 10 | 记忆可视化 | 稳固/一般/危险 统计仪表盘 | 小 |
| 11 | 推送通知 | "今天有 N 个词需要复习" | 小 |

### Phase D: AI 阅读理解（暂缓）

| # | 任务 | 说明 | 预估 |
|---|------|------|------|
| 12 | AI 生成短文阅读理解 | 基于生词本词汇生成阅读材料+理解题 | 大 |

---

## 六、成本分析

### 本地出题（Phase A）
- API 调用: 0
- 成本: $0
- 适用规模: 无限

### AI 出题（Phase B）
- 触发条件: 词复习 3+ 次仍未掌握
- 批量大小: 5-10 词/次
- 每次调用: ~500 tokens ≈ $0.003
- 100 个困难词: ~20 次调用 ≈ $0.06
- 每月每用户: 预估 ≤ $0.50

---

## 七、FAQ

### Q: 200 个生词怎么办？每天复习多少？
A: FSRS 会根据每个词的 stability 自动调度。已掌握的词间隔会越来越长（1周→2周→1月→3月），
所以每天只会弹出 5-20 个真正需要复习的词，不会一股脑 200 个全来。
每次复习 ~5 分钟，做 10-15 题即可。

### Q: 生词本才 2-3 个词能复习吗？
A: 能。选择题的干扰项来自词条自身（近反义词翻译）+ 预置词库，不依赖生词本大小。
连线消消乐需要 ≥ 4 个词才会出，不够时只出选择题/填空/拼写。

### Q: 本地例句就那么几个，反复出不会背答案吗？
A: 会。所以设计了多题型轮转——同一个词，第一次出连线，第二次出拼写，第三次出例句填空。
如果已复习 3+ 次还没掌握，触发 AI 生成全新例句补充 (Phase B)。

### Q: 没网能复习吗？
A: 能。Phase A 纯本地，Phase B 的 AI 题也是提前缓存好的。只有生成新 AI 题需要网络。

### Q: 用户需要自己选题型吗？
A: 不需要。点"开始复习"后系统自动混合出题，大约 5 分钟一个 Session。
题型配比根据待复习词的记忆状态自动调整。

### Q: 跟现在的练习系统（TodayPackage）什么关系？
A: 不同系统。TodayPackage 是"每日学习新内容"（听力、改错、填空等），
这个复习系统是"巩固生词本里的旧词"。两个系统的词可以联动：
TodayPackage 练习中遇到的不认识的词 → 自动加入生词本 → 进入复习循环。
