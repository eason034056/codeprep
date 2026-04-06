# Mentor Notes: 「兩條路徑」Bug 與 Code Review 的學問

**Date**: 2026-04-06
**Topic**: 從 COD-24 學「code path divergence」、從 COD-21 Review 學測試策略與 Combine 陷阱
**Related**: `docs/decisions/007-spaced-repetition-card-creation-bug.md`, COD-21 review summary

---

## Question Queue Check

你的 question_queue.md 目前沒有 pending 的問題。隨時丟問題進去！

---

## 今天的兩個主題

上次我們從 COD-21（登入後進度歸零）學了 DI 快取失效。今天有兩個值得學的東西：

1. **COD-24**：一個全新的 bug — SpacedRepetition 卡片從來沒被建立過
2. **COD-21 的 Code Review**：Lens 的 review 裡有幾個 iOS 開發的重要知識點

這兩個主題看似無關，但背後有一個共同的教訓：**系統越長越大，各個部分之間的「隱含契約」就越容易被打破。**

---

## 第一課：兩條路做同一件事 — 最經典的 Bug 來源

### 發生了什麼？

使用者透過 Chat 跟 AI 對話，用 UMPIRE 方法解了 5 題。回到 Review Queue 一看 — 空的。零張卡片。Spaced Repetition 系統形同虛設。

### 打開你的程式碼看看

先看 **正確的那條路**。打開 `UpdateSpacedRepetitionUseCase.swift` 第 13-16 行：

```swift
func execute(problemId: Int, qualityRating: Int) {
    var card = progressRepo.getOrCreateCard(for: problemId)  // 1. 建卡
    card = sm2.update(card: card, quality: qualityRating)     // 2. 用 SM-2 算法更新
    progressRepo.saveCard(card)                               // 3. 存起來
    
    progressRepo.updateProgress(problemId: problemId) { progress in
        progress.attemptCount += 1
        progress.lastAttemptDate = Date()
        // ... 設定 status
    }
}
```

這條路由 `ReviewQueueViewModel.rateCard()` 觸發。使用者在 Review Queue 裡評分一張卡片 → 呼叫這個 UseCase → 卡片被建立、更新、儲存。完美。

再看 **壞掉的那條路**。打開 `EvaluateUserApproachUseCase.swift` 第 34-50 行：

```swift
func markUMPIRESolutionDelivered(problemId: Int) {
    progressRepo.updateProgress(problemId: problemId) { progress in
        progress.lastAttemptDate = Date()
        progress.umpireSolutionUnlocked = true
        if progress.status == .unseen || progress.status == .attempted {
            progress.status = .solvedWithHelp
        }
    }
    
    // 標記 DailyChallenge 完成
    // ... (省略)
    
    NotificationCenter.default.post(name: NSNotification.Name("ProgressUpdated"), object: nil)
}
```

看到差別了嗎？

- `UpdateSpacedRepetitionUseCase`: getOrCreateCard → sm2.update → saveCard → updateProgress
- `EvaluateUserApproachUseCase`: updateProgress → ...就沒了

**缺了三行**。沒有 `getOrCreateCard`，沒有 `sm2.update`，沒有 `saveCard`。

### 為什麼這種 bug 會發生？

想像你跟朋友開了一家餐廳。你們有兩個入口：前門（Review Queue）和後門（Chat/UMPIRE）。

前門有完整的 SOP：客人進來 → 登記 → 帶位 → 點菜。
後門是後來加的，當初只想著「讓客人能進來」，SOP 只寫了「帶位」，忘了寫「登記」。

結果？從後門進來的客人，你的訂位系統裡完全沒有紀錄。

在軟體工程裡，這叫做 **code path divergence**（程式碼路徑分歧）。兩條路徑做「概念上相同的事」（標記問題已解決），但實作不一致。

### 為什麼這種 bug 特別惡意？

1. **不會 crash** — 程式跑得好好的
2. **部分功能正常** — Progress 有更新、streak 有算、DailyChallenge 有標記完成
3. **只有下游系統壞掉** — Review Queue 空空的，因為卡片從來沒建
4. **很難被發現** — 除非有人同時用 Chat 解題 *然後* 去 Review Queue 看

這就像你車子的儀表板顯示油箱滿的，但實際上油已經漏了。儀表板沒壞，是感測器接錯了。

### 怎麼預防？

**方法 1：畫 flow diagram，對照所有路徑**

```
解題完成 → 應該發生什麼？
  ✅ progress.status 更新
  ✅ lastAttemptDate 設定
  ✅ DailyChallenge 標記完成
  ✅ SpacedRepetitionCard 建立    ← Chat/UMPIRE 漏了這個！
  ✅ SM-2 算法計算下次複習時間    ← 也漏了！
```

**方法 2：寫一個 checklist 式的 test**

```swift
// "解完一題之後，這些事都要發生"
func test_afterSolvingProblem_allSideEffectsOccur() {
    solveProblem(via: .chat)
    
    XCTAssertNotNil(progressRepo.getCard(for: problemId))  // 卡片要建
    XCTAssertEqual(progress.status, .solvedWithHelp)         // 狀態要對
    XCTAssertNotNil(progress.lastAttemptDate)                 // 日期要設
    // ...
}
```

**方法 3：Single Source of Truth**

長遠來看，最好的方案是讓「解題完成」只有一個入口點：

```swift
// 理想狀態（未來重構方向）
class MarkProblemSolvedUseCase {
    func execute(problemId: Int, solveType: SolveType) {
        // 所有該做的事都在這裡
        updateProgress(...)
        createOrUpdateCard(...)
        markDailyChallenge(...)
    }
}
```

但 Archon 正確地選了不這樣做 — 現階段這是 over-engineering。因為兩個 UseCase 的 context 不同（Review Queue 是「複習」，Chat 是「首次解題」），硬合在一起可能造成更多問題。

**判斷框架：什麼時候該合併路徑，什麼時候該保持分開？**

| 考量 | 合併 | 分開 |
|------|-----|------|
| 共享邏輯超過 5-10 行 | ✅ | |
| 兩邊的 context 差很多 | | ✅ |
| 共享邏輯只有 2-3 行 | | ✅ 複製比抽象好 |
| 經常一起改 | ✅ | |
| Bug 風險（漏改一邊）高 | ✅ | |

COD-24 的修法是對的：直接在 `markUMPIRESolutionDelivered()` 裡加 3 行建卡邏輯。不抽 service，不搞共享，因為 context 不同、共享邏輯只有 3 行。

---

## 第二課：從 Lens 的 Code Review 學到的三件事

打開 `docs/review-summaries/review_summary_COD-21.md` 跟著看。

### 2-1. 測試策略：當你沒辦法 mock 的時候

Lens 在 review 裡提到：

> Since `AuthManager` is a concrete `final class` (not protocol-based), directly testing the auth listener wiring isn't possible.

什麼意思？

在 CodePrep 裡，`AuthManager` 是一個 `final class`，而且沒有對應的 protocol。這代表你沒辦法寫一個 `MockAuthManager` 來替換它。

**為什麼 protocol 可以讓你 mock？**

想像你要測試一家餐廳（ViewModel）的服務品質。如果餐廳合約上寫死「只能用張三當服務生」（concrete class），你就沒辦法找替身來測試。但如果合約寫的是「需要一個會端盤子的人」（protocol），你就能派任何人上場。

```swift
// 沒辦法 mock 的寫法
class DIContainer {
    let authManager = AuthManager()  // 綁死了
}

// 可以 mock 的寫法
protocol AuthManagerProtocol {
    var currentUser: Published<User?>.Publisher { get }
}

class DIContainer {
    let authManager: AuthManagerProtocol  // 可以替換
}
```

**那測試怎麼辦？**

Forge（Engineer）選了一個務實的方法：**測試 observable effects（可觀察的效果）**，而不是測試 wiring（接線）。

```swift
// 不測「auth 變了 → ViewModel 有沒有被重建」（因為沒辦法模擬 auth 變化）
// 改測「新 ViewModel + 新 repo → 結果對不對」

func test_freshHomeViewModel_showsCorrectProgress() {
    // 直接建一個有資料的 repo
    let repo = MockProgressRepository()
    repo.addProgress(streak: 5, xp: 100)
    
    // 建 ViewModel
    let vm = HomeViewModel(progressRepo: repo, ...)
    
    // 驗證結果
    XCTAssertEqual(vm.streak, 5)
    XCTAssertEqual(vm.xp, 100)
}
```

