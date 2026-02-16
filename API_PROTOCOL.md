# Volingo 后端 API JSON 协议规范

> 本文档定义了 iOS 客户端期望的所有 JSON 数据格式。  
> 后端只需按此格式返回 JSON，客户端即可直接解析渲染。

---

## 目录

0. [身份认证机制](#0-身份认证机制)
   - 0.1 [匿名设备 ID（X-Device-Id）](#01-匿名设备-idx-device-id)
1. [通用字段与枚举值](#1-通用字段与枚举值)
2. [题型 JSON 定义](#2-题型-json-定义)
   - 2.1 [选择题 (multipleChoice)](#21-选择题-multiplechoice)
   - 2.2 [填空题 (cloze)](#22-填空题-cloze)
   - 2.3 [阅读理解 (reading)](#23-阅读理解-reading)
   - 2.4 [翻译题 (translation)](#24-翻译题-translation)
   - 2.5 [句型改写 (rewriting)](#25-句型改写-rewriting)
   - 2.6 [纠错题 (errorCorrection)](#26-纠错题-errorcorrection)
   - 2.7 [排序题 (sentenceOrdering)](#27-排序题-sentenceordering)
   - 2.8 [听力题 (listening)](#28-听力题-listening)
   - 2.9 [口语题 (speaking)](#29-口语题-speaking)
   - 2.10 [写作题 (writing)](#210-写作题-writing)
   - 2.11 [词汇题 (vocabulary)](#211-词汇题-vocabulary)
   - 2.12 [语法题 (grammar)](#212-语法题-grammar)
   - 2.13 [场景对话题 (scenario*)](#213-场景对话题-scenario)
3. [组合接口](#3-组合接口)
   - 3.1 [获取练习题组](#31-获取练习题组)
   - 3.2 [今日推荐套餐](#32-今日推荐套餐)
   - 3.3 [学习统计](#33-学习统计github-热力图风格)
4. [提交答案 & 题目投诉接口](#4-提交答案--题目投诉接口)
5. [生词本接口](#5-生词本接口)
   - 5.1 [添加生词](#51-添加生词)
   - 5.2 [删除生词](#52-删除生词)
   - 5.3 [获取生词列表](#53-获取生词列表全量)
6. [通用响应格式](#6-通用响应格式)

---

## 0. 身份认证机制

### 0.1 匿名设备 ID（X-Device-Id）

> 用户首次启动 App 时，客户端生成一个 UUID 作为设备唯一标识，存入 Keychain（卸载重装不丢失）。  
> **所有 API 请求**必须在 HTTP Header 中携带此设备 ID，服务端以此追踪用户做题记录。

#### 请求头规范

| Header | 值 | 必填 | 说明 |
|--------|----|------|------|
| `X-Device-Id` | string (UUID) | ✅ | 设备唯一标识，格式 `550e8400-e29b-41d4-a716-446655440000` |
| `Authorization` | string | ❌ | 用户注册/登录后携带 `Bearer {token}`，匿名用户不传 |

#### 示例

```
GET /api/v1/practice/today-package?textbookCode=juniorPEP-7a
X-Device-Id: 550e8400-e29b-41d4-a716-446655440000
```

#### 服务端逻辑

1. **首次见到新 deviceId** → 自动创建匿名用户记录（`anonymous_user` 表）
2. **后续请求** → 通过 `deviceId` + LEFT JOIN 排除已完成的题目，只返回未做过的题
3. **选题策略**：
   - **永久排除**已完成的题目（做过即不再出现）
   - 匹配 `textbookCode` + `questionType`
   - 随机抽取保证多样性
   - 题库全部完成时返回空数组 + `remaining: 0`

#### 数据库参考结构

```sql
-- 匿名用户表
CREATE TABLE anonymous_user (
  device_id       VARCHAR(36) PRIMARY KEY,  -- UUID
  created_at      TIMESTAMP DEFAULT NOW(),
  textbook_code   VARCHAR(32),
  user_id         VARCHAR(36) NULL          -- 注册后关联
);

-- 题库表
CREATE TABLE question_bank (
  id              UUID PRIMARY KEY,
  textbook_code   VARCHAR(32) NOT NULL,
  question_type   VARCHAR(32) NOT NULL,
  content         JSONB NOT NULL,            -- 完整题目 JSON
  is_active       BOOLEAN DEFAULT true,      -- 被投诉下架 = false
  created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_qbank_lookup
  ON question_bank (textbook_code, question_type, is_active);

-- 用户完成记录表
CREATE TABLE user_completion (
  id              BIGINT GENERATED ALWAYS AS IDENTITY,
  device_id       VARCHAR(36) NOT NULL,      -- FK → anonymous_user
  question_id     UUID NOT NULL,             -- FK → question_bank
  textbook_code   VARCHAR(32) NOT NULL,      -- 冗余存储，加速按教材查询
  is_correct      BOOLEAN NOT NULL,
  time_spent_ms   INT,
  completed_at    TIMESTAMP DEFAULT NOW(),
  UNIQUE (device_id, question_id)            -- 一人一题只记录一次，同时作为索引
);

CREATE INDEX idx_completion_device_textbook
  ON user_completion (device_id, textbook_code);
```

#### 核心选题查询（LEFT JOIN 排除已完成）

```sql
-- 单条 SQL 完成：从题库中选出该用户未做过的题
SELECT q.*
FROM question_bank q
LEFT JOIN user_completion uc
  ON q.id = uc.question_id
  AND uc.device_id = :deviceId
WHERE q.textbook_code = :textbookCode
  AND q.question_type = :questionType
  AND q.is_active = true
  AND uc.id IS NULL            -- 没有匹配 = 没做过
ORDER BY RANDOM()
LIMIT :count;
```

> **性能说明**：
> - `LEFT JOIN ... IS NULL` 比 `NOT IN (子查询)` 更高效，数据库优化器处理更好
> - `UNIQUE (device_id, question_id)` 约束本身就是索引，JOIN 时直接命中
> - `ORDER BY RANDOM()` 在小表（几百条）上几乎无开销

---

## 1. 通用字段与枚举值

### 每道题目的共有字段

> 以下字段出现在 **每一道** 题目的 JSON 中：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | string (UUID) | ✅ | 题目唯一标识 |
| `questionType` | string | ✅ | 题型标识，见下方枚举 |
| `textbookCode` | string | ✅ | 所属教材编码，决定该题的适用年级/教材。格式见下方说明 |

### textbookCode（教材编码）

教材编码由 `seriesCode` + `-` + `年级` + `学期` 组成，与客户端 `TextbookOption.code()` 对齐。

**编码规则**：`{seriesCode}-{gradeNumber}{semester}`

- `gradeNumber`：1~12（小学1~6 = 1~6，初中7~9，高中10~12）
- `semester`：`a` = 上册，`b` = 下册

**示例**：

```
"juniorPEP-7a"      — 初中人教版·七年级上册
"juniorPEP-7b"      — 初中人教版·七年级下册
"seniorFLTRP-10a"   — 高中外研版·高一上册
"primaryPEP-3b"     — 小学人教版·三年级下册
"collegeCet"        — 大学英语四六级（无年级/学期）
"cefr"              — CEFR 分级（无年级/学期）
"ielts"             — 雅思备考
"toefl"             — 托福备考
"cambridge"         — 剑桥教材
"longman"           — 朗文教材
```

**完整 seriesCode 列表**：

```
"primaryPEP"        — 小学·人教版
"primaryFLTRP"      — 小学·外研版
"primaryYilin"      — 小学·译林版
"primaryHujiao"     — 小学·沪教版
"juniorPEP"         — 初中·人教版
"juniorFLTRP"       — 初中·外研版
"juniorYilin"       — 初中·译林版
"juniorHujiao"      — 初中·沪教版
"seniorPEP"         — 高中·人教版
"seniorFLTRP"       — 高中·外研版
"seniorYilin"       — 高中·译林版
"seniorHujiao"      — 高中·沪教版
"collegeCet"        — 大学英语（四级/六级）
"graduateExam"      — 考研英语
"preschoolPhonics"  — 启蒙/自然拼读
"cefr"              — CEFR 分级
"cambridge"         — 剑桥 English in Use
"longman"           — 朗文 Speakout/Cutting Edge
"ielts"             — 雅思备考
"toefl"             — 托福备考
```

> **设计理念**：不再使用 `difficulty` (easy/medium/hard)，因为难度是相对于教材等级的。  
> 一道 `juniorPEP-7a` 的题对七年级学生是正常难度，对高中生就是简单题。  
> 用户能力提升后，系统自动推荐下学期或下一年级的题目。

### questionType（题型标识）

```
"multipleChoice"   — 选择题
"cloze"            — 填空题
"reading"          — 阅读理解
"translation"      — 翻译题
"rewriting"        — 句型改写
"errorCorrection"  — 纠错题
"sentenceOrdering" — 排序题
"listening"        — 听力专项
"speaking"         — 口语专项
"writing"          — 写作专项
"vocabulary"       — 词汇专项
"grammar"          — 语法专项
"scenarioDaily"    — 日常场景
"scenarioCampus"   — 校园场景
"scenarioWorkplace"— 职场场景
"scenarioTravel"   — 旅行场景
"quickSprint"      — 5分钟快练
"errorReview"      — 错题复练
"randomChallenge"  — 随机挑战
"timedDrill"       — 提速训练
```

### speakingCategory（口语子类型）

```
"readAloud" — 跟读
"respond"   — 对话回答
"retell"    — 复述
"describe"  — 看图说话
```

### writingCategory（写作子类型）

```
"sentence"    — 写句子
"paragraph"   — 写段落
"essay"       — 写短文
"application" — 应用文
```

### vocabularyCategory（词汇子类型）

```
"meaning"  — 词义辨析
"spelling" — 拼写
"form"     — 词形变化
"synonym"  — 近义词
```

### grammarTopic（语法主题）

```
"tense"       — 时态
"clause"      — 从句
"nonFinite"   — 非谓语
"article"     — 冠词
"preposition" — 介词
"passive"     — 被动语态
```

---

## 2. 题型 JSON 定义

> 每道题都包含共有字段（`id`, `type`, `textbookCode`），下方示例中均已展示。  
> 大部分题型包含 `translation` 字段，提供英文原文的中文翻译，方便学生理解。

---

### 2.1 选择题 (multipleChoice)

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440001",
  "questionType": "multipleChoice",
  "textbookCode": "juniorPEP-7a",
  "stem": "The word 'abandon' means ___.",
  "translation": "'abandon' 这个词的意思是 ___。",
  "options": ["to keep", "to give up", "to find", "to carry"],
  "correctIndex": 1,
  "explanation": "abandon 意为'放弃、抛弃'。",
  "explanationTranslation": "abandon means 'to give up or desert'."
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `stem` | string | ✅ | 题干文本（英文） |
| `translation` | string | ✅ | 题干的中文翻译 |
| `options` | string[] | ✅ | 选项数组，通常 4 个 |
| `correctIndex` | int | ✅ | 正确答案在 options 中的索引（0-based） |
| `explanation` | string | ✅ | 答案解析 |
| `explanationTranslation` | string | ❌ | 解析的中文翻译 |

---

### 2.2 填空题 (cloze)

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440002",
  "questionType": "cloze",
  "textbookCode": "juniorPEP-7a",
  "sentence": "I have ___ finished my homework.",
  "translation": "我已经完成了我的作业。",
  "correctAnswer": "already",
  "hints": ["已经"],
  "explanation": "already 用于肯定句中，表示'已经'。",
  "explanationTranslation": "'already' is used in affirmative sentences to mean 'already'."
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sentence` | string | ✅ | 含 `___` 占位符的句子 |
| `translation` | string | ✅ | **填完空后**完整句子的中文翻译 |
| `correctAnswer` | string | ✅ | 正确答案文本 |
| `hints` | string[] | ❌ | 提示词数组（可为 null 或空数组） |
| `explanation` | string | ✅ | 答案解析 |
| `explanationTranslation` | string | ❌ | 解析的中文翻译 |

---

### 2.3 阅读理解 (reading)

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440003",
  "questionType": "reading",
  "textbookCode": "juniorPEP-8a",
  "title": "The Discovery of Penicillin",
  "content": "In 1928, Alexander Fleming noticed that a mold called Penicillium notatum had contaminated one of his petri dishes...",
  "translation": "1928年，亚历山大·弗莱明注意到一种名为青霉菌的霉菌污染了他的一个培养皿……",
  "questions": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440003-q1",
      "stem": "What did Fleming discover?",
      "translation": "弗莱明发现了什么？",
      "options": ["A new virus", "A mold that kills bacteria", "A new medicine", "A type of food"],
      "correctIndex": 1,
      "explanation": "文中明确提到 Fleming 发现了一种能杀死细菌的霉菌。"
    },
    {
      "id": "550e8400-e29b-41d4-a716-446655440003-q2",
      "stem": "When was penicillin discovered?",
      "translation": "青霉素是什么时候被发现的？",
      "options": ["1918", "1928", "1938", "1948"],
      "correctIndex": 1,
      "explanation": "文章第一句提到 In 1928。"
    }
  ]
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `title` | string | ✅ | 文章标题 |
| `content` | string | ✅ | 文章正文（英文） |
| `translation` | string | ✅ | **全文中文翻译** |
| `questions` | array | ✅ | 该篇文章下的题目数组 |
| `questions[].id` | string | ✅ | 子题 ID |
| `questions[].stem` | string | ✅ | 子题题干（英文） |
| `questions[].translation` | string | ✅ | 子题题干的中文翻译 |
| `questions[].options` | string[] | ✅ | 选项 |
| `questions[].correctIndex` | int | ✅ | 正确答案索引 |
| `questions[].explanation` | string | ✅ | 解析 |

> **说明**：每道阅读子题都包含 `explanation`，用于答错后展示解析。

---

### 2.4 翻译题 (translation)

> **无需额外 `translation` 字段**，因为题目本身就是中英互译。

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440004",
  "questionType": "translation",
  "textbookCode": "juniorPEP-8b",
  "sourceText": "科技改变了我们的生活方式。",
  "direction": "zhToEn",
  "referenceAnswer": "Technology has changed our way of life.",
  "keywords": ["technology", "changed", "way of life"],
  "explanation": "注意时态用现在完成时 has changed。",
  "explanationTranslation": "Pay attention to using the present perfect tense 'has changed'."
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sourceText` | string | ✅ | 原文内容 |
| `direction` | string | ✅ | 翻译方向：`"zhToEn"`（中译英）或 `"enToZh"`（英译中） |
| `referenceAnswer` | string | ✅ | 参考译文 |
| `keywords` | string[] | ✅ | 用户答案必须包含的关键词（用于前端简单判分） |
| `explanation` | string | ✅ | 翻译要点解析 |
| `explanationTranslation` | string | ❌ | 解析的中文翻译 |

---

### 2.5 句型改写 (rewriting)

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440005",
  "questionType": "rewriting",
  "textbookCode": "juniorPEP-9a",
  "originalSentence": "He is too young to go to school.",
  "originalTranslation": "他太小了，不能上学。",
  "instruction": "用 so...that 改写",
  "instructionTranslation": "Rewrite using so...that",
  "referenceAnswer": "He is so young that he can't go to school.",
  "referenceTranslation": "他是如此年幼以至于不能上学。",
  "explanation": "too...to 和 so...that...not 可以互换表达。",
  "explanationTranslation": "'too...to' and 'so...that...not' are interchangeable expressions."
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `originalSentence` | string | ✅ | 原始句子（英文） |
| `originalTranslation` | string | ✅ | 原句中文翻译 |
| `instruction` | string | ✅ | 改写要求/指令 |
| `instructionTranslation` | string | ❌ | 改写指令的翻译 |
| `referenceAnswer` | string | ✅ | 参考答案 |
| `referenceTranslation` | string | ✅ | 参考答案的中文翻译 |
| `explanation` | string | ✅ | 解析 |
| `explanationTranslation` | string | ❌ | 解析的翻译 |

---

### 2.6 纠错题 (errorCorrection)

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440006",
  "questionType": "errorCorrection",
  "textbookCode": "juniorPEP-7b",
  "sentence": "She don't like apples.",
  "translation": "她不喜欢苹果。",
  "errorRange": "don't",
  "correction": "doesn't",
  "explanation": "第三人称单数主语 She 后应该用 doesn't。",
  "explanationTranslation": "After third person singular subject 'She', use 'doesn't'."
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sentence` | string | ✅ | 含错误的完整句子 |
| `translation` | string | ✅ | **正确句子**的中文翻译 |
| `errorRange` | string | ✅ | 错误部分的原文文本（前端用于高亮匹配） |
| `correction` | string | ✅ | 正确写法 |
| `explanation` | string | ✅ | 解析 |
| `explanationTranslation` | string | ❌ | 解析的翻译 |

---

### 2.7 排序题 (sentenceOrdering)

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440007",
  "questionType": "sentenceOrdering",
  "textbookCode": "primaryPEP-5a",
  "shuffledParts": ["going", "I", "am", "to school"],
  "correctOrder": [1, 2, 0, 3],
  "correctSentence": "I am going to school.",
  "translation": "我正要去学校。",
  "explanation": "正确语序为 I am going to school.",
  "explanationTranslation": "The correct order is: I am going to school."
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `shuffledParts` | string[] | ✅ | 打乱的词/短语片段 |
| `correctOrder` | int[] | ✅ | 正确顺序的索引数组，指向 shuffledParts 的下标 |
| `correctSentence` | string | ❌ | 正确排列后的完整句子（用于展示答案） |
| `translation` | string | ✅ | 正确排列后完整句子的中文翻译 |
| `explanation` | string | ✅ | 解析 |
| `explanationTranslation` | string | ❌ | 解析的翻译 |

---

### 2.8 听力题 (listening)

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440008",
  "questionType": "listening",
  "textbookCode": "juniorPEP-8a",
  "audioURL": "https://api.volingo.com/audio/listening_001.mp3",
  "transcript": "Good morning, class. Today we're going to learn about the solar system.",
  "transcriptTranslation": "早上好，同学们。今天我们要学习太阳系。",
  "stem": "What is the topic of the lesson?",
  "stemTranslation": "这节课的主题是什么？",
  "options": ["History", "The solar system", "English grammar", "Music"],
  "correctIndex": 1,
  "explanation": "原文明确说 learn about the solar system。",
  "explanationTranslation": "The passage clearly says 'learn about the solar system'."
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `audioURL` | string | ❌ | 音频文件 URL（可为 null，前端有 fallback 显示 transcript） |
| `transcript` | string | ✅ | 听力原文（英文） |
| `transcriptTranslation` | string | ✅ | 听力原文的中文翻译 |
| `stem` | string | ✅ | 问题（英文） |
| `stemTranslation` | string | ✅ | 问题的中文翻译 |
| `options` | string[] | ✅ | 选项数组 |
| `correctIndex` | int | ✅ | 正确答案索引 |
| `explanation` | string | ✅ | 解析 |
| `explanationTranslation` | string | ❌ | 解析的翻译 |

---

### 2.9 口语题 (speaking)

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440009",
  "questionType": "speaking",
  "textbookCode": "juniorPEP-7a",
  "prompt": "Please read the following sentence aloud:",
  "referenceText": "The weather is beautiful today, isn't it?",
  "translation": "今天天气真好，不是吗？",
  "category": "readAloud"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `prompt` | string | ✅ | 题目指引/要求 |
| `referenceText` | string | ✅ | 参考文本（跟读内容 / 参考回答） |
| `translation` | string | ✅ | 参考文本的中文翻译 |
| `category` | string | ✅ | 口语子类型，见枚举 `speakingCategory` |

---

### 2.10 写作题 (writing)

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440010",
  "questionType": "writing",
  "textbookCode": "juniorPEP-9b",
  "prompt": "Write a short paragraph about your favorite hobby. Include what it is, why you like it, and how often you do it.",
  "promptTranslation": "写一段关于你最喜欢的爱好的短文。包括它是什么，你为什么喜欢它，以及你多久做一次。",
  "category": "paragraph",
  "wordLimit": {
    "min": 50,
    "max": 100
  },
  "referenceAnswer": "My favorite hobby is reading. I enjoy it because it allows me to explore different worlds and learn new things. I usually read for about an hour every evening before bed.",
  "referenceTranslation": "我最喜欢的爱好是阅读。我喜欢它，因为它让我探索不同的世界并学习新事物。我通常每天晚上睡前读大约一个小时的书。"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `prompt` | string | ✅ | 写作要求（英文） |
| `promptTranslation` | string | ✅ | 写作要求的中文翻译 |
| `category` | string | ✅ | 写作子类型，见枚举 `writingCategory` |
| `wordLimit.min` | int | ✅ | 最少字数 |
| `wordLimit.max` | int | ✅ | 最多字数 |
| `referenceAnswer` | string | ✅ | 参考范文 |
| `referenceTranslation` | string | ✅ | 参考范文的中文翻译 |

---

### 2.11 词汇题 (vocabulary)

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440011",
  "questionType": "vocabulary",
  "textbookCode": "juniorPEP-7a",
  "word": "brave",
  "phonetic": "/breɪv/",
  "stem": "Which word means '勇敢的'?",
  "translation": "哪个词的意思是'勇敢的'？",
  "options": ["afraid", "brave", "shy", "lazy"],
  "correctIndex": 1,
  "explanation": "brave 意为'勇敢的'。",
  "explanationTranslation": "'brave' means 'courageous'.",
  "category": "meaning",
  "meaning": "勇敢的",
  "exampleSentence": "The brave firefighter saved the child.",
  "exampleTranslation": "勇敢的消防员救了那个孩子。"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `word` | string | ✅ | 目标词汇 |
| `phonetic` | string | ❌ | 音标（可为 null） |
| `meaning` | string | ❌ | 词义（中文） |
| `stem` | string | ✅ | 题干 |
| `translation` | string | ✅ | 题干的中文翻译 |
| `options` | string[] | ✅ | 选项 |
| `correctIndex` | int | ✅ | 正确答案索引 |
| `explanation` | string | ✅ | 解析 |
| `explanationTranslation` | string | ❌ | 解析的翻译 |
| `category` | string | ✅ | 词汇子类型，见枚举 `vocabularyCategory` |
| `exampleSentence` | string | ❌ | 例句（英文） |
| `exampleTranslation` | string | ❌ | 例句的中文翻译 |

---

### 2.12 语法题 (grammar)

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440012",
  "questionType": "grammar",
  "textbookCode": "juniorPEP-7b",
  "stem": "She ___ to school every day.",
  "translation": "她每天去上学。",
  "options": ["go", "goes", "going", "gone"],
  "correctIndex": 1,
  "explanation": "主语 She 是第三人称单数，一般现在时动词加 -es。",
  "explanationTranslation": "The subject 'She' is third person singular, so the verb takes -es in simple present.",
  "grammarPoint": "tense",
  "grammarPointTranslation": "时态"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `stem` | string | ✅ | 题干（英文） |
| `translation` | string | ✅ | 填完空后完整句子的中文翻译 |
| `options` | string[] | ✅ | 选项 |
| `correctIndex` | int | ✅ | 正确答案索引 |
| `explanation` | string | ✅ | 解析 |
| `explanationTranslation` | string | ❌ | 解析的翻译 |
| `grammarPoint` | string | ✅ | 语法主题，见枚举 `grammarTopic` |
| `grammarPointTranslation` | string | ❌ | 语法主题的中文翻译 |

---

### 2.13 场景对话题 (scenario*)

> `type` 可为 `"scenarioDaily"` / `"scenarioCampus"` / `"scenarioWorkplace"` / `"scenarioTravel"`

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440013",
  "questionType": "scenarioDaily",
  "textbookCode": "juniorPEP-7a",
  "scenarioTitle": "在咖啡店点单",
  "context": "你走进一家咖啡店，需要点一杯咖啡。",
  "dialogueLines": [
    {
      "speaker": "AI",
      "text": "Good morning! Welcome to Coffee House. What can I get for you?",
      "translation": "早上好！欢迎来到 Coffee House。你想要点什么？"
    },
    {
      "speaker": "You",
      "text": "___",
      "translation": null
    }
  ],
  "userPrompt": "你想点一杯中杯拿铁",
  "options": [
    "I'd like a medium latte, please.",
    "Give me food.",
    "Where is the bus stop?",
    "I don't know."
  ],
  "correctIndex": 0,
  "referenceResponse": "I'd like a medium latte, please.",
  "referenceTranslation": "我想要一杯中杯拿铁，谢谢。"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `scenarioTitle` | string | ✅ | 场景标题 |
| `context` | string | ✅ | 场景描述（中文） |
| `dialogueLines` | array | ✅ | 对话记录 |
| `dialogueLines[].speaker` | string | ✅ | 说话人：`"AI"` 或 `"You"` |
| `dialogueLines[].text` | string | ✅ | 该轮对话内容（用户轮可用 `"___"` 占位） |
| `dialogueLines[].translation` | string | ❌ | 该轮对话的中文翻译（用户待填轮可为 null） |
| `userPrompt` | string | ✅ | 提示用户应该表达什么 |
| `options` | string[] | ❌ | 选择形式时提供选项（可为 null，表示自由输入） |
| `correctIndex` | int | ❌ | 正确选项索引（options 存在时必填） |
| `referenceResponse` | string | ✅ | 参考回答 |
| `referenceTranslation` | string | ✅ | 参考回答的中文翻译 |

---

## 3. 组合接口

### 3.1 获取练习题组

#### 请求

```
GET /api/v1/practice/questions?type={questionType}&count={n}&textbookCode={code}
X-Device-Id: {deviceId}
```

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `questionType` | string | ✅ | 题型标识（见枚举） |
| `count` | int | ❌ | 题目数量，默认 5 |
| `textbookCode` | string | ✅ | 教材编码，如 `"juniorPEP-7a"` |

> 服务端使用 LEFT JOIN 排除该 `X-Device-Id` 已完成的题目，只返回未做过的题。
> 若该题型全部完成，返回空数组 + `remaining: 0`。

#### 响应

```json
{
  "questionType": "multipleChoice",
  "textbookCode": "juniorPEP-7a",
  "remaining": 450,
  "questions": [
    { /* 对应题型的 JSON 对象 */ },
    { /* ... */ }
  ]
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `remaining` | int | 该题型剩余未完成题数（不含本次返回的）。为 0 时客户端显示"已全部完成" |

> **阅读理解特殊格式**：`type=reading` 时返回的不是 questions 数组，而是 passages 数组：

```json
{
  "questionType": "reading",
  "textbookCode": "juniorPEP-8a",
  "passages": [
    {
      "id": "uuid-string",
      "title": "...",
      "content": "...",
      "translation": "...",
      "questions": [ /* ReadingQuestion 数组 */ ]
    }
  ]
}
```

---

### 3.2 今日推荐套餐

#### 请求

```
GET /api/v1/practice/today-package?textbookCode={code}
X-Device-Id: {deviceId}
```

> 服务端根据 `X-Device-Id` 使用 LEFT JOIN 排除该设备已完成的题目，随机组合不同题型返回未做过的题。

#### 响应

```json
{
  "date": "2026-02-14",
  "textbookCode": "juniorPEP-8a",
  "estimatedMinutes": 15,
  "items": [
    {
      "type": "multipleChoice",
      "count": 10,
      "weight": 0.35,
      "questions": [
        { /* MCQQuestion JSON（含 textbookCode） */ }
      ]
    },
    {
      "type": "cloze",
      "count": 5,
      "weight": 0.20,
      "questions": [
        { /* ClozeQuestion JSON */ }
      ]
    },
    {
      "type": "reading",
      "count": 3,
      "weight": 0.20,
      "passages": [
        { /* ReadingPassage JSON（含 passage.translation） */ }
      ]
    },
    {
      "type": "listening",
      "count": 3,
      "weight": 0.15,
      "questions": [
        { /* ListeningQuestion JSON */ }
      ]
    },
    {
      "type": "vocabulary",
      "count": 5,
      "weight": 0.10,
      "questions": [
        { /* VocabularyQuestion JSON */ }
      ]
    }
  ]
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `date` | string (ISO date) | 套餐日期 |
| `textbookCode` | string | 教材编码 |
| `estimatedMinutes` | int | 预计完成时间（分钟） |
| `items[].type` | string | 题型标识 |
| `items[].count` | int | 该题型题量 |
| `items[].weight` | float | 权重 0~1 |
| `items[].questions` | array | 该题型的题目数组（reading 类型用 `passages`） |

---

### 3.3 学习统计（GitHub 热力图风格）

> 返回用户终身学习数据 + 每日做题活动记录，前端可绘制热力图或曲线图。
> 数据来源：`user_completion` 表按日期聚合，无额外统计表。

#### 请求

```
GET /api/v1/user/stats?days={n}
X-Device-Id: {deviceId}
```

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `days` | int | ❌ | 返回最近 N 天的每日活动数据，默认 365 |

#### 响应

```json
{
  "totalCompleted": 1247,
  "totalCorrect": 1089,
  "currentStreak": 5,
  "longestStreak": 23,
  "dailyActivity": [
    { "date": "2026-02-15", "count": 12, "correctCount": 10 },
    { "date": "2026-02-14", "count": 8,  "correctCount": 7 },
    { "date": "2026-02-13", "count": 0,  "correctCount": 0 }
  ]
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `totalCompleted` | int | 终身总做题数 |
| `totalCorrect` | int | 终身总正确数 |
| `currentStreak` | int | 当前连续打卡天数 |
| `longestStreak` | int | 历史最长连续天数 |
| `dailyActivity` | array | 每日活动数组（按日期降序） |
| `dailyActivity[].date` | string | 日期（ISO date） |
| `dailyActivity[].count` | int | 当日做题数（0 = 未学习） |
| `dailyActivity[].correctCount` | int | 当日正确数 |

> **服务端查询**：
> ```sql
> -- 终身统计
> SELECT COUNT(*) AS total_completed,
>        SUM(CASE WHEN is_correct THEN 1 ELSE 0 END) AS total_correct
> FROM user_completion
> WHERE device_id = :deviceId;
>
> -- 每日活动（最近 N 天）
> SELECT DATE(completed_at) AS date,
>        COUNT(*) AS count,
>        SUM(CASE WHEN is_correct THEN 1 ELSE 0 END) AS correct_count
> FROM user_completion
> WHERE device_id = :deviceId
>   AND completed_at >= NOW() - INTERVAL :days DAY
> GROUP BY DATE(completed_at)
> ORDER BY date DESC;
> ```
> 连续打卡天数需在应用层计算：遍历 `dailyActivity` 从今天往前数连续 count > 0 的天数。

---

## 4. 提交答案 & 题目投诉接口

### 4.1 提交答案（批量）

#### 请求

```
POST /api/v1/practice/submit
X-Device-Id: {deviceId}
```

> **客户端判断对错**：答案已在题目 JSON 中（`correctIndex`、`correctAnswer` 等），客户端本地判断后将结果批量提交给服务端记录。
> 一次提交当次练习中所有做过的题目。服务端根据 `questionId` 从题库查出 `textbookCode`、`questionType`，冗余写入 `user_completion` 表。
> `ON CONFLICT DO NOTHING`（重复提交幂等）。

```json
{
  "results": [
    { "questionId": "550e8400-e29b-41d4-a716-446655440001", "isCorrect": true },
    { "questionId": "550e8400-e29b-41d4-a716-446655440002", "isCorrect": false },
    { "questionId": "550e8400-e29b-41d4-a716-446655440003", "isCorrect": true }
  ]
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `results` | array | ✅ | 答题结果数组 |
| `results[].questionId` | string | ✅ | 题目 ID |
| `results[].isCorrect` | boolean | ✅ | 客户端判断是否正确 |

> 不再需要 `userAnswer` 字段 —— 服务端只记录完成状态，不存储用户作答内容。
> `textbookCode`、`questionType` 由服务端从题库查出后冗余存入完成记录（方案 A：反范式，适合 Cosmos DB 无 JOIN 场景）。

#### 响应

HTTP 204 No Content（无响应体）

### 4.2 投诉错误题目

> 用户发现题目答案有误、题干有歧义等问题时，可提交投诉。后台收集后人工审核或自动下架。

#### 请求

```
POST /api/v1/practice/report
X-Device-Id: {deviceId}
```

```json
{
  "questionId": "550e8400-e29b-41d4-a716-446655440001",
  "reason": "wrongAnswer",
  "description": "正确答案应该是 B 而不是 C"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `questionId` | string | ✅ | 题目 ID |
| `reason` | string | ✅ | 投诉类型，见下方枚举 |
| `description` | string | ❌ | 用户补充说明（可为 null） |

**reason 枚举值**：

| 值 | 说明 |
|----|------|
| `wrongAnswer` | 答案错误 |
| `ambiguous` | 题干有歧义 |
| `typo` | 拼写/语法错误 |
| `inappropriate` | 内容不当 |
| `other` | 其他问题 |

#### 响应

```json
{
  "reportId": "550e8400e29b41d4a716446655440099"
}
```

> **运营用途**：后台统计每道题的投诉次数，投诉 ≥ N 次自动下架待审。审核后可修正题目或永久删除。

---

## 5. 生词本接口

> 生词本数据存储在服务端，通过 `X-Device-Id` 关联用户。  
> 复习逻辑（间隔复习、level 计算）在 iOS 客户端本地完成，服务端只做 CRUD 存储。

### 5.1 添加生词

#### 请求

```
POST /api/v1/wordbook/add
X-Device-Id: {deviceId}
```

```json
{
  "word": "elaborate",
  "phonetic": "/ɪˈlæb.ər.ət/",
  "definitions": [
    {
      "partOfSpeech": "adj.",
      "meaning": "精心制作的；详尽的",
      "example": "She made elaborate preparations for the party.",
      "exampleTranslation": "她为聚会做了精心的准备。"
    },
    {
      "partOfSpeech": "v.",
      "meaning": "详细阐述",
      "example": "Could you elaborate on that point?",
      "exampleTranslation": "你能详细说明一下那个观点吗？"
    }
  ]
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `word` | string | ✅ | 单词原文 |
| `phonetic` | string | ❌ | 音标 |
| `definitions` | array | ✅ | 释义数组 |
| `definitions[].partOfSpeech` | string | ✅ | 词性（adj. / v. / n. 等） |
| `definitions[].meaning` | string | ✅ | 中文释义 |
| `definitions[].example` | string | ❌ | 例句 |
| `definitions[].exampleTranslation` | string | ❌ | 例句中文翻译 |

#### 响应

```json
{
  "id": "wb-550e8400-e29b-41d4-a716-446655440001",
  "word": "elaborate",
  "addedAt": "2026-02-15T10:30:00Z"
}
```

> 如果该单词已存在（同一 deviceId + word 去重），返回已有记录，不重复添加。

---

### 5.2 删除生词

#### 请求

```
DELETE /api/v1/wordbook/{wordId}
X-Device-Id: {deviceId}
```

#### 响应

HTTP 204 No Content（无响应体）

如果 wordId 不存在，返回 HTTP 404：

```json
{ "error": "Word not found" }
```

---

### 5.3 获取生词列表（全量）

#### 请求

```
GET /api/v1/wordbook/list
X-Device-Id: {deviceId}
```

#### 响应

```json
{
  "total": 156,
  "words": [
    {
      "id": "wb-550e8400-e29b-41d4-a716-446655440001",
      "word": "elaborate",
      "phonetic": "/ɪˈlæb.ər.ət/",
      "definitions": [
        {
          "partOfSpeech": "adj.",
          "meaning": "精心制作的；详尽的",
          "example": "She made elaborate preparations for the party.",
          "exampleTranslation": "她为聚会做了精心的准备。"
        }
      ],
      "addedAt": "2026-02-15T10:30:00Z"
    }
  ]
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `total` | int | 生词总数 |
| `words` | array | 全量生词数组（按 addedAt 降序） |
| `words[].id` | string | 生词 ID（用于删除） |
| `words[].word` | string | 单词原文 |
| `words[].phonetic` | string | 音标（可为 null） |
| `words[].definitions` | array | 释义数组 |
| `words[].addedAt` | string | 添加时间（ISO 8601） |

> **说明**：不分页，全量返回。几百个生词的 JSON 体积很小（~50KB）。  
> 客户端拿到全量数据后，在本地完成复习逻辑（correctCount/wrongCount/level/间隔计算）。

#### 数据库参考结构

```sql
CREATE TABLE wordbook (
  id          VARCHAR(64) PRIMARY KEY,
  device_id   VARCHAR(36) NOT NULL,
  word        VARCHAR(128) NOT NULL,
  phonetic    VARCHAR(128),
  definitions JSONB NOT NULL,
  added_at    TIMESTAMP DEFAULT NOW(),
  UNIQUE (device_id, word)            -- 同一用户同一单词不重复
);

CREATE INDEX idx_wordbook_device ON wordbook (device_id);
```

---

## 6. 响应约定

所有接口直接返回业务数据，不做额外包装。通过 HTTP 状态码表示成功或失败：

| HTTP 状态码 | 说明 | 响应体 |
|-------------|------|--------|
| 200 | 成功（有数据返回） | 业务数据 JSON |
| 204 | 成功（无需返回数据） | 无 |
| 400 | 请求参数错误 | `{ "error": "..." }` |
| 404 | 资源不存在 | `{ "error": "..." }` |
| 429 | 请求过于频繁 | `{ "error": "..." }` |
| 500 | 服务端内部错误 | `{ "error": "..." }` |

错误示例：

```json
{ "error": "Missing X-Device-Id header" }
```

---

## 附：iOS 客户端对应的 Swift Model 映射

| JSON type 值 | Swift 模型 | 所在文件 |
|--------------|-----------|---------|
| `multipleChoice` | `MCQQuestion` | QuestionModels.swift |
| `cloze` | `ClozeQuestion` | QuestionModels.swift |
| `reading` | `ReadingPassage` + `ReadingQuestion` | QuestionModels.swift |
| `translation` | `TranslationQuestion` | QuestionModels.swift |
| `rewriting` | `RewritingQuestion` | QuestionModels.swift |
| `errorCorrection` | `ErrorCorrectionQuestion` | QuestionModels.swift |
| `sentenceOrdering` | `OrderingQuestion` | QuestionModels.swift |
| `listening` | `ListeningQuestion` | QuestionModels.swift |
| `speaking` | `SpeakingQuestion` | QuestionModels.swift |
| `writing` | `WritingQuestion` | QuestionModels.swift |
| `vocabulary` | `VocabularyQuestion` | QuestionModels.swift |
| `grammar` | `GrammarQuestion` | QuestionModels.swift |
| `scenario*` | `ScenarioQuestion` | QuestionModels.swift |

---

## 附：textbookCode 与 iOS TextbookOption 映射

| textbookCode 前缀 | iOS TextbookOption | 适用年级 |
|-------------------|--------------------|---------|
| `primaryPEP-{1~6}{a\|b}` | `.primaryPEP` | 小学1~6年级 |
| `primaryFLTRP-{1~6}{a\|b}` | `.primaryFLTRP` | 小学1~6年级 |
| `primaryYilin-{1~6}{a\|b}` | `.primaryYilin` | 小学1~6年级 |
| `primaryHujiao-{1~6}{a\|b}` | `.primaryHujiao` | 小学1~6年级 |
| `juniorPEP-{7~9}{a\|b}` | `.juniorPEP` | 初中7~9年级 |
| `juniorFLTRP-{7~9}{a\|b}` | `.juniorFLTRP` | 初中7~9年级 |
| `juniorYilin-{7~9}{a\|b}` | `.juniorYilin` | 初中7~9年级 |
| `juniorHujiao-{7~9}{a\|b}` | `.juniorHujiao` | 初中7~9年级 |
| `seniorPEP-{10~12}{a\|b}` | `.seniorPEP` | 高中10~12年级 |
| `seniorFLTRP-{10~12}{a\|b}` | `.seniorFLTRP` | 高中10~12年级 |
| `seniorYilin-{10~12}{a\|b}` | `.seniorYilin` | 高中10~12年级 |
| `seniorHujiao-{10~12}{a\|b}` | `.seniorHujiao` | 高中10~12年级 |
| `collegeCet` | `.collegeCet` | 大学四六级 |
| `graduateExam` | `.graduateExam` | 考研 |
| `cefr` | `.cefr` | CEFR 分级 |
| `cambridge` | `.cambridge` | 剑桥教材 |
| `longman` | `.longman` | 朗文教材 |
| `ielts` | `.ielts` | 雅思备考 |
| `toefl` | `.toefl` | 托福备考 |

---

> **给后端 AI 的提示**：  
> 1. 严格按照上述 JSON 格式返回数据，iOS 客户端的 `Codable` 解码即可直接工作。  
> 2. 每道题必须携带 `textbookCode`，用于按教材维度出题和升级。  
> 3. 提供 `POST /api/v1/practice/report` 接口供用户投诉错误题目。  
> 4. 除翻译题外，所有含英文原文的题型都必须提供对应的中文翻译字段。  
> 5. 当前前端使用 `MockDataFactory` 生成本地数据，后续替换为 HTTP 请求即可。  
> 6. **所有 API 请求都必须携带 `X-Device-Id` Header**，服务端以此追踪匿名用户的做题记录和生词本。  
> 7. **选题使用 LEFT JOIN 排除已完成题目**：`question_bank LEFT JOIN user_completion ON id = question_id AND device_id = :id WHERE uc.id IS NULL`，避免 `NOT IN` 大列表。  
> 8. **submit 由客户端判断对错**，服务端只记录到 `user_completion`，`ON CONFLICT DO NOTHING` 保证幂等。  
> 9. **做过的题永久排除**，不会再出现在后续请求中。题库全部完成时返回 `remaining: 0`。  
> 10. **生词本**全量返回（不分页），复习逻辑在客户端本地完成，服务端只做 CRUD 存储。  
> 11. **学习统计**从 `user_completion` 表按日期聚合，支持 GitHub 热力图风格的每日活动数据。
