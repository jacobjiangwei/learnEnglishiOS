# Volingo AI 出题方案

## 一、整体思路

```
教材 PDF → Document Intelligence 提取 → GPT-4o 结构化分析 → TextbookAnalysis (已完成)
                                                                    ↓
                                                              AI 批量出题 (本方案)
                                                                    ↓
                                                          questions 容器 (Cosmos DB)
                                                                    ↓
                                                        每日包 / 按需抽题 → iOS App
```

核心原则：**按单元 × 按题型批次** 逐步生成，每次 API 调用只生成一个单元的一组题型，避免 token 溢出。

---

## 二、数据源（每个单元可用的素材）

来自 `TextbookAnalysis.Units[i]`：

| 素材 | 典型规模 | 说明 |
|------|---------|------|
| `Vocabulary[]` | 8~25 词 | word, meaning, type |
| `SentencePatterns[]` | 2~6 条 | pattern, usage |
| `Grammar[]` | 1~3 个知识点 | 语法描述 |
| `Songs[]` | 0~2 首 | 歌谣/韵文 |
| `Commands[]` | 0~5 条 | 课堂指令 |
| `StoryTitle/Summary` | 0~1 篇 | 单元故事 |

另外 `VocabularyGlossary[]` 提供全书词汇表，可用于生成跨单元干扰项。

---

## 三、题目数量规划

### 3.1 每单元出题目标

| 题型 | apiKey | 每单元数量 | 素材来源 | 说明 |
|------|--------|-----------|---------|------|
| 词汇选择 | `vocabulary` | **15~20** | Vocabulary | 含义选择、拼写、词形变化、近义词 |
| 语法选择 | `grammar` | **8~10** | Grammar + SentencePatterns | 每个语法点 3~4 题 |
| 填空题 | `cloze` | **10~12** | Vocabulary + SentencePatterns | 句中挖词 |
| 选择题 | `multipleChoice` | **10~15** | 综合 | 涵盖词义/语法/常识 |
| 翻译题 | `translation` | **6~8** | SentencePatterns + Vocabulary | 中译英/英译中各半 |
| 句型改写 | `rewriting` | **5~6** | SentencePatterns + Grammar | 陈述↔疑问、主动↔被动 |
| 纠错题 | `errorCorrection` | **5~6** | Grammar + Vocabulary | 常见错误 |
| 排序题 | `sentenceOrdering` | **5~6** | SentencePatterns | 打乱重组 |
| 阅读理解 | `reading` | **3~4 篇** (每篇 3~4 小题) | 单元话题 + Vocabulary | AI 生成短文 |
| 听力题 | `listening` | **6~8** | Vocabulary + SentencePatterns | 生成 transcript + 选择题 |
| 口语题 | `speaking` | **6~8** | SentencePatterns + Vocabulary | 朗读/翻译说/跟读/补全 |
| 写作题 | `writing` | **3~4** | 单元主题 | 写句/写段/应用文 |

**每单元合计：约 80~110 题**

### 3.2 每册教材总量

| 学段 | 典型单元数 | 每单元题数 | 每册总题数 |
|------|-----------|-----------|-----------|
| 小学 | 6~8 | 80~100 | **500~800** |
| 初中 | 8~12 | 90~110 | **720~1320** |
| 高中 | 8~10 | 90~110 | **720~1100** |

这个量级足够支撑：
- 每日练习包 (15~20 题/天) → 一学期不重复
- 专项训练模式 → 足够深度
- 错题复练 → 有足够变体

---

## 四、切片策略（解决 token 限制）

### 4.1 GPT-4o Token 预算

| 项目 | Token 数 |
|------|---------|
| 系统提示（JSON schema + 规则） | ~1500 |
| 单元素材输入 | ~500~2000 |
| 全书词汇表（用于干扰项） | ~1000~3000 |
| **输入合计** | **~3000~6500** |
| 输出预算（max_tokens） | **8000~12000** |
| 单题 JSON 平均 | ~200~400 tokens |
| **单次可生成** | **20~50 题** |

结论：**一个单元 + 一个批次（2~3 种相关题型）= 一次 API 调用**，完全在 token 限制内。

### 4.2 分 Batch 调用

把 12 种题型分成 **5 个 Batch**，每个 Batch 共享上下文，减少 API 调用次数：

