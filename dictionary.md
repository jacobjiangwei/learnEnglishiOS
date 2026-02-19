# 词典 & 生词本 功能设计

> 第二个 Tab: 查词 + 生词本，合并为一个统一的词汇学习入口。

---

## 一、核心思路

### 1.1 查词功能：Cosmos DB + AI 兜底

**当前状态**: iOS 端曾尝试用本地 SQLite 词典 (`learnEnglishDict.db`)，但数据只有一万多词，已放弃。

**新方案**: 后端查词 + AI 兜底 + iOS 本地 SQLite 持久缓存（新建的缓存库，不是旧词典）。

```
用户输入单词
    → ① iOS 本地缓存 SQLite 查询 (wordCache.db)
        → 命中 → 直接展示，不请求后端
        → 未命中 ↓
    → ② 后端 GET /api/v1/dictionary/{word}
        → Cosmos DB "dictionary" 容器查询 (PK: /word)
            → 命中 → 直接返回
            → 未命中 → 调用 AI (OpenAI/Azure OpenAI) 生成词条
                      → 写入 Cosmos DB (后续其他用户查询直接命中)
                      → 返回给客户端
    → ③ iOS 收到响应后，写入本地 SQLite 缓存 (wordCache.db)
        → 下次查同一个词，直接走 ①，零流量

注: 本地 SQLite 是专为缓存后端查询结果新建的数据库，不是旧的 learnEnglishDict.db。
```

**优势**:
- 永远不会查不到词——AI 兜底保证 100% 覆盖
- **每个词只请求后端一次**，之后永久本地命中，极省流量
- 词条质量会随使用量自然积累，热门词汇由 AI 生成一次后缓存
- 未来可人工审核/修正 AI 生成的词条，提升质量
- 服务端统一管理数据，多端共享

### 1.2 生词本：轻量存储 + 本地复习

**已有**: 后端 wordbook 容器 (PK: /deviceId)，支持 add/delete/list。

**核心原则**: 生词本 assume 该单词的完整词条已在本地缓存中存在（因为用户查过才会加入生词本）。因此 **生词本只存生词本特有的元数据**（加入时间、复习状态等），不重复存储单词释义。展示时从本地词条缓存中读取完整信息。如果本地缓存意外丢失，再次查一下后端即可。

**迭代**:
- 查询即收藏（可选）：用户设置里有开关，默认关闭
- 手动收藏：词条详情页有收藏按钮
- 生词本与复习系统联动：生词自动进入艾宾浩斯复习队列
- **复习完全在本地进行**：艾宾浩斯计算、待复习列表、复习状态更新全部 iOS 本地完成，不需要后端 API

---

## 二、数据模型

### 2.1 词典词条文档 (Cosmos DB: "dictionary" 容器)

```
容器: dictionary
分区键: /word
id: 单词本身 (小写，如 "abandon")
```

```json
{
  "id": "abandon",
  "word": "abandon",
  "phonetic": "/əˈbændən/",
  "audioUrl": null,
  "senses": [
    {
      "pos": "vt.",
      "definitions": ["to leave completely and finally"],
      "translations": ["抛弃，放弃"],
      "examples": [
        {
          "en": "He abandoned his wife and children.",
          "zh": "他抛弃了妻子和孩子。"
        }
      ]
    },
    {
      "pos": "n.",
      "definitions": ["a feeling of freedom from worry or shame"],
      "translations": ["放纵，放任"],
      "examples": [
        {
          "en": "She danced with wild abandon.",
          "zh": "她尽情地跳舞。"
        }
      ]
    }
  ],
  "exchange": {
    "pastTense": "abandoned",
    "pastParticiple": "abandoned",
    "presentParticiple": "abandoning",
    "thirdPersonSingular": "abandons",
    "plural": null,
    "comparative": null,
    "superlative": null
  },
  "synonyms": ["desert", "forsake", "relinquish", "give up"],
  "antonyms": ["keep", "retain", "maintain"],
  "relatedPhrases": [
    { "phrase": "abandon ship", "meaning": "弃船" },
    { "phrase": "abandon hope", "meaning": "放弃希望" },
    { "phrase": "with abandon", "meaning": "放纵地，尽情地" }
  ],
  "usageNotes": "abandon 强调完全彻底地放弃，语气比 give up 更强烈。",
  "source": "ai",
  "createdAt": "2026-02-19T10:00:00Z",
  "queryCount": 42
}
```

**与现有 `Word` 模型的兼容性**: 核心字段 (`word`, `phonetic`, `senses`, `exchange`, `synonyms`, `antonyms`) 保持一致，iOS 端可复用现有的 `Word` 模型解析。新增 `relatedPhrases`、`usageNotes`、`source`、`queryCount` 等后端专用字段。

### 2.2 生词本

生词本分两层存储：

#### 后端 WordbookDocument (Cosmos DB, 仅同步备份用)

只存最精简的信息，用于跨设备同步和数据备份：

