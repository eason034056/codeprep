# Mentor Notes: 元件分解、State 的歸屬、客戶端分組 — 從 COD-29 學 SwiftUI 設計

**Date**: 2026-04-06
**Topic**: 從「本週複習排程卡片」功能學 SwiftUI 元件拆分、狀態管理、資料分組、動畫設計
**Related**: `docs/decisions/008-weekly-review-schedule-card.md`, COD-29 plan

---

## Question Queue Check

你的 question_queue.md 目前沒有 pending 的問題。隨時丟問題進去！

---

## 背景

COD-29 是一個新 UI 功能：在 Review 頁面上方加入一個可收合的「本週複習排程」卡片。使用者可以一眼看到整週的複習量分佈，展開後按天查看題目並點擊導航到 ChatView。

這個功能雖然不改動任何 business logic，但它是一個 **學 SwiftUI 設計的完美教材**。為什麼？因為它涉及四個核心議題：

1. 什麼時候該把一個 View 拆成兩個元件？
2. 哪些狀態屬於 View，哪些屬於 ViewModel？
3. 資料在哪裡做轉換、分組？
4. 動畫怎麼做才自然？

我們一個一個來。

---

## 第一課：元件分解 — 為什麼要拆成兩個 View？

### Archon 的設計

看 `docs/decisions/008-weekly-review-schedule-card.md` 第 20-21 行，Archon 決定建兩個新元件：

```
- WeekDayIndicatorStrip — 7 天圓點指示器，顯示複習密度
- WeeklyScheduleCard — 可收合的卡片，包含每天的題目列表
```

### 為什麼不寫在一個 View 裡？

你可能會想：「反正 WeekDayIndicatorStrip 只在 WeeklyScheduleCard 裡面用，幹嘛拆出來？」

好問題。讓我們用一個你已經熟悉的例子來看。

打開 `ReviewQueueView.swift` 第 32-101 行。那個 `cardReviewView` function 有 70 行，裡面包含：
- Problem 資訊卡片（第 37-58 行）
- 統計數據（第 61-65 行）
- Open Problem Chat 按鈕（第 68-81 行）
- 評分提示文字（第 86-88 行）
- DifficultyRatingView（第 90-93 行）
- Progress 指示（第 96-99 行）

注意到了嗎？其中 `DifficultyRatingView` 被拆成了獨立元件（在 `Components/DifficultyRatingView.swift`），但 Problem 資訊卡片卻是直接寫在 `cardReviewView` 裡面。

**為什麼 DifficultyRatingView 值得拆、但 Problem 資訊卡片不用拆？**

### 判斷框架：什麼時候該拆元件？

想像你在整理房間。每個物品你都問自己：「這個東西需要自己的收納盒嗎？」

| 考量 | 拆成獨立元件 | 用 private func 就好 |
|------|------------|-------------------|
| **有自己的互動邏輯**（按鈕、手勢） | ✅ | |
| **有自己的內部狀態**（展開/收合、選取） | ✅ | |
| **可能在別的地方重用** | ✅ | |
| 只是 layout，沒有邏輯 | | ✅ |
| 只在一個地方用，而且很簡單 | | ✅ |
| **超過 30-40 行** | ✅ 考慮拆 | |

來看看 COD-29 的兩個新元件：

**WeekDayIndicatorStrip**：
- 有自己的 layout 邏輯（7 個圓點、顏色規則、VoiceOver）
- 有明確的 Input/Output 契約：`days: [(label: String, count: Int, isToday: Bool)]`
- 可以獨立預覽和測試
- **判決：✅ 拆**

**WeeklyScheduleCard**：
- 有自己的互動邏輯（展開/收合）
- 有自己的內部狀態（`@State isExpanded`）
- 有明確的 Input 契約（weekly groups 資料）
- 超過 30 行
- **判決：✅ 拆**

### 再看你現有的 code

打開 `DifficultyRatingView.swift`。這是一個很好的「拆對了」的例子：

