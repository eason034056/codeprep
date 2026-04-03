# Mentor Notes: DI Cache Invalidation & Stale References

**Date**: 2026-04-03
**Topic**: 從 COD-20 bug 學 DI 快取失效、@ObservedObject vs @StateObject、Factory vs Singleton
**Related**: `docs/decisions/006-progress-reset-after-login.md`, COD-20, COD-21

---

## Question Queue Check

你的 question_queue.md 目前沒有 pending 的問題。如果在讀這份筆記的過程中有任何疑問，隨時丟進去！

---

## 故事背景

Eason，這次的 bug 超級經典。使用者在沒有登入的時候刷了幾題 LeetCode，累積了 streak 和 XP。然後他們去 Settings 連結了 Google 帳號，回到 Home 一看 — 進度全部歸零了。

但是！資料完全沒有被刪除。它們好好的躺在 SwiftData 裡。

這就是我們今天要學的核心概念：**資料在，但 UI 看不到** — 一種特別陰險的 bug 類型。

---

## 第一課：DI Container 裡的快取陷阱

### 打開你的 `DIContainer.swift` 看看

先看第 159-172 行：

```swift
private var _homeViewModel: HomeViewModel?

var homeViewModel: HomeViewModel {
    if let existing = _homeViewModel { return existing }
    let vm = HomeViewModel(
        selectDailyUseCase: selectDailyProblems,
        problemRepo: problemRepo,
        progressRepo: progressRepo,           // ← 建立時用了「當下的」progressRepo
        learningPathProgress: learningPathProgress
    )
    vm.learningPath = selectedLearningPath
    _homeViewModel = vm
    return vm
}
```

這是一個 **lazy singleton** 模式：第一次有人要 `homeViewModel`，就建一個，之後都給同一個。

### 問題出在哪？

想像一下你去餐廳吃飯：

1. 你坐下來，服務生給你一張菜單（`progressRepo` with userId = ""）
2. 你開始點菜、吃東西（累積進度）
3. 中途你換了一張桌子（auth state change → 新的 userId）
4. 服務生說：「菜單已經更新了！」（`_progressRepo = nil`）
5. **但你手上還拿著舊菜單**（`_homeViewModel` 沒被清除，它的 `progressRepo` 還是舊的）

這就是 **stale reference**（陳舊參照）。`HomeViewModel` 被建立的時候，它把 `progressRepo` 存進了自己的 `private let` 屬性（看 `HomeViewModel.swift` 第 21 行）。這是一個 **值被捕獲** 的瞬間 — 之後你怎麼改 DIContainer 的 `_progressRepo`，都跟它無關了。

### 為什麼其他 ViewModel 沒事？

打開 `ContentView.swift` 第 35 行和第 40-46 行比較一下：

```swift
// Learn tab — 每次都建新的
LearningPathsView(viewModel: container.makeLearningPathsViewModel())

// Review tab — 每次都建新的
ReviewQueueView(viewModel: container.makeReviewQueueViewModel())
```

再看 `DIContainer.swift` 第 188-198 行：

```swift
func makeReviewQueueViewModel() -> ReviewQueueViewModel {
    ReviewQueueViewModel(
        progressRepo: progressRepo,    // ← 每次呼叫都用「最新的」progressRepo
        problemRepo: problemRepo,
        updateSRUseCase: updateSpacedRepetition
    )
}
```

看到差別了嗎？`makeReviewQueueViewModel()` 是 **工廠方法（factory method）**。每次呼叫都造一個新的，用的是當下最新的 `progressRepo`。而 `homeViewModel` 是 **快取/單例** — 只造一次，之後都回傳同一個。

**判斷框架：什麼時候該用 factory，什麼時候該用 singleton？**