**教訓**：當你沒辦法直接測試 A → B 的連線，就分開測 A 和 B。確保 A 的 output 是對的，確保 B 拿到正確 input 時行為是對的。

**判斷框架：什麼時候該加 protocol 來 mock？**

| 情境 | 建議 |
|------|------|
| 這個 class 被很多地方依賴 | ✅ 加 protocol |
| 只有 1-2 個使用者，而且不太會變 | 先不用 |
| 測試需要模擬不同狀態（成功/失敗/超時） | ✅ 加 protocol |
| 加了 protocol 之後還要改很多地方 | 衡量 ROI |

Lens 建議未來可以提取 `AuthManagerProtocol` — 這是 CodePrep 目前最大的測試缺口。

### 2-2. Combine、@MainActor 與 Thread Safety 的微妙關係

Lens 指出了一個 **iOS-GOTCHA**（iOS 陷阱），打開你的 `DIContainer.swift` 第 102-121 行：

```swift
authManager.$currentUser
    .map { $0?.userId ?? "" }
    .removeDuplicates()
    .sink { [weak self] newUserId in
        guard let self else { return }
        self._currentUserId = nil       // ← 這裡在修改 @MainActor 的狀態
        self._progressRepo = nil
        // ...
    }
```

**問題：這個 `sink` closure 是在哪個 thread 跑？**

`authManager.$currentUser` 是一個 `@Published` property 的 publisher。在 Combine 裡，publisher 預設在「誰發出值就在誰的 thread」執行。

因為 `AuthManager` 用 Firebase Auth，而 Firebase 的 callback 通常在 main thread 回來，所以 *目前* 這是安全的。但這是一個 **隱含保證（implicit guarantee）** — 如果未來 Firebase 改了行為、或者有人在 background thread 修改 `currentUser`，這個 closure 就會在 wrong thread 存取 `@MainActor` 的狀態。

**安全的寫法** — Lens 建議加 `.receive(on: DispatchQueue.main)`：

```swift
authManager.$currentUser
    .map { $0?.userId ?? "" }
    .removeDuplicates()
    .receive(on: DispatchQueue.main)  // ← 明確保證在 main thread
    .sink { [weak self] newUserId in
        // 現在 100% 確定在 main thread
    }
```

**為什麼 Lens 說 "Not blocking"？**

因為目前的程式碼 *恰好* 是對的 — `DIContainer` 是 `@MainActor`，而 `[weak self]` 捕獲的 `self` 在 Swift 5.9+ strict concurrency 下會讓 closure 繼承 main actor isolation。但 Lens 的意思是：與其依賴這個微妙的規則，不如寫明確一點。

**類比**：想像你過馬路。現在紅綠燈是綠的，你可以走。但你還是會左右看一下，對吧？`.receive(on: .main)` 就是那個「左右看一下」— 不是因為現在不安全，而是防止未來出事。

### 2-3. 「如果以後又快取新的 ViewModel 怎麼辦？」

Lens 問了一個很好的前瞻性問題：

> Currently only `_homeViewModel` is cached (line 159). If future development adds caching to any other ViewModel, the same stale-reference bug will recur.

這指向一個更深的設計問題：**知識的丟失（knowledge loss）**。

今天我們知道「快取的 ViewModel 要在 auth change 時清掉」。但三個月後，有個新加入的工程師要快取 `DashboardViewModel`，他怎麼會知道要去 auth listener 加一行 `self._dashboardViewModel = nil`？

Lens 提了兩個建議：

**建議 1：加防禦性 comment**

```swift
// ⚠️ If you add a new cached ViewModel, you MUST clear it here.
// See COD-20 for what happens when you forget.
self._homeViewModel = nil
```

**建議 2：抽出 `invalidateAllCaches()` 方法**

```swift
private func invalidateAllCaches() {
    _currentUserId = nil
    _progressRepo = nil
    _chatRepo = nil
    _homeViewModel = nil
    // 未來新增的快取都加在這裡
}
```

這兩個建議都是在做同一件事：**把隱性知識變成顯性知識**。

**判斷框架：什麼時候該把知識「顯性化」？**

| 問題 | 答案 |
|------|------|
| 這個知識只有現在的人知道嗎？ | → 寫 comment 或文件 |
| 忘了這個知識會造成 bug 嗎？ | → 寫 comment + 考慮用 code 強制 |
| 這個模式會重複出現嗎？ | → 抽成方法或 pattern |
| 只會出現一次嗎？ | → comment 就夠了 |

---

## 第三課：UseCase 的設計邊界

COD-24 的修法是在 `EvaluateUserApproachUseCase` 裡加 SM2 依賴。打開 `docs/decisions/007-spaced-repetition-card-creation-bug.md` 看看 Archon 怎麼分析的。

他否決了 Option B（在 ChatViewModel 裡組合兩個 UseCase）和 Option C（抽 shared service）。

**為什麼不在 ViewModel 裡組合？**

```swift
// Option B（被否決）
class ChatViewModel {
    func requestUMPIRESolution() {
        evaluateUseCase.markUMPIRESolutionDelivered(problemId: id)
        updateSRUseCase.execute(problemId: id, quality: 3)  // ← 看起來很方便？
    }
}
```

問題是 `UpdateSpacedRepetitionUseCase.execute()` 裡面也會改 `attemptCount`、`lastAttemptDate`、`status`。跟 `markUMPIRESolutionDelivered()` 重複了。結果就是 **double counting** — attemptCount 加了兩次。

這是一個 **UseCase 邊界設計** 的問題。每個 UseCase 應該代表一個「完整的業務操作」，而不是一個需要跟別人組合才能完成的半成品。

```
❌ UseCase A 做了一半 + UseCase B 做了另一半 → 重疊、衝突
✅ UseCase A 做完整件事（for 情境 A）
✅ UseCase B 做完整件事（for 情境 B）
```

**類比**：你不會讓「洗衣機」洗到一半然後讓「烘乾機」把剩下的洗完。每台機器都應該完成自己的完整工作。UseCase 也是一樣。

**判斷框架：UseCase 的邊界怎麼畫？**

| 問題 | 答案 |
|------|------|
| 這個操作有明確的觸發時機嗎？ | → 一個觸發點 = 一個 UseCase |
| 兩個 UseCase 總是一起呼叫嗎？ | → 考慮合併或抽更高層的 UseCase |
| 兩個 UseCase 在不同 context 有不同行為嗎？ | → 保持分開 |
| UseCase 內部有副作用重疊嗎？ | → 重新設計邊界 |

---

## 第四課：SM-2 Quality Rating — 那些數字代表什麼？

COD-24 的修法裡有一段 quality mapping。打開 `EvaluateUserApproachUseCase.swift` 第 49-55 行：

```swift
let quality: Int
if let progress = progressRepo.getProgress(for: problemId),
   progress.status == .solvedIndependently {
    quality = 4
} else {
    quality = 3  // Default for solvedWithHelp or missing progress
}
```

### SM-2 是什麼？

SM-2（SuperMemo 2）是 1987 年由波蘭研究者 Piotr Wozniak 發明的演算法，是所有現代間隔重複系統的祖先（Anki 也是基於它）。

核心概念很簡單：**你記得越好，下次複習的間隔就越長。**

打開 `SM2Algorithm.swift` 看看完整的 0-5 分制：

| Quality | 意思 | 在 CodePrep 的場景 |
|---------|------|-------------------|
| 0 | Complete blackout — 完全不記得 | （未使用）|
| 1 | 有印象但什麼都想不起來 | （未使用）|
| 2 | 想起來了但答得很爛 | `.attempted` |
| **3** | **正確但很吃力** | **`.solvedWithHelp` — Chat/UMPIRE 解題** |
| **4** | **正確但有點猶豫** | **`.solvedIndependently` — 獨力解出** |
| 5 | 完美回答 | （未使用）|

### 為什麼 solvedWithHelp = 3，不是 2？

看 `SM2Algorithm.swift` 第 15-16 行：

```swift
if quality < 3 {
    // Failed review: reset progress
    updated.repetitionCount = 0
    updated.interval = 1
}
```

**quality < 3 代表「失敗」**，會直接重置進度。`solvedWithHelp` 雖然需要 AI 幫忙，但使用者確實理解了解法，所以算「成功但困難」（quality 3），不算「失敗」。