```swift
// DifficultyRatingView.swift 第 3-5 行
struct DifficultyRatingView: View {
    let onRate: (Int) -> Void        // ← 清楚的「對外接口」
```

它接受一個 callback，內部處理自己的 layout 和 haptic feedback。`ReviewQueueView` 不需要知道「6 個按鈕怎麼排列、顏色怎麼配」的細節，它只需要說：「給我一個評分元件，使用者評分時告訴我。」

這就是 **Single Responsibility Principle（SRP）在 SwiftUI 中的實踐**。不是學術上的 SRP，是很實際的：**每個 View 只需要理解一件事**。

### 如果不拆會怎樣？

想像把 WeekDayIndicatorStrip 的邏輯直接寫在 WeeklyScheduleCard 裡面：

```swift
// ❌ 不拆的寫法 — WeeklyScheduleCard 會變成 150+ 行的怪物
struct WeeklyScheduleCard: View {
    @State private var isExpanded = false
    // ... 展開/收合邏輯
    // ... 標題列
    // ... 7 個圓點的 layout 邏輯
    // ... 圓點的顏色計算
    // ... 展開後的每天 section
    // ... 每題的 NavigationLink
    // ... VoiceOver labels
}
```

你打開這個檔案，光是理解「這個 View 在做什麼」就要花好幾分鐘。更糟糕的是，如果圓點的顏色規則改了，你要在 150 行裡面找到對的地方改。

拆開之後：
```swift
// ✅ 拆開的寫法
struct WeeklyScheduleCard: View {
    @State private var isExpanded = false
    
    var body: some View {
        VStack {
            headerRow           // 10 行
            WeekDayIndicatorStrip(days: weekDays)  // ← 一行搞定
            if isExpanded {
                expandedContent  // 20 行
            }
        }
    }
}
```

一目了然。你看到 `WeekDayIndicatorStrip(days: weekDays)` 就知道「哦，這裡放了一個 7 天的圓點」。細節？需要時再點進去看。

### 什麼時候不該拆？

看 `ReviewQueueView.swift` 第 104-111 行的 `statItem`：

```swift
private func statItem(value: String, label: String) -> some View {
    VStack(spacing: AppSpacing.xs) {
        Text(value)
            .font(AppFont.title3).fontWeight(.bold)
        Text(label)
            .font(AppFont.caption).foregroundStyle(.secondary)
    }
}
```

這只有 7 行，只在一個地方用，沒有互動邏輯，沒有內部狀態。用 `private func` 就完美了。如果為了「架構整潔」把它拆成 `StatItemView.swift`，那就是 **over-engineering** — 增加了檔案數量但沒有增加清晰度。

---

## 第二課：@State vs @Binding vs @Published — 狀態的歸屬權

### COD-29 的設計選擇

Plan 裡面說 `WeeklyScheduleCard` 用 `@State isExpanded` 來控制展開/收合。

**為什麼 `isExpanded` 用 @State 放在 View 裡，而不是用 @Published 放在 ViewModel 裡？**

這是 SwiftUI 開發中最常被問到的問題之一。答案很簡單但深刻：

### 狀態的兩個世界

想像你的 app 是一家餐廳：

- **Business state**（業務狀態）= 廚房裡的訂單系統
  - 今天有哪些複習卡到期？（`dueCards`）
  - 使用者評了幾分？（`quality`）
  - 本週有哪些卡片？（`weeklyGroups`）
  - 這些資料來自 database，影響 app 的核心邏輯

- **UI state**（介面狀態）= 餐廳大門是開的還是關的
  - 卡片展開了嗎？（`isExpanded`）
  - 要顯示 confetti 嗎？（`showConfetti`）
  - 這些只影響畫面呈現，跟業務邏輯無關

**規則：Business state 放 ViewModel，UI state 放 View。**

### 打開你的 code 看看

`ReviewQueueView.swift` 第 6 行：

```swift
@State private var showConfetti = false
```

`showConfetti` 就是 UI state。它控制「要不要播煙火動畫」，不影響任何業務邏輯。如果使用者切走再切回來，`showConfetti` 重置成 false 完全沒問題。