```json
{
  "id": "device123_abandon",
  "deviceId": "device123",
  "word": "abandon",
  "addedAt": "2026-02-19T10:00:00Z",
  "source": "dictionary"
}
```

**不存释义、音标等内容**——这些数据在本地词条缓存里已经有了。

#### iOS 本地 SavedWord (本地持久化，主要数据源)

本地存储包含完整的生词本元数据 + 复习状态：

```json
{
  "word": "abandon",
  "addedAt": "2026-02-19T10:00:00Z",
  "source": "dictionary",

  "reviewLevel": 0,
  "nextReviewAt": "2026-02-19T10:10:00Z",
  "correctCount": 0,
  "wrongCount": 0,
  "lastReviewedAt": null
}
```

展示时，用 `word` 作为 key 去本地词条缓存取完整释义。如果缓存丢失，重新调后端 API 查一次。

**字段说明**:
- `source` — 来源 (`"dictionary"` 查词添加 / `"manual"` 手动添加 / `"practice"` 做题中遇到的)
- `reviewLevel` — 艾宾浩斯复习等级 (0-7)，**纯本地**
- `nextReviewAt` — 下次复习时间，**纯本地**
- `correctCount` / `wrongCount` — 复习正确/错误次数，**纯本地**
- `lastReviewedAt` — 上次复习时间，**纯本地**

---

## 三、后端 API 设计

### 3.1 词典查询

```
GET /api/v1/dictionary/{word}
```

**响应**:
```json
{
  "word": "abandon",
  "phonetic": "/əˈbændən/",
  "senses": [...],
  "exchange": {...},
  "synonyms": [...],
  "antonyms": [...],
  "relatedPhrases": [...],
  "usageNotes": "..."
}
```

**后端逻辑** (`DictionaryService`):
1. 接收 word 参数，转小写
2. 查询 Cosmos DB `dictionary` 容器，PK = word
3. 命中 → 增加 `queryCount`，返回
4. 未命中 → 调用 AI 生成 → 写入 Cosmos → 返回
5. AI 生成的 prompt 包含：词性、释义、例句、近反义词、常用短语、用法说明

### 3.2 生词本 (已有，精简)

```
POST   /api/v1/wordbook          — 添加生词 (word + source，不传释义)
DELETE /api/v1/wordbook/{wordId} — 删除生词
GET    /api/v1/wordbook          — 获取生词本列表 (仅 word + addedAt + source)
```

**不需要复习相关的 API**——复习状态、待复习列表、艾宾浩斯计算全部在 iOS 本地完成。

### 3.3 模糊搜索 / 联想词 (本地实现，不走 API)

**不通过后端 API 实现**。iOS 本地导入一个纯单词 key 的轻量 DB（仅单词列表，无释义，体积很小），用于输入时的下拉联想。

用户也可以不采纳联想，直接输入任意词（包括互联网词语、缩写等），都允许查询。

> 联想功能优先级较低 (P1)，之后再做。

---

## 四、AI 生成词条的 Prompt 设计

```
You are an English dictionary engine. Generate a comprehensive dictionary entry 
for the word "{word}" in the following JSON format:

{
  "word": "...",
  "phonetic": "IPA notation",
  "senses": [
    {
      "pos": "part of speech abbreviation (n., v., adj., adv., etc.)",
      "definitions": ["English definition 1", "English definition 2"],
      "translations": ["中文翻译1", "中文翻译2"],
      "examples": [
        { "en": "Example sentence in English.", "zh": "中文翻译。" }
      ]
    }
  ],
  "exchange": {
    "pastTense": "...", "pastParticiple": "...", 
    "presentParticiple": "...", "thirdPersonSingular": "...",
    "plural": "...", "comparative": "...", "superlative": "..."
  },
  "synonyms": ["..."],
  "antonyms": ["..."],
  "relatedPhrases": [
    { "phrase": "...", "meaning": "中文含义" }
  ],
  "usageNotes": "中文使用说明，包含易混淆词对比和常见错误提示"
}

Rules:
- Include ALL common parts of speech for this word
- Each sense should have 1-2 examples
- Provide 3-5 synonyms and antonyms if applicable
- Related phrases should be real, commonly used collocations
- Usage notes should target Chinese English learners
- Set irrelevant exchange fields to null
- Return ONLY valid JSON, no markdown
```

---

## 五、iOS 端改动

### 5.1 DictionaryService 改造

**当前**: 旧的本地 SQLite 词典 (`learnEnglishDict.db`) 已放弃（仅一万多词，不完整）。

**改为**: 新建本地 SQLite 缓存库 (`wordCache.db`) + 后端 API 兜底。

```swift
// 新的 DictionaryService 行为:
// 1. 先查本地 SQLite 缓存 (wordCache.db)
//    → 命中：直接返回，零网络开销
// 2. 缓存未命中 → 调 GET /api/v1/dictionary/{word}
// 3. 返回结果后 **写入 wordCache.db 永久保存**
//    → 该词以后永远走本地，不再请求后端
// 4. 无网络且本地也没有 → 提示用户无法查询，稍后再试
```