| 情境 | 用 Factory（每次新建） | 用 Singleton/Cache（快取） |
|------|----------------------|--------------------------|
| 依賴的東西會變 | ✅ 安全 | ⚠️ 需要 invalidation 機制 |
| 建立成本很高 | 浪費效能 | ✅ 省資源 |
| 需要保持狀態 | 每次都丟失狀態 | ✅ 狀態保留 |
| Auth 變化時 | 自動拿到新 repo | 需要手動清 cache |

`HomeViewModel` 之所以被快取，是因為它在 `init` 的時候會做 `loadDailyProblems()`（選題、計算 XP 等），成本不低。而且它是主頁 tab，每次 SwiftUI re-render 都會被存取。如果每次都重建，會造成畫面閃爍。

**但 trade-off 就是**：一旦你快取了，你就必須負責 invalidation。這就是經典的：

> "There are only two hard things in Computer Science: cache invalidation and naming things." — Phil Karlton

---

## 第二課：@ObservedObject vs @StateObject — 誰「擁有」這個物件？

打開你的 `HomeView.swift` 第 5 行：

```swift
@ObservedObject var viewModel: HomeViewModel
```

為什麼這裡用 `@ObservedObject` 而不是 `@StateObject`？這個選擇**直接影響了 bug fix 能不能成功**。

### 兩者的核心差異

想像你養了一隻貓：

- **@StateObject** = 你是貓的主人。不管你搬幾次家（View re-render），貓都跟著你，SwiftUI 保證這隻貓活著。就算 `body` 重新計算，SwiftUI **不會** 把貓換掉。
- **@ObservedObject** = 你只是貓咪旅館。有人把貓寄放在你這，你照顧它、觀察它的行為。但明天主人可能把貓帶走，換一隻新的來。

在程式碼裡：

```swift
// @StateObject — SwiftUI 管生命週期
struct HomeView: View {
    @StateObject var viewModel = HomeViewModel(...)  // SwiftUI 只會建立一次
}

// @ObservedObject — 外部管生命週期
struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel     // 誰傳進來就用誰
}
```

### 為什麼這裡一定要用 @ObservedObject？

看 `ContentView.swift` 第 19-20 行：

```swift
HomeView(
    viewModel: container.homeViewModel,  // ← DIContainer 提供 ViewModel
    ...
)
```

`HomeViewModel` 的生命週期是由 `DIContainer` 管理的，不是由 `HomeView` 管理的。

**如果用了 @StateObject 會怎樣？**

1. Auth 變了 → DIContainer 清掉 `_homeViewModel`，建了一個新的
2. `container.objectWillChange.send()` 觸發 `ContentView` re-render
3. `ContentView.body` 重新計算，呼叫 `container.homeViewModel` 拿到新的 ViewModel
4. 但是！如果 `HomeView` 用 `@StateObject`，SwiftUI 會說：「我已經有一個了，不要你給我的新的」
5. **HomeView 繼續用舊的 ViewModel** — bug 修了也沒用！

所以 `@ObservedObject` 在這裡是 **必要的設計選擇**，不是隨便選的。

**判斷框架：什麼時候用哪個？**

| 問題 | @StateObject | @ObservedObject |
|------|-------------|-----------------|
| 誰建立這個物件？ | 這個 View 自己建的 | 別人傳進來的 |
| 物件能活過 re-render 嗎？ | ✅ SwiftUI 保護 | 取決於傳入者 |
| 適合 DI pattern 嗎？ | ❌ View 不該自己建 ViewModel | ✅ 外部注入 |

**經驗法則**：如果 ViewModel 是透過 init 參數傳進來的，就用 `@ObservedObject`。如果 View 自己在 body 裡面 new 一個，用 `@StateObject`。

---

## 第三課：Invalidation Cascade（失效連鎖）

這是 DI 快取最容易踩到的坑。打開 `DIContainer.swift` 第 102-121 行：