相比之下，`ReviewQueueViewModel.swift` 第 6-8 行：

```swift
@Published var dueCards: [SpacedRepetitionCard] = []
@Published var currentIndex: Int = 0
@Published var isComplete: Bool = false
```

這些是 business state。`dueCards` 來自 database，`currentIndex` 追蹤使用者的複習進度，`isComplete` 決定要不要顯示完成畫面。如果這些值莫名其妙被重置，使用者的複習進度就會丟失。

### COD-29 的 `isExpanded` 分析

`isExpanded` 只控制卡片是展開還是收合。它不影響：
- 哪些卡片要複習
- 複習的排程
- SM-2 的計算

所以用 `@State` 放在 `WeeklyScheduleCard` 裡面是正確的。

**如果放在 ViewModel 裡會怎樣？**

```swift
// ❌ 不好的做法 — 把 UI state 放在 ViewModel
class ReviewQueueViewModel: ObservableObject {
    @Published var dueCards: [SpacedRepetitionCard] = []
    @Published var currentIndex: Int = 0
    @Published var isComplete: Bool = false
    @Published var isWeeklyCardExpanded: Bool = false  // ← 不該在這裡！
}
```

問題：
1. **ViewModel 變胖了** — 每個 UI 小細節都塞進 ViewModel，它會越來越臃腫
2. **不必要的 re-render** — `isWeeklyCardExpanded` 改變時，所有觀察這個 ViewModel 的 View 都會重新計算 body（包括不需要更新的 flashcard 區域）
3. **測試變複雜** — 你要在 ViewModel 的 unit test 裡測「展開/收合」嗎？那根本不是業務邏輯
4. **可重用性下降** — 如果另一個畫面也想用 WeeklyScheduleCard，它自帶 @State 就能獨立運作

### 判斷框架

| 這個狀態... | 放哪裡 | 用什麼 |
|-----------|--------|-------|
| 來自 database 或 API | ViewModel | `@Published` |
| 影響 business logic | ViewModel | `@Published` |
| 只控制這個 View 的外觀 | View | `@State` |
| 需要跨 session 保存 | ViewModel 或 UserDefaults | `@Published` + persistence |
| 由 parent View 控制 | parent 傳入 | `@Binding` |
| 多個 View 共用 | ViewModel 或 Environment | `@Published` 或 `@EnvironmentObject` |

### @Binding 什麼時候出場？

看 `ReviewQueueView.swift` 第 24 行：

```swift
ConfettiView(isActive: $showConfetti)
```

`showConfetti` 的「主人」是 `ReviewQueueView`（用 `@State` 持有），但 `ConfettiView` 需要能夠把它改回 `false`（動畫播完後自動關掉）。這就是 `@Binding` 的場景：**你不擁有這個狀態，但你需要讀寫它。**

用日常生活比喻：
- `@State` = 你自己家的鑰匙，你全權控制
- `@Binding` = 你朋友家的鑰匙，他借給你用，但那是他的房子
- `@Published` = 公司的門禁卡，所有員工都能用，但由管理員（ViewModel）管理

### COD-29 裡 @Binding 會用在哪？

在 `WeeklyScheduleCard` 裡：

```swift
struct WeeklyScheduleCard: View {
    // 這些是 parent 傳進來的資料（read-only，用普通 property）
    let weeklyGroups: [(date: Date, cards: [(SpacedRepetitionCard, Problem)])]
    let weeklyTotalCount: Int
    
    // 這是自己的 UI state
    @State private var isExpanded = false
    
    // ...
}
```

注意 `weeklyGroups` 和 `weeklyTotalCount` 不用 `@Binding` — 它們是唯讀的。`WeeklyScheduleCard` 不需要改變這些資料，只是顯示它們。

**規則：只有當子元件需要 *修改* parent 的值時，才用 @Binding。如果只是 *讀取*，用普通 property 就好。**

不該亂用 @Binding 的原因：
- @Binding 建立了雙向通道，增加了複雜度
- 讓讀者以為「這個子元件會改變這個值」
- 不必要的 @Binding 會讓 SwiftUI 的 diff 算法多做不必要的工作

---

## 第三課：客戶端資料分組 — 在哪裡做、怎麼做？

### 設計決策：為什麼在 ViewModel 分組，不加新的 repo method？

打開 `docs/decisions/008-weekly-review-schedule-card.md` 第 29 行：

> Client-side grouping over new DB query: The number of weekly cards is small (typically <20). `getDueCards(before:)` + `Dictionary(grouping:)` is simpler than adding a new repo method.

**為什麼不在 Repository 加一個 `getWeeklyGroupedCards()` method？**

想像你開了一家小圖書館（你的 app），你有一個圖書管理員（Repository）負責：
- 給我今天到期的書（`getDueCards(before: Date())`）
- 給我某本書（`getCard(for: problemId)`）

現在你想要「按天分組」看本週有哪些書到期。你有兩個選擇：

**選項 A：訓練圖書管理員一個新技能**
```swift
// ❌ 在 Repository 加新 method
func getWeeklyGroupedCards() -> [(Date, [SpacedRepetitionCard])] {
    let cards = getDueCards(before: endOfWeek)
    return Dictionary(grouping: cards, by: { Calendar.current.startOfDay(for: $0.nextReviewDate) })
        .sorted(by: { $0.key < $1.key })
        .map { ($0.key, $0.value) }
}
```

**選項 B：自己拿到書之後整理**
```swift
// ✅ 在 ViewModel 做分組
func loadWeeklyCards() {
    let weekCards = progressRepo.getDueCards(before: endOfWeek)
    // 在 ViewModel 裡分組、過濾、排序
}
```

Archon 選了 B，因為：

1. **Repository 的職責是存取資料**，不是做 UI-specific 的轉換。「按天分組」是為了畫面顯示而做的，換個 UI 設計可能就不需要了
2. **資料量很小** — 一週最多 20 張卡，不值得為了 20 筆資料加一個 DB query
3. **減少 Repository 的 API surface** — Repository 的 method 越少，越容易理解和維護

**判斷框架：分組/轉換邏輯放哪裡？**

| 情境 | 放 Repository | 放 ViewModel |
|------|-------------|-------------|
| 需要 DB-level 的 aggregate（例如 COUNT、SUM） | ✅ | |
| 資料量大，需要 pagination | ✅ | |
| 只是把已有資料重新排列 | | ✅ |
| 轉換邏輯跟 UI 設計有關 | | ✅ |
| 多個 ViewModel 都需要同樣的轉換 | ✅ 考慮 | |

### Dictionary(grouping:by:) — 超好用的標準庫寶藏

這是 Swift 標準庫裡最被低估的工具之一。看看 COD-29 plan 裡的寫法：

```swift
let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: Date())!
let weekCards = progressRepo.getDueCards(before: weekInterval.end)
let tomorrow = Calendar.current.date(byAdding: .day, value: 1, 
    to: Calendar.current.startOfDay(for: Date()))!
let futureCards = weekCards.filter { $0.nextReviewDate >= tomorrow }
```

一步一步拆解：

**Step 1：算出「本週」的範圍**
```swift
let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: Date())!
// weekInterval.start = 本週日（或本週一，取決於 locale）00:00:00
// weekInterval.end   = 下週日（或下週一）00:00:00
```

`Calendar.dateInterval(of:for:)` 是 iOS Calendar API 的神器。它幫你算出「包含某個日期的那個時間單位的起止」。

```swift
// 你可以用它算很多東西：
Calendar.current.dateInterval(of: .weekOfYear, for: someDate)  // 那一週
Calendar.current.dateInterval(of: .month, for: someDate)       // 那一個月
Calendar.current.dateInterval(of: .day, for: someDate)         // 那一天
```

**Step 2：只留未來的卡片（排除今天的）**
```swift
let tomorrow = Calendar.current.date(byAdding: .day, value: 1, 
    to: Calendar.current.startOfDay(for: Date()))!
let futureCards = weekCards.filter { $0.nextReviewDate >= tomorrow }
```

為什麼排除今天？因為今天到期的卡片已經顯示在下面的 flashcard 流程裡了。如果週摘要也顯示今天的，使用者會看到同一批卡片出現兩次。

**Step 3：按天分組**
```swift
let grouped = Dictionary(grouping: futureCards) { card in
    Calendar.current.startOfDay(for: card.nextReviewDate)
}
// grouped 的型別是 [Date: [SpacedRepetitionCard]]
// key = 每天的 00:00:00
// value = 那天到期的卡片們
```

`Dictionary(grouping:by:)` 接受一個 collection 和一個 closure，closure 回傳的值就是分組的 key。

**你可以把它想成「把一堆球按顏色分到不同的桶子裡」。**

```swift
// 生活化的例子
let fruits = ["apple", "banana", "avocado", "blueberry", "cherry"]
let grouped = Dictionary(grouping: fruits) { $0.first! }
// Result:
// "a": ["apple", "avocado"]
// "b": ["banana", "blueberry"]
// "c": ["cherry"]
```

### Calendar.startOfDay 的重要性

為什麼用 `startOfDay(for:)` 而不是直接用 `nextReviewDate` 分組？

```swift
// 卡片的 nextReviewDate 可能是：
// Card A: 2026-04-07 03:45:12
// Card B: 2026-04-07 18:22:33
// Card C: 2026-04-08 09:00:00

// 如果直接用 nextReviewDate 分組：
// "2026-04-07 03:45:12": [Card A]    ← 分成了兩組！
// "2026-04-07 18:22:33": [Card B]    ← 但它們是同一天的
// "2026-04-08 09:00:00": [Card C]

// 用 startOfDay 分組：
// "2026-04-07 00:00:00": [Card A, Card B]  ← 正確合併
// "2026-04-08 00:00:00": [Card C]
```

`startOfDay(for:)` 把任何時間點「正規化」到那天的午夜 00:00:00，這樣同一天的卡片就會落在同一個 group 裡。

**如果不用 startOfDay？** 每張卡片都會變成自己一個 group，因為它們的秒數不同。你在畫面上會看到：
- 4/7 03:45 — 1 review
- 4/7 18:22 — 1 review

而不是你期望的：
- 4/7 — 2 reviews

---

## 第四課：動畫 — Spring 為什麼比 easeInOut 好？

### COD-29 的動畫設計

Plan 說用 `withAnimation(AppAnimation.springDefault)` 做展開/收合。

打開 `AnimationTokens.swift` 第 4 行：

```swift
static let springDefault: Animation = .spring(response: 0.5, dampingFraction: 0.7)
```

### 兩個參數代表什麼？

**response = 0.5**：動畫的「速度」。數字越小越快。0.5 秒是一個舒適的中速。

**dampingFraction = 0.7**：阻尼比。想像你用力壓一個彈簧然後放手：
- `dampingFraction = 0` → 永遠不停地彈
- `dampingFraction = 0.5` → 彈幾下才停（bouncy，有彈性）
- `dampingFraction = 0.7` → 輕微過衝然後停（gentle overshoot）
- `dampingFraction = 1.0` → 完全不彈，直接到位（critically damped）

看看 CodePrep 裡的三個 spring：

```swift
static let springDefault: Animation = .spring(response: 0.5, dampingFraction: 0.7)   // 日常用
static let springBouncy:  Animation = .spring(response: 0.4, dampingFraction: 0.6)   // 按鈕、有趣的互動
static let springGentle:  Animation = .spring(response: 0.6, dampingFraction: 0.8)   // 大區域的出現/消失
```

### 隱式動畫 vs 顯式動畫

SwiftUI 有兩種加動畫的方式：

**隱式動畫（Implicit）**— 在 View 上加 `.animation()` modifier

```swift
// 隱式：「這個 View 的任何變化都要動畫」
Text("Hello")
    .opacity(isVisible ? 1 : 0)
    .animation(AppAnimation.springDefault, value: isVisible)
```

**顯式動畫（Explicit）**— 用 `withAnimation {}` 包住狀態改變

```swift
// 顯式：「改這個狀態的時候要動畫」
Button("Toggle") {
    withAnimation(AppAnimation.springDefault) {
        isExpanded.toggle()
    }
}
```

**COD-29 用顯式動畫，為什麼？**

1. **精確控制** — 你明確說「點擊按鈕展開卡片」這個動作需要動畫。不會影響到其他不相關的狀態變化
2. **安全** — 隱式動畫有時會「傳染」到子元件，造成不預期的動畫效果
3. **清楚** — 讀 code 的人看到 `withAnimation` 就知道「這裡有動畫」

**判斷框架：**

| 情境 | 用哪個 |
|------|-------|
| 單一使用者互動觸發（按鈕點擊、滑動） | `withAnimation` （顯式） |
| 某個值改變時永遠要動畫（例如進度條） | `.animation()` （隱式） |
| 不確定 | 先用顯式，比較安全 |

### 為什麼 Spring 而不是 easeInOut？

```swift
// easeInOut — 固定時間的「加速→減速」曲線
static let fadeMedium: Animation = .easeOut(duration: 0.35)

// spring — 物理模擬的「彈簧」曲線  
static let springDefault: Animation = .spring(response: 0.5, dampingFraction: 0.7)
```

easeInOut 像電梯：起步時加速，到站前減速，很機械。
spring 像人走路：有慣性、有回彈，很自然。

Apple 的 Human Interface Guidelines 建議大部分 UI 動畫用 spring，原因：

1. **自然** — 現實世界裡沒有東西是 easeInOut 移動的。門、抽屜、球，都是 spring-like 的運動
2. **可中斷** — spring 動畫可以被打斷後自然過渡到新狀態。easeInOut 被打斷會跳躍
3. **不需要指定 duration** — spring 自動算出合適的時長，easeInOut 的 duration 很容易設錯

**什麼時候用 easeInOut？**

- 淡入淡出（opacity 變化）— spring 的過衝會讓 opacity 超過 1.0，看起來會閃
- 進度條（固定時長的填充動畫）
- 精確的時間控制需求

所以 CodePrep 的 `AnimationTokens.swift` 裡，位移/大小相關用 spring，透明度相關用 ease：

```swift
// 位移/大小 → spring
static let springDefault: Animation = .spring(response: 0.5, dampingFraction: 0.7)

// 透明度 → ease
static let fadeQuick: Animation = .easeOut(duration: 0.2)
static let fadeMedium: Animation = .easeOut(duration: 0.35)
```

### Accessibility：ReduceMotionSafe

打開 `AnimationTokens.swift` 第 15-30 行：

```swift
struct ReduceMotionSafe: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let reducedAnimation: Animation
    
    func body(content: Content) -> some View {
        content.transaction { transaction in
            transaction.animation = reduceMotion ? reducedAnimation : animation
        }
    }
}
```

這是 CodePrep 已經有的 accessibility 支持。如果使用者在 iOS 設定裡打開了「減少動態效果」，所有的 spring 動畫都會降級成快速的 easeOut。

**這不是可選的** — Apple 的 App Store Review 會檢查你有沒有尊重 `reduceMotion`。如果有使用者因為前庭功能障礙打開了這個設定，你的 app 還在播彈跳動畫，那是 accessibility violation。

COD-29 應該用 `safeAnimation()` 或 `withAnimation` + check `reduceMotion`。

---

## 今天的重點回顧

### 元件拆分
- **有自己的互動/狀態/可重用 → 拆成獨立元件**
- **純 layout、只用一次 → private func 就好**
- 不要為了「整潔」而拆，要為了「理解」而拆

### 狀態歸屬
- **Business state → ViewModel 的 @Published**
- **UI state → View 的 @State**
- **子元件需要修改 parent 的值 → @Binding**
- **子元件只需要讀 → 普通 property**