本地缓存策略：
- **不设过期时间**，查过一次就永久保存在 `wordCache.db`
- `wordCache.db` 是一个新建的 SQLite 数据库，专门存储从后端拉取的词条
- 旧的 `learnEnglishDict.db` 不再使用，可移除
- 如果需要更新词条（后端修正了 AI 错误），可以在 app 更新时提供清除缓存选项

### 5.2 界面结构 (第二个 Tab)

```
📖 词典 Tab
├── 🔍 搜索栏 (顶部常驻)
│   ├── 输入时：下拉联想词列表
│   └── 搜索时：展示词条详情
│
├── 📋 最近查过 (搜索栏下方，横向滚动 chips)
│   └── 最近 10 个查过的词，点击快速再看
│
├── 切换 Segment: [词典] [生词本]
│
│── 词典 (默认)
│   ├── 搜索结果 → 词条详情卡片
│   │   ├── 单词 + 音标 + 🔊播放发音
│   │   ├── 释义列表 (按词性分组)
│   │   │   └── 每个义项: 英文定义 + 中文翻译 + 例句
│   │   ├── 词形变化 (时态/复数等)
│   │   ├── 近义词 / 反义词 (可点击跳转查询)
│   │   ├── 常用短语
│   │   ├── 用法说明
│   │   └── ⭐ 添加到生词本 按钮
│   └── 空状态: 热门词汇推荐 / 今日单词
│
└── 生词本
    ├── 📊 统计栏: 总数 / 待复习 / 已掌握
    ├── 筛选: 全部 / 待复习 / 新词 / 已掌握
    ├── 生词列表
    │   ├── 每行: 单词 + 音标 + 首个释义 + 复习状态标签
    │   ├── 左滑: 删除
    │   └── 点击: 展开详情 / 跳转词典
    └── 🧠 开始复习 按钮 (跳转到复习 Session)
```

### 5.3 设置项

```
词典设置
├── 查词自动加入生词本: [开关，默认关闭]
└── 清除查词缓存: [按钮] (清空 wordCache.db，重新从后端拉取)
```

---

## 六、实现优先级

### Phase 1 — 核心查词 (MVP)

| # | 任务 | 端 |
|---|------|----|
| 1 | 后端: 创建 `dictionary` Cosmos 容器 (PK: /word) | Backend |
| 2 | 后端: `DictionaryDocument` 数据模型 | Backend |
| 3 | 后端: `GET /api/v1/dictionary/{word}` 精确查询 + AI 兜底 | Backend |
| 4 | iOS: `APIService` 添加 dictionary 端点 | iOS |
| 5 | iOS: 本地词条持久缓存层 (查过的词永久存本地) | iOS |
| 6 | iOS: `DictionaryService` 改为 本地缓存优先 → API 兜底 | iOS |
| 7 | iOS: 更新 `DictionaryView` 适配新数据源 | iOS |

### Phase 2 — 生词本增强

| # | 任务 | 端 |
|---|------|----|
| 8 | 后端: `WordbookDocument` 精简为只存 word + addedAt + source | Backend |
| 9 | iOS: 本地 SavedWord 增加艾宾浩斯复习字段 | iOS |
| 10 | iOS: 生词本列表 UI + 筛选 (从本地缓存读取词条详情) | iOS |
| 11 | iOS: 查词 → 收藏联动 (含设置开关) | iOS |
| 12 | iOS: 本地复习系统 (艾宾浩斯计算 + 复习 Session) | iOS |

### Phase 3 — 体验优化

| # | 任务 | 端 |
|---|------|----|
| 13 | iOS: 导入纯单词 key DB，实现本地搜索联想 | iOS |
| 14 | iOS: 最近查过横向 chips | iOS |
| 15 | iOS: 空状态热门词 / 今日推荐词 | iOS |
| 16 | 后端: 词条质量审核后台 (人工纠正 AI 错误) | Backend |
| 17 | iOS: 移除旧 `learnEnglishDict.db`，清理无用代码 | iOS |

---

## 七、成本与注意事项

- **AI 生成成本**: 每个词条约 500-800 tokens (GPT-4o ~$0.005/词条)，常用英语词汇约 3-5 万词，全量预生成约 $150-$250。也可按需生成，初期几乎无成本。
- **Cosmos DB RU**: 单次查询约 3-5 RU，AI 写入约 10 RU。免费层 1000 RU/s 足够初期使用。
- **缓存策略**: iOS 本地**永久缓存**，每个词只请求后端一次，之后零流量。
- **并发保护**: 多个用户同时查同一个不存在的词时，需要防止重复 AI 生成。可用 Cosmos upsert 或分布式锁。
- **数据预热**: 可以批量预生成高频词条 (CET4/CET6 核心词汇 ~5000 词)，减少用户首次查询延迟。
- **本地缓存大小**: 每个词条约 1-2KB，1 万词约 10-20MB，完全可接受。