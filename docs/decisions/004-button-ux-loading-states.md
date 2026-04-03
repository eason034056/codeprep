# COD-14: Button UX Improvements — Loading States + ScalePress Sweep

## Implementation Notes

### Problem
Interactive buttons across the app lacked consistent press feedback (scale animation) and haptic response. The chat send button also had no visual loading indicator during the pre-stream window (after tapping send, before the first AI token arrives).

### Approach
Presentation-layer-only changes — no domain or data modifications. Used the existing `ScalePressButtonStyle` from `AnimationTokens.swift` and `HapticManager` singleton.

**Why this approach over a new `LoadingButtonStyle`:**
The CTO's plan explicitly suggested inline conditional content for the chat spinner rather than a new button style. This keeps the change minimal and avoids abstracting a one-off pattern.

### What Changed

#### 1. Chat Send Button Spinner (`ChatView.swift`)
- Replaced the static `arrow.up.circle.fill` icon with a `Group` that conditionally renders:
  - `ProgressView()` with `AppColor.accent` tint when `isStreaming && streamingText.isEmpty`
  - The original arrow icon otherwise
- Used `.transition(.opacity)` on both branches + `.animation(.easeInOut(duration: 0.25))` for smooth crossfade
- The button was already disabled during streaming — no behavior change needed

**Alternative considered:** Wrapping both states in `ZStack` with opacity toggles. Rejected because `Group` with `if/else` + transitions is cleaner and avoids rendering both views simultaneously.

#### 2. OnboardingView ScalePress Sweep
| Button | `.scalePress` | Haptic |
|--------|:---:|:---:|
| Continue (page nav) | Yes | `light()` added |
| Path cards (Grind 75, NeetCode 150) | Yes | `light()` added |
| Save Key | Yes | `light()` added |
| Skip for now | Yes | No (tertiary action) |
| Get Started | Yes | `light()` added |

#### 3. SettingsView ScalePress Sweep
| Button | `.scalePress` | Haptic |
|--------|:---:|:---:|
| Sign In with Google | Yes | Already in ViewModel |
| Sign In with Apple | Yes | Already in ViewModel |
| Save Key | Yes | Already had `light()` |
| Apply custom model | Yes | Already had `medium()` |
| Export Data | Yes (was `.plain`) | Already had `light()` |
| Delete All Data | Yes (was `.plain`) | No (destructive, uses system alert) |
| ModelModeButton | Yes (was `.plain`) | Already had `light()` |

#### 4. LoginView ScalePress Sweep
| Button | `.scalePress` | Haptic |
|--------|:---:|:---:|
| Continue with Google | Yes | `light()` added |
| SignInWithAppleButton | Skipped (native HIG component) | N/A |

### What Was NOT Touched (per requirements)
- Toolbar / navigation buttons (system behavior)
- Tab bar buttons (`CustomTabBarView.swift`)
- `SignInWithAppleButton` in `LoginView` (native Apple HIG component)
- System alert/confirmation buttons
- DatePicker components

### Patterns Referenced
- `ScalePressButtonStyle` — `Core/DesignSystem/AnimationTokens.swift:67-77`
- `HapticManager.shared` — `Core/DesignSystem/HapticManager.swift`
- `AppColor.accent` tint — `Core/DesignSystem/DesignTokens.swift:8`
- Existing `.scalePress` usage — `ChatView.swift:212` (send button already had it)

### Potential Risks
- **ScalePress on disabled buttons:** `.buttonStyle(.scalePress)` still applies the scale animation even when `.disabled(true)`. This is acceptable because disabled buttons already have reduced opacity, and the scale springs back instantly if the button doesn't fire. No user confusion expected.
- **ProgressView sizing:** The spinner is constrained to 32x32 to match the send arrow icon size. If the system ProgressView changes default sizing in future iOS versions, this frame keeps it stable.

### TODO
- Consider adding `.scalePress` to future buttons added to the app (establish as default convention)
- The `TypingIndicatorView` in the chat scroll area is separate from the send button spinner — both serve different purposes (typing dots = chat area feedback, spinner = input bar feedback)