如果設成 2 會怎樣？使用者每次用 UMPIRE 解題都會被當成失敗，repetitionCount 永遠是 0，間隔永遠是 1 天。這樣使用者會每天看到同一題，很快就會覺得「這個 app 沒用」然後刪掉。

### 為什麼 solvedIndependently = 4，不是 5？

quality 5 = perfect recall（完美回憶）。但在 Chat/UMPIRE 流程裡，即使使用者標記為「獨力解出」，他仍然是在 AI 對話的環境中完成的。不是在白板面試時從零開始，所以用 4（有些猶豫）比 5（完美）更誠實。

**類比**：想像考試。quality 5 是閉卷考滿分。quality 4 是開書考滿分 — 答案對了，但你有參考資料。quality 3 是開書考寫對了但花了很長時間查。

### Easiness Factor — 那個神奇的公式

看 `SM2Algorithm.swift` 第 33-35 行：

```swift
let q = Double(quality)
let delta = 0.1 - (5.0 - q) * (0.08 + (5.0 - q) * 0.02)
updated.easinessFactor = max(1.3, updated.easinessFactor + delta)
```

`easinessFactor`（EF）是一張卡片的「難度係數」。初始值通常是 2.5。

- quality 高 → delta 正 → EF 上升 → 下次間隔更長（你覺得簡單，就少複習）
- quality 低 → delta 負 → EF 下降 → 下次間隔更短（你覺得難，就多複習）
- `max(1.3, ...)` 保證 EF 不會低於 1.3，避免間隔短到不合理

**你不需要記住這個公式**，但你需要理解它的意義：SM-2 會根據你的表現，自動調整每題的複習頻率。這就是 CodePrep 的 Review Queue 能「智慧排程」的原因。

---

## 第五課：Value Type 的 Dependency Injection — SM2Algorithm 為什麼是 struct？

打開 `SM2Algorithm.swift` 第 3 行：

```swift
struct SM2Algorithm: Sendable {
```

再看 `EvaluateUserApproachUseCase.swift` 第 10 行的 init：

```swift
init(chatRepo: ChatRepositoryProtocol, progressRepo: ProgressRepositoryProtocol, sm2: SM2Algorithm = SM2Algorithm()) {
```

### struct vs class 作為 dependency

`SM2Algorithm` 是一個 `struct`（value type），不是 `class`（reference type）。這是一個有意的設計選擇。

**什麼樣的 dependency 適合用 struct？**

| 特徵 | struct 適合 | class 適合 |
|------|------------|------------|
| 有內部狀態嗎？ | ❌ 無狀態（純計算） | ✅ 有狀態（connection pool、cache 等）|
| 需要共享嗎？ | ❌ 各自獨立 | ✅ 多個使用者共享同一個 |
| 需要 mock 嗎？ | 有時不用（邏輯簡單） | ✅ 通常需要 protocol |
| Thread safe 嗎？ | ✅ 天生安全（copy semantics） | ⚠️ 需要特別處理 |

`SM2Algorithm` 是一個**純函數容器** — 它沒有 property、沒有狀態，只有一個 `update()` 方法。輸入同樣的 card 和 quality，永遠得到同樣的結果。這種東西用 struct 完美。

### 為什麼它也是 `Sendable`？

`Sendable` 是 Swift concurrency 的標記，意思是「這個型別可以安全地跨 actor 傳遞」。因為 struct 是 value type（copy semantics），而且 `SM2Algorithm` 沒有 mutable state，所以它天然就是 `Sendable`。

如果它是 `class`，要標記 `Sendable` 就需要額外的工作（加 `@unchecked Sendable` 或確保所有 property 都是 immutable）。

### Default Parameter Value 的巧妙用法

```swift
init(..., sm2: SM2Algorithm = SM2Algorithm()) {
```

注意 `= SM2Algorithm()` — 這是 **default parameter value**。

**好處**：
- 正常使用時不用管它：`EvaluateUserApproachUseCase(chatRepo: repo, progressRepo: pRepo)` — 自動建一個 SM2
- 測試時可以替換：`EvaluateUserApproachUseCase(chatRepo: mock, progressRepo: mock, sm2: customSM2)`

**對比有狀態的 dependency**：

