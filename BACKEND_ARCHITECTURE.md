# 题库后台架构设计 (Phase 1)

> 目标: 基于授权教材构建云端大题库, 自动生成创新题型, 可追溯、可扩展、可审计

---

## 1. 总体架构

**核心模块**
- 内容入库与结构化
- AI 出题与自动筛选
- 人工抽检与规则校验
- 题库入库 (Cosmos DB)
- 媒体资源存储 (Blob)
- 客户端拉题与练习记录

**逻辑分层**
- Ingestion Layer: 教材导入与文本结构化
- Generation Layer: AI 出题与质量控制
- Storage Layer: 题库与媒体
- Delivery Layer: API 出题分发

---

## 2. 流程与数据流

1) 内容入库 (授权教材)
- 输入: PDF/EPUB/Word/纯文本
- 输出: 标准化 JSON

2) 清洗结构化
- 句子拆分、词汇提取、语法点标注
- 按 书籍 -> 单元 -> 课文 -> 句子 组织

3) AI 生成题目 + 初步筛选
- 题型模板 + Prompt 约束
- 自动检查: 答案唯一性、语法正确性、难度合理

4) 人工抽检 / 规则校验
- 抽样 10% 题目人工复审
- 关键题型强制审核

5) 写入 Cosmos DB
- 题目元数据与题干

6) 媒体文件存 Blob
- 图片/音频/视频与题目关联

7) 客户端按规则拉题
- 按等级、年级、题型、题源、难度

---

## 3. 数据模型 (核心字段)

### 3.1 Content 结构化数据
```json
{
  "bookId": "book_001",
  "bookName": "人教版高中英语必修一",
  "unit": "Unit 1",
  "lesson": "Reading",
  "sentences": [
    {"id": "s_001", "text": "...", "tokens": ["..."], "grammar": ["..."], "level": "高一"}
  ]
}
```

### 3.2 Question 题目数据
```json
{
  "id": "q_20260209_0001",
  "system": "国内",
  "level": "高一",
  "skill": "词汇",
  "type": "choice",
  "stem": "选出“苹果”的英文",
  "options": ["apple", "banana", "orange", "grape"],
  "correctIndex": 0,
  "explanation": "apple 表示苹果。",
  "difficulty": 2,
  "tags": ["名词", "日常"],
  "media": {"imageUrl": null, "audioUrl": null},
  "source": {
    "type": "book",
    "name": "人教版高中英语必修一",
    "unit": "Unit 1",
    "page": 12
  },
  "reviewStatus": "approved",
  "version": 1,
  "createdAt": "2026-02-09T00:00:00Z"
}
```

---

## 4. Cosmos DB 设计建议

**容器划分**
- `Questions`: 题库主表
- `ContentUnits`: 教材结构化内容
- `UserProgress`: 用户练习记录 (可选)

**Partition Key**
- `Questions`: `level` 或 `system+level` (高基数, 常用拉题条件)
- `ContentUnits`: `bookId`

**注意事项**
- 单题 JSON < 2MB
- 媒体不入库, 放 Blob
- 题目可打标签方便分组拉题

---

## 5. Blob Storage 设计

- 目录结构:
  - `books/{bookId}/images/...`
  - `books/{bookId}/audio/...`
  - `questions/{questionId}/...`

- 通过 URL 与题目关联

---

## 6. 题库生成策略

**题型层级**
- 教材忠实题: 考察同一知识点, 但不照抄
- 变体题: 改语境、改表达、同义改写
- 迁移题: 跨单元组合, 强化应用

**质量控制**
- AI 出题后做规则校验
- 难度分层与错误选项可控
- 人工抽检 10%

---

## 7. API 交付方式 (简化)

- `GET /questions?system=&level=&type=&count=`
- `POST /questions/feedback` (纠错与举报)
- `POST /progress` (答题记录)

---

## 8. 后续扩展

- 支持题目版本管理与回滚
- 支持 AB 测试不同题型
- 支持 LLM 题目动态生成与缓存
- 支持分年级题库迁移


题目的 json

{
  "id": "q_20260209_0001",
  "level": "高一",
  "system": "国内",
  "skill": "词汇",
  "type": "choice",
  "stem": "选出“苹果”的英文",
  "options": ["apple", "banana", "orange", "grape"],
  "correctIndex": 0,
  "explanation": "apple 表示苹果。",
  "difficulty": 2,
  "tags": ["名词", "日常"],
  "media": {
    "imageUrl": null,
    "audioUrl": null
  },
  "source": {
    "type": "book",
    "name": "人教版高中英语必修一",
    "unit": "Unit 1",
    "page": 12
  },
  "version": 1,
  "createdAt": "2026-02-09T00:00:00Z"
}

支持多题型的“播放器”设计

你理解的方向完全正确：
无论学习/复习/练习，最终都是做题。
只要题目格式统一、type 清晰，前端做一个“题目播放器”即可：

type	交互	说明
choice	单选	中英互译
image_choice	图片选择	图词匹配
fill_blank	填空	例句挖空
spelling	输入拼写	记忆强化
listening_choice	听音选择	听力
speaking_repeat	跟读	语音评测
reading_mcq	阅读选择	段落理解
