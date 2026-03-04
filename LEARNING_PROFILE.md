# 学习设置统一定义

> 用户选择年级 → 教材 → 学期 → 单元。每次登录确认一次。
> 前后端使用完全一致的 code。

---

## 1. 用户 Profile 字段

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `grade` | `string` | 年级 code | `"junior1"` |
| `publisher` | `string?` | 教材出版社 code，仅学制年级需要 | `"pep"` |
| `semester` | `string?` | 学期，仅学制年级需要 | `"a"` |
| `currentUnit` | `int?` | 当前学到第几单元（1-based） | `3` |

> 替代旧字段：~~`Level`~~, ~~`TextbookCode`~~, ~~`Semester`~~

---

## 2. Grade（年级）

### 2.1 学制年级（有教材 + 学期）

| code | 显示名 | gradeNumber |
|------|--------|-------------|
| `primary1` | 小学一年级 | 1 |
| `primary2` | 小学二年级 | 2 |
| `primary3` | 小学三年级 | 3 |
| `primary4` | 小学四年级 | 4 |
| `primary5` | 小学五年级 | 5 |
| `primary6` | 小学六年级 | 6 |
| `junior1` | 初一 | 7 |
| `junior2` | 初二 | 8 |
| `junior3` | 初三 | 9 |
| `senior1` | 高一 | 10 |
| `senior2` | 高二 | 11 |
| `senior3` | 高三 | 12 |

### 2.2 非学制年级（无教材/学期，直接用 grade 当 textbookCode）

| code | 显示名 |
|------|--------|
| `cet4` | 四级 |
| `cet6` | 六级 |
| `graduate` | 考研 |
| `daily` | 日常 |
| `ket` | KET |
| `pet` | PET |
| `fce` | FCE |
| `cae` | CAE |
| `cpe` | CPE |
| `cefrA1` | CEFR A1 |
| `cefrA2` | CEFR A2 |
| `cefrB1` | CEFR B1 |
| `cefrB2` | CEFR B2 |
| `cefrC1` | CEFR C1 |
| `cefrC2` | CEFR C2 |
| `ielts` | IELTS |
| `toefl` | TOEFL |

---

## 3. Publisher（教材出版社）

仅学制年级需要选择。

| code | 显示名 | 适用范围 |
|------|--------|---------|
| `pep` | 人教版 | 小学 / 初中 / 高中 |
| `fltrp` | 外研版 | 小学 / 初中 / 高中 |
| `yilin` | 译林版 | 小学 / 初中 / 高中 |
| `hujiao` | 沪教版 | 小学 / 初中 / 高中 |

各年级段可用出版社：

| 年级段 | 可选出版社 | 默认推荐 |
|--------|-----------|---------|
| 小学 (primary1-6) | pep, fltrp, yilin, hujiao | pep |
| 初中 (junior1-3) | pep, fltrp, yilin, hujiao | pep |
| 高中 (senior1-3) | pep, fltrp, yilin, hujiao | pep |

---

## 4. Semester（学期）

仅学制年级需要选择。

| code | 显示名 |
|------|--------|
| `a` | 上学期 |
| `b` | 下学期 |

---

## 5. textbookCode 生成规则

`textbookCode` 用于查询题库（questions 容器的 partition key）。

### 学制年级

```
{publisher}{Stage}-{gradeNumber}{semester}
```

其中 `Stage` 由年级段决定：

| 年级范围 | Stage 前缀 |
|---------|-----------|
| primary1-6 | `primary` |
| junior1-3 | `junior` |
| senior1-3 | `senior` |

完整映射表：

| grade | publisher | semester | → textbookCode |
|-------|-----------|----------|----------------|
| primary1 | pep | a | `primaryPEP-1a` |
| primary1 | pep | b | `primaryPEP-1b` |
| primary3 | fltrp | a | `primaryFLTRP-3a` |
| junior1 | pep | a | `juniorPEP-7a` |
| junior2 | yilin | b | `juniorYilin-8b` |
| senior3 | hujiao | b | `seniorHujiao-12b` |

**命名规则**：`{stage}{Publisher首字母大写}-{gradeNumber}{semester}`

```
Publisher code → textbookCode 前缀映射:
  pep    → PEP
  fltrp  → FLTRP
  yilin  → Yilin
  hujiao → Hujiao
```

### 非学制年级

```
textbookCode = grade
```

即：`"cet4"`, `"ielts"`, `"cefrB1"` 等直接作为 textbookCode。

---

## 6. Unit（单元）

`currentUnit` 记录用户当前学到的单元号（1-based）。

每本教材的总单元数在 iOS/后端共享的配置中查表：

```
func totalUnits(textbookCode: String) -> Int
```

> **V1 暂不实现单元选择 UI**，先默认 `currentUnit = 1`。
> 后续迭代：显示单元列表让用户选择当前进度。

---

## 7. 数据存储

### 7.1 后端 Cosmos DB — `userProfiles` 容器

```csharp
public class HBUserProfile
{
    public string Id { get; set; }           // = userId
    public string? DisplayName { get; set; }
    public string? Email { get; set; }
    public bool HasEmailIdentity { get; set; }

    // ── 学习设置 (新) ──
    public string? Grade { get; set; }       // "junior1"
    public string? Publisher { get; set; }    // "pep" (学制年级) / null (非学制)
    public string? Semester { get; set; }     // "a"/"b" (学制年级) / null
    public int? CurrentUnit { get; set; }     // 1-based
}
```

API DTO:

```csharp
public record UserProfile(
    string Id,
    string? DisplayName,
    string? Email,
    bool HasEmailIdentity,
    string? Grade = null,
    string? Publisher = null,
    string? Semester = null,
    int? CurrentUnit = null);

public record UpdateProfileRequest(
    string? Grade = null,
    string? Publisher = null,
    string? Semester = null,
    int? CurrentUnit = null,
    string? DisplayName = null);
```

### 7.2 iOS 本地 — `UserState`（JSON file）

```swift
struct UserState: Codable {
    var isOnboardingCompleted: Bool = false

    // ── 学习设置 ──
    var grade: String?           // "junior1"
    var publisher: String?       // "pep"
    var semester: String?        // "a"
    var currentUnit: Int?        // 1

    // ── 其他 ──
    var createdAt: Date = Date()
    var preferences: LearningPreferences = LearningPreferences()
}
```

### 7.3 iOS `AuthUserProfile`（API 返回）

```swift
struct AuthUserProfile: Codable {
    let id: String
    let displayName: String?
    let email: String?
    let hasEmailIdentity: Bool
    let grade: String?
    let publisher: String?
    let semester: String?
    let currentUnit: Int?
}
```

---

## 8. textbookCode 计算（前后端通用逻辑）

### Swift

```swift
extension UserState {
    /// 根据 grade + publisher + semester 生成 textbookCode
    var textbookCode: String? {
        guard let grade = grade else { return nil }
        guard let gradeEnum = Grade(rawValue: grade) else { return grade }

        // 非学制年级 → grade 即 textbookCode
        guard gradeEnum.isSchoolGrade else { return grade }

        // 学制年级 → 需要 publisher + semester
        guard let publisher = publisher, let semester = semester else { return nil }
        let stage = gradeEnum.stage           // "primary" / "junior" / "senior"
        let pubName = Publisher.displayCode(publisher)  // "PEP" / "FLTRP" / "Yilin" / "Hujiao"
        let gradeNum = gradeEnum.gradeNumber!
        return "\(stage)\(pubName)-\(gradeNum)\(semester)"
    }
}
```

### C#

```csharp
public static string? BuildTextbookCode(string? grade, string? publisher, string? semester)
{
    if (grade is null) return null;
    if (!GradeInfo.TryGet(grade, out var info)) return grade;
    if (!info.IsSchoolGrade) return grade;
    if (publisher is null || semester is null) return null;

    var pubDisplay = publisher switch {
        "pep" => "PEP", "fltrp" => "FLTRP",
        "yilin" => "Yilin", "hujiao" => "Hujiao",
        _ => publisher
    };
    return $"{info.Stage}{pubDisplay}-{info.GradeNumber}{semester}";
}
```

---

## 9. 用户流程

### 首次使用（新设备用户）
1. 选择年级 → 2. 选择教材（学制年级） → 3. 选择学期 → ✅ 进入主界面

### 邮箱登录（已有云端数据）
1. 登录 → 2. 从云端恢复 grade/publisher/semester/currentUnit → 3. **确认/修改**当前设置 → ✅ 进入主界面

### 每次 session（可选，V2）
- 展示当前设置卡片，用户可快速修改学期/单元

---

## 10. 需要变更的文件

### 后端 (C#)

| 文件 | 变更 |
|------|------|
| `AuthModels.cs` | `HBUserProfile`: Level/TextbookCode/Semester → Grade/Publisher/Semester/CurrentUnit |
| `AuthModels.cs` | `UserProfile` DTO: 同上 |
| `AuthModels.cs` | `UpdateProfileRequest` DTO: 同上 |
| `AuthService.cs` | `UpdateProfileAsync`: 更新字段映射 |
| `AuthService.cs` | `ToProfile()`: 更新映射 |
| `AuthService.cs` | 新增 `BuildTextbookCode()` 静态方法 |
| `CosmosQuestionService.cs` | `textbookCode` 参数不变，但调用方需用新函数生成 |
| `ApiEndpoints.cs` | 练习题 API 仍接受 `textbookCode` 查询参数（不变） |

### iOS (Swift)

| 文件 | 变更 |
|------|------|
| `OnboardingModels.swift` | 删除 `TextbookOption` 大 enum，改为 `Grade` + `Publisher` 小 enum |
| `OnboardingModels.swift` | `UserState`: selectedLevel/selectedTextbook/selectedSemester → grade/publisher/semester/currentUnit |
| `UserStateStore.swift` | 所有 `selectedLevel`/`selectedTextbook` 引用 → 新字段 |
| `UserStateStore.swift` | `restoreFromCloudProfile()`: 读取新字段 |
| `UserStateStore.swift` | `currentTextbookCode` → 用新 `textbookCode` 计算属性 |
| `AuthManager.swift` | `AuthUserProfile`: 字段改名 |
| `AuthManager.swift` | `updateProfile()`: 发送新字段 |
| `APIService.swift` | `updateProfile()`: Body 字段改名 |
| `RootView.swift` | `pushLocalProfileToCloud()`: 用新字段 |
| `OnboardingFlowView.swift` | 简化流程：年级 → 教材 → 学期 |
| `OnboardingFlowView.swift` | `createUserAndSyncProfile()`: 用新字段 |
| 所有 ViewModel | `textbookCode` 引用改为从 `UserState.textbookCode` 计算 |

---

## 11. 迁移策略

旧数据兼容：
- 后端：两个字段并存一段时间。读取时优先用新字段 `Grade`，如果为空回退解析旧 `Level` 字段。
- iOS：`UserState` 加 `migration()` 方法，从旧 `selectedLevel`/`selectedTextbook`/`selectedSemester` 迁移到新字段。
- 题库 `questions` 容器：**不需要迁移**，textbookCode 格式不变（如 `juniorPEP-7a`），只是生成方式从 iOS 端变更。