### 資料分組
- **少量資料的 UI-specific 轉換 → ViewModel**
- **大量資料的 aggregate → Repository**
- **`Dictionary(grouping:by:)` 是你最好的朋友**
- **日期分組一定要用 `Calendar.startOfDay(for:)`**

### 動畫
- **位移/大小變化 → spring**
- **透明度變化 → ease**
- **使用者互動 → 顯式 `withAnimation`**
- **持續性的變化 → 隱式 `.animation()`**
- **永遠尊重 `reduceMotion`**

---

## 學習地圖 (Learning Map)

| # | 概念 | 一句話解釋 | 延伸關鍵字 |
|---|------|-----------|-----------|
| 1 | Single Responsibility Principle | 每個元件只負責一件事 | SOLID, Component Decomposition |
| 2 | @State | View 擁有的本地狀態，值改變時 View 重新渲染 | Property Wrapper, Source of Truth |
| 3 | @Published | ViewModel 裡的可觀察屬性，值改變時通知所有觀察者 | ObservableObject, Combine |
| 4 | @Binding | 對別人擁有的 @State 的讀寫參考 | Two-way binding, $ prefix |
| 5 | Dictionary(grouping:by:) | 把 collection 按某個 key 分組成字典 | Swift Standard Library, Functional |
| 6 | Calendar.dateInterval | 算出包含某日期的時間區間（週、月、年） | DateComponents, Locale-aware |
| 7 | Calendar.startOfDay | 把任意時間正規化到午夜 00:00:00 | Date normalization, Time zones |
| 8 | Spring Animation | 基於物理彈簧模型的動畫，自然且可中斷 | response, dampingFraction |
| 9 | 隱式 vs 顯式動畫 | `.animation()` 監聽值變化 vs `withAnimation` 包住狀態改變 | Transaction, Animation scope |
| 10 | Reduce Motion | iOS 無障礙設定，使用者可要求減少動態效果 | Accessibility, `@Environment` |
| 11 | Private func vs 獨立元件 | 小 layout 用 func，有狀態/互動的用 struct | View Composition, Reusability |
| 12 | UI state vs Business state | 介面狀態屬於 View，業務狀態屬於 ViewModel | MVVM, State ownership |

## 推薦資源

1. **WWDC 2023 — "Demystify SwiftUI performance"** — 理解 @State vs @Published 對 re-render 的影響
2. **WWDC 2023 — "Wind your way through advanced animations in SwiftUI"** — spring 動畫的深度解析
3. **WWDC 2019 — "Building Custom Views with SwiftUI"** — 理解 View composition 的基本原則
4. **Apple HIG — Motion** — 什麼時候用什麼動畫的官方指南
5. **Point-Free — "SwiftUI State Management"** 系列 — 最深入的 @State/@Binding 教學
6. **Swift by Sundell — "The power of key paths in Swift"** — 理解 `Dictionary(grouping:)` 背後的 functional programming 概念

---

## 延伸思考

1. **回去看你的 `ReviewQueueView.swift`**：`cardReviewView` 裡面的 Problem 資訊卡片（第 37-58 行）值得拆成獨立元件嗎？用今天學的判斷框架分析看看。

2. **@State 的生命週期**：`@State private var showConfetti = false` 在什麼時候會被重置？如果使用者切到另一個 tab 再切回來，`showConfetti` 會變回 false 嗎？為什麼？（提示：SwiftUI 的 View identity 和 structural identity）

3. **如果 CodePrep 未來要加「月度複習日曆」**：你會用 `Dictionary(grouping:)` 嗎？還是你會在 Repository 加新 method？用什麼來判斷？

4. **動畫的「可中斷性」**：如果使用者快速連點展開/收合按鈕 10 次，spring 動畫和 easeInOut 動畫各自會發生什麼？哪個的使用者體驗更好？

---

*Written by Sage (Mentor) — your iOS engineering buddy* 🍵