```
Batch 1: 词汇基础
├── vocabulary (15~20 题)
├── cloze (10~12 题)
└── 输入：Vocabulary[] + GlossaryEntry[]（干扰项）
    输出预估：~6000 tokens

Batch 2: 语法 & 选择
├── grammar (8~10 题)
├── multipleChoice (10~15 题)
├── errorCorrection (5~6 题)
└── 输入：Grammar[] + SentencePatterns[] + Vocabulary[]
    输出预估：~7000 tokens

Batch 3: 产出型
├── translation (6~8 题)
├── rewriting (5~6 题)
├── sentenceOrdering (5~6 题)
└── 输入：SentencePatterns[] + Grammar[]
    输出预估：~5000 tokens

Batch 4: 篇章型
├── reading (3~4 篇，含子题)
├── writing (3~4 题)
└── 输入：Unit topic + Vocabulary[] + SentencePatterns[]
    输出预估：~8000 tokens

Batch 5: 听说型
├── listening (6~8 题)
├── speaking (6~8 题)
└── 输入：Vocabulary[] + SentencePatterns[] + Commands[]
    输出预估：~5000 tokens
```

### 4.3 生成流程

```
对每本教材:
  ├── 读取 TextbookDocument.Analysis
  ├── 提取全书词汇表 (用于干扰项池)
  │
  └── 对每个 Unit (并行或顺序):
      ├── Batch 1: POST GPT-4o → vocabulary + cloze
      ├── Batch 2: POST GPT-4o → grammar + MCQ + errorCorrection
      ├── Batch 3: POST GPT-4o → translation + rewriting + ordering
      ├── Batch 4: POST GPT-4o → reading + writing
      ├── Batch 5: POST GPT-4o → listening + speaking
      │
      └── 合并所有题目 → 写入 Cosmos "questions" 容器
          (partition key = textbookCode)
```

每个单元 5 次 API 调用，一本 8 单元教材 = **40 次调用**。
按 GPT-4o 10K TPM 限制，限速约 1 call / 6s，总耗时约 **4~5 分钟/册**。

---

## 五、级别标注

每道题标注 `level` 字段，与 iOS 端 `UserLevel` 体系对齐。
值直接取自教材的 textbookCode 所对应的学段，例如：

| textbookCode 前缀 | level 值 | 说明 |
|-------------------|----------|------|
| `primaryPEP-3a` | `"小学三年级"` | 根据 grade 号自动映射 |
| `juniorPEP-8b` | `"初二"` | 初中 grade 8 = 初二 |
| `seniorPEP-11a` | `"高二"` | 高中 grade 11 = 高二 |
| `collegeCet4` | `"四级"` | 非学段系列直接映射 |

`level` 由 textbookCode 自动确定，无需 AI 判断。
同一册书的所有题目 `level` 相同。

---

## 六、题目 JSON Schema（与现有系统对齐）

所有题目沿用 `QuestionSeeder` 已有的 `Dictionary<string, object>` 动态 schema，**新增**以下通用字段：

```json
{
  "id": "guid",
  "questionType": "vocabulary",
  "textbookCode": "juniorPEP-7a",
  "unitNumber": 3,
  "level": "初一",
  "tags": ["unit3", "vocabulary", "meaning"],
  "generatedBy": "gpt-4o",
  "generatedAt": "2025-01-15T10:30:00Z",
  
  // ... 题型特定字段 (保持与 QuestionSeeder 一致)
}
```

新增字段说明：
- `unitNumber` — 来自哪个单元，用于按单元筛选练习
- `level` — 用户学段级别，与 iOS `UserLevel` 枚举值对齐（如 `"初一"`、`"高二"`、`"四级"`）
- `tags` — 标签数组，用于精细筛选
- `generatedBy` — 标记 AI 生成 vs 人工录入
- `generatedAt` — 生成时间

---

## 七、Prompt 设计要点

### 7.1 系统提示模板（以 Batch 1 为例）

```
你是一个专业的英语教育出题专家。根据给定的教材单元词汇表，生成高质量的练习题。

规则：
1. 所有题目必须基于给定的词汇和句型，不能超纲
2. 中文翻译准确自然，适合中国学生
3. 干扰项合理但有区分度，不能出现两个正确答案
4. 题目要紧扣该年级课本内容，不超纲
5. 每道题都要有详细的中英文解析
6. 输出严格 JSON 格式

=== 当前教材信息 ===
教材: {textbookCode}
单元: Unit {unitNumber} - {unitTitle}
话题: {topic}

=== 本单元词汇表 ===
{vocabulary_json}

=== 全书词汇表（用于生成干扰项） ===
{glossary_json}

=== 要求生成的题型和数量 ===
1. vocabulary 题 × 18 道（含 meaning/spelling/form/synonym 四种 category）
2. cloze 题 × 10 道

请以 JSON 数组格式输出所有题目。
```