```swift
authManager.$currentUser
    .map { $0?.userId ?? "" }
    .removeDuplicates()
    .sink { [weak self] newUserId in
        guard let self else { return }
        self._currentUserId = nil
        self._progressRepo = nil
        self._chatRepo = nil
        self._homeViewModel = nil   // ← 這就是 fix！

        if !newUserId.isEmpty {
            self.syncService.start(userId: newUserId)
        } else {
            self.syncService.stop()
        }

        self.objectWillChange.send()
    }
```

修復前，第 111 行那行不存在。清掉了 `_progressRepo` 和 `_chatRepo`，但沒清 `_homeViewModel`。

這就是 **invalidation cascade** 問題：

```
Auth changes
  → _progressRepo = nil ✅
  → _chatRepo = nil ✅
  → _homeViewModel = ???
       └─ 裡面還拿著舊的 progressRepo 😱
```

想像一下骨牌：你推倒了第一張（清 repo），但第二張（ViewModel）沒有倒。因為 ViewModel 裡面存的是 **reference**（參照），不是每次都去問 DIContainer「現在的 repo 是誰」。

### 教訓

當你在 DI Container 裡快取物件時，畫一張 **dependency graph**：

```
DIContainer
  ├─ _progressRepo (userId dependent) ← 會變
  ├─ _chatRepo (userId dependent) ← 會變
  └─ _homeViewModel ← 依賴 progressRepo！
       ├─ progressRepo (captured at init)
       └─ problemRepo (不變)
```

**規則：當你 invalidate 一個節點，所有依賴它的節點都要跟著 invalidate。**

如果不這樣做會怎樣？就是 COD-20 — 資料在，但 UI 看不到。

---

## 第四課：「資料在但看不到」的除錯心法

這類 bug 特別惡意，因為：

1. **不會 crash** — 所以 error log 裡什麼都沒有
2. **資料沒丟** — 所以從 DB 層看一切正常
3. **UI 看起來正確** — 它確實在顯示 0，因為查詢條件「對」但 runtime 狀態「錯」

### 除錯框架

當你遇到「資料應該在但 UI 顯示不對」：

1. **先確認資料層** — 資料真的存在嗎？用 SwiftData 的 debug 工具或 print 確認
2. **檢查查詢條件** — `userId` filter 用的是哪個值？是期望的值嗎？
3. **追蹤物件身份** — 你拿到的 ViewModel/Repository 是哪一個 instance？是新的還是舊的？
4. **檢查 reference chain** — 從 UI 一路追到 data，中間有沒有任何一層拿到舊的參照？

在 CodePrep 的這個 case：

```
HomeView → @ObservedObject viewModel (舊的 HomeViewModel)
  → self.progressRepo (舊的，userId = "")
    → 查詢結果是空的（因為資料已經 migrate 到新 userId 了）
      → UI 顯示 0
```

### 快速 debug 技巧

在 `HomeViewModel.init` 加一行臨時 print：

```swift
init(...) {
    print("🔍 HomeViewModel init — progressRepo userId: \(progressRepo)")
    ...
}
```

如果 auth 變了但這行沒有被印出來，代表 ViewModel 沒有被重建 — 就是 stale reference。

---

## 第五課：為什麼修一行就好，不用大重構？

Archon（CTO）在 `docs/decisions/006-progress-reset-after-login.md` 裡列了三個被否決的方案。我們來看為什麼最簡單的反而最好：

### 方案 1：讓 HomeViewModel 自己觀察 auth 狀態
```swift
// 被否決 — 為什麼？
class HomeViewModel: ObservableObject {
    init(authManager: AuthManager, ...) {
        authManager.$currentUser.sink { ... }  // ← ViewModel 知道 auth 了
    }
}
```

**問題**：ViewModel 不應該知道 AuthManager 的存在。在 Clean Architecture 裡，ViewModel 屬於 **Presentation Layer**，AuthManager 屬於 **Infrastructure Layer**。如果 ViewModel 直接依賴 AuthManager，等於跨了兩層。

想像一下：你是餐廳的廚師（ViewModel），你只需要知道今天要做什麼菜（data）。你不需要知道客人是怎麼訂位的（auth）。訂位系統是大廳經理（DIContainer）的事。

### 方案 2：讓所有 Repo 自動反應 userId 變化

**問題**：SwiftData 的 `#Predicate` 在建立 `FetchDescriptor` 時就把 userId 值捕獲了。要讓它動態反應，等於要把整個 Repository 層重寫成 Combine publisher 模式。這是一次大手術，風險不值得。

### 方案 3：不快取 HomeViewModel

**問題**：每次 SwiftUI re-render 都重建，會重新做 `selectDailyProblems`、計算 XP 等，造成效能浪費和畫面閃爍。

### 為什麼「清一行 cache」是最好的？

```swift
self._homeViewModel = nil   // ← 就這一行
```

- **最小改動** — 只動一行，blast radius 最小
- **尊重現有架構** — 不改 layer boundary，不改 data flow
- **Auth change 是罕見事件** — 一次登入/登出才觸發一次，重建 ViewModel 的成本微不足道
- **已有基礎設施** — `objectWillChange.send()` 已經在觸發 re-render，新建的 ViewModel 會自然被 HomeView 接收

**教訓**：修 bug 時，先問「能不能用最少的改動解決？」而不是「趁機重構」。重構是另一個 task。

---

## 學習地圖 (Learning Map)

以下是這次筆記涵蓋的概念，從基礎到進階排列：

| # | 概念 | 一句話解釋 | 延伸關鍵字 |
|---|------|-----------|-----------|
| 1 | Reference vs Value | Swift class 是 reference type，struct 是 value type | `class` vs `struct`, ARC |
| 2 | Dependency Injection | 不要自己建依賴，讓外部傳進來 | DI Container, Inversion of Control |
| 3 | Factory vs Singleton | 每次建新的 vs 重複使用同一個 | Creational Patterns, GoF |
| 4 | @ObservedObject vs @StateObject | 誰擁有 ObservableObject 的生命週期 | SwiftUI property wrappers, WWDC 2020 "Data Essentials in SwiftUI" |
| 5 | Cache Invalidation | 快取了就要負責清除 | TTL, LRU, dependency graph |
| 6 | Invalidation Cascade | 清 A 時，依賴 A 的 B/C 也要清 | Reactive programming, signal propagation |
| 7 | Clean Architecture Layers | Presentation → Domain → Data，不能跨層依賴 | Uncle Bob, layer boundaries |
| 8 | Minimum Viable Fix | 用最小改動修 bug，重構另開 task | Blast radius, risk management |

## 推薦資源

1. **WWDC 2020 — Data Essentials in SwiftUI** — 最權威的 @StateObject vs @ObservedObject 解釋
2. **WWDC 2023 — Discover Observation in SwiftUI** — 新的 `@Observable` macro，是未來的方向
3. **Book: "Dependency Injection: Principles, Practices, and Patterns"** by Mark Seemann — DI 的聖經，雖然是 .NET 但概念通用

---

## 延伸思考

1. 如果未來有第二個 ViewModel 也需要被快取（例如某個很重的 Dashboard），你會怎麼設計 invalidation 機制？一個一個清？還是有更自動化的方式？

2. Swift 5.9 引入了 `@Observable` macro（用 `@Observable` 取代 `ObservableObject`）。如果 CodePrep 遷移到 `@Observable`，`@StateObject` / `@ObservedObject` 的區分還存在嗎？（提示：查查 `@Bindable`）

3. 在目前的架構中，如果有人不小心在 `_homeViewModel = nil` 之後、`objectWillChange.send()` 之前又存取了 `container.homeViewModel`，會發生什麼？（提示：思考 Combine sink 的 thread safety）

---

*Written by Sage (Mentor) — your iOS engineering buddy* 🍵