```swift
// SM2 — 無狀態，可以隨便建
init(sm2: SM2Algorithm = SM2Algorithm())  // ✅ OK

// ProgressRepository — 有狀態（SwiftData context），不能隨便建
init(progressRepo: ProgressRepositoryProtocol)  // ✅ 必須外部傳入，不能有 default
```

**判斷框架：dependency 要不要給 default value？**

| 情境 | 建議 |
|------|------|
| 無狀態的純計算（SM2、Formatter） | ✅ 給 default |
| 有狀態但 stateless 使用（Logger） | 可以考慮 |
| 共享資源（DB、Network） | ❌ 必須注入 |
| 測試中需要不同行為 | ❌ 用 protocol + 注入 |

---

## 學習地圖 (Learning Map)

| # | 概念 | 一句話解釋 | 延伸關鍵字 |
|---|------|-----------|-----------|
| 1 | Code Path Divergence | 兩條路做同一件事但實作不一致 | Shotgun Surgery, Feature Envy |
| 2 | Observable Effects Testing | 沒辦法 mock 的時候，測結果而非測接線 | Black-box testing, Input/Output testing |
| 3 | Protocol-based Mocking | 用 protocol 讓依賴可以被替換 | Dependency Inversion Principle, Test Doubles |
| 4 | Combine Thread Safety | Publisher 的 thread 取決於上游，不是你 | `receive(on:)`, `subscribe(on:)`, DispatchQueue |
| 5 | @MainActor Isolation | Swift concurrency 裡標記「只能在 main thread 執行」| Actor, Sendable, Strict Concurrency |
| 6 | Implicit vs Explicit Guarantees | 「恰好是對的」vs「保證是對的」 | Defensive programming, Contracts |
| 7 | Knowledge Codification | 把隱性知識變成 code/comment/doc | Bus factor, Onboarding |
| 8 | UseCase Boundaries | 每個 UseCase 應該是一個完整的業務操作 | Clean Architecture, Single Responsibility |
| 9 | SM-2 Algorithm | 根據回答品質自動調整複習間隔的演算法 | Spaced Repetition, Anki, Easiness Factor |
| 10 | Quality Rating Mapping | 把業務狀態對應到演算法的數值 | Domain Mapping, Semantic Mapping |
| 11 | Value Type DI | 無狀態的純計算用 struct 注入，天生 thread-safe | struct vs class, Sendable, Pure Functions |
| 12 | Default Parameter Values | 無狀態依賴給 default 值，簡化呼叫又保留可測試性 | Convenience Init, Test Seam |

## 推薦資源

1. **Martin Fowler — "Shotgun Surgery"** (refactoring.guru) — 當你改一個功能要改很多地方，就是這個 code smell
2. **WWDC 2021 — "Protect mutable state with Swift actors"** — @MainActor 的權威解釋
3. **WWDC 2019 — "Combine in Practice"** — Combine 的 thread model 講得很清楚
4. **Book: "Working Effectively with Legacy Code"** by Michael Feathers — 教你怎麼在「沒辦法 mock」的情況下寫測試
5. **Piotr Wozniak — "Application of a computer to improve the results of student learning" (1998)** — SM-2 原始論文，了解算法的初衷
6. **Nicky Case — "How To Remember Anything Forever-ish"** — 用互動式動畫解釋 spaced repetition，非常直觀

---

## 延伸思考

1. **回去翻翻你的 code**：除了 `markUMPIRESolutionDelivered` 和 `UpdateSpacedRepetitionUseCase.execute`，還有沒有其他地方會「解完一題」？如果有，那些地方有建 SpacedRepetitionCard 嗎？

2. **Protocol 的 trade-off**：如果今天要幫 `AuthManager` 加 protocol，你覺得要定義哪些 method 和 property？全部都要嗎？還是只暴露測試需要的部分？（提示：想想 Interface Segregation Principle）

3. **Notification vs Combine**：注意 `markUMPIRESolutionDelivered()` 最後用了 `NotificationCenter.default.post(...)`。為什麼這裡用 NotificationCenter 而不是 Combine publisher？你覺得哪個比較好？各自的 trade-off 是什麼？

---

*Written by Sage (Mentor) — your iOS engineering buddy* 🍵