### 7.2 关键 Prompt 技巧

1. **提供干扰项池**：把全书词汇表传入，让 AI 从同册课本中选择形近/义近词作为干扰项
2. **指定 category 分布**：vocabulary 题要均匀覆盖 meaning / spelling / form / synonym
3. **限定适用年级**：在 prompt 中注明 level，确保题目难度与学段匹配
4. **给出 JSON 示例**：每种题型给 1 个完整示例，确保格式一致
5. **temperature = 0.7**：比分析阶段(0.1)略高，增加题目多样性

---

## 八、质量保障

### 8.1 自动校验（生成后立即执行）

| 检查项 | 规则 |
|--------|------|
| JSON 格式 | 能正确反序列化 |
| 必填字段 | 每种题型的必填字段都存在 |
| correctIndex 范围 | 0 ≤ correctIndex < options.length |
| 选项数量 | MCQ/grammar/vocabulary 至少 4 个选项 |
| 无重复 ID | 同一 textbookCode 下 ID 唯一 |
| 答案合理 | correctIndex 对应的选项确实正确（抽样） |
| level 正确 | level 值与 textbookCode 对应的 UserLevel 一致 |

### 8.2 失败重试

- 单个 Batch 解析失败 → 自动重试 (最多 3 次)
- 校验不通过 → 重新生成该 Batch
- 部分题目缺失字段 → 丢弃该题，不影响其他题

---

## 九、增量更新策略

| 场景 | 策略 |
|------|------|
| 首次导入教材 | 全量生成所有单元所有题型 |
| 教材重新分析 | 标记旧题 `deprecated = true`，重新生成 |
| 手动追加 | Admin UI 手动触发单个 Batch 重新生成 |
| 题库不足 | 通过 Admin UI 选择单元 + 题型，追加生成 |

---

## 十、与每日包的衔接

当前 `CosmosQuestionService.GenerateDailyPackageAsync` 是 TODO 空包。
题库建成后，每日包逻辑：

```
1. 确定今日日期（中国时区）
2. 从 questions 容器查询该 textbookCode 下所有题目
3. 排除用户已完成的题目 ID（completions 容器）
4. 按以下规则抽取 15~20 题：
   ├── 词汇 × 4
   ├── 语法 × 3
   ├── 填空 × 2
   ├── 选择 × 2
   ├── 翻译 × 1
   ├── 听力 × 2
   ├── 口语 × 2
   ├── 阅读 × 1 篇
   └── 写作 × 1 (可选)
5. 优先选当前进度对应的单元（根据用户做题记录推断）
6. 写入 dailyPackages 容器
```

---

## 十一、API 调用成本估算

| 项目 | 数值 |
|------|------|
| 每 Batch 输入 | ~4000 tokens |
| 每 Batch 输出 | ~7000 tokens |
| 每单元 5 Batch | ~55K tokens |
| 每册 8 单元 | ~440K tokens |
| GPT-4o 价格 | $2.5/1M input + $10/1M output |
| **每册成本** | 输入 $0.40 + 输出 $2.80 ≈ **$3.20** |
| 21 个系列 × 平均 6 册 | ~126 册 × $3.20 ≈ **$400** (一次性) |

---

## 十二、实现步骤（建议顺序）

1. **[Service] `IQuestionGeneratorService`** — 出题服务接口
2. **[Service] `OpenAIQuestionGeneratorService`** — 5 个 Batch 的 prompt 模板 + GPT-4o 调用
3. **[Service] `QuestionValidatorService`** — 自动校验 + 过滤
4. **[Endpoints] Admin 出题 API** — 触发生成、查看进度、重新生成
5. **[Admin UI] 出题面板** — 选教材/单元/题型，一键生成，查看结果
6. **[Fix] `GenerateDailyPackageAsync`** — 从题库智能抽题组包

---

## 十三、总结

| 问题 | 答案 |
|------|------|
| 一个年级出多少题？ | 每单元 80~110 题 × 6~12 单元 = **每册 500~1300 题** |
| 是否尽可能多？ | 按题型合理分配即可，不需无限多。500+ 题足够一学期不重复 |
| Token 限制怎么办？ | 按 **单元 × 题型批次** 切片，每次 API 调用生成 20~30 题 |
| 切片粒度？ | **5 个 Batch / 单元**，每个 Batch 2~3 种相关题型 |
| 总共几次调用？ | 每册 ~40 次，耗时 ~5 分钟，成本 ~$3 |
