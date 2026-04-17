# P0 Product UX Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deliver the first UX refactor milestone for Codex Config Switcher so users can clearly distinguish live state vs selected preset vs unsaved draft, complete common edits in a simplified main window, and switch configs faster from the menu bar with safer guardrails.

**Architecture:** Keep file read/write behavior centered in `CodexConfigSwitcherCore`, but move new validation and preset-comparison logic into testable core helpers. Let `AppModel` orchestrate derived UI state such as current live preset, unsaved changes, validation issues, pending destructive actions, and settings sheet visibility. Split the SwiftUI UI into smaller view components so the main window can show a sidebar, summary card, basic editor, advanced section, and a dedicated settings sheet without turning `PresetEditorView` into an even larger monolith.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit (`NSOpenPanel`, `NSAlert`), Swift Testing

---

## Execution Notes

- The current worktree is already dirty. Before editing, re-read and preserve user changes in:
  - `README.md`
  - `Sources/CodexConfigSwitcher/Views/PresetEditorView.swift`
  - `Sources/CodexConfigSwitcherCore/Models.swift`
  - `Tests/CodexConfigSwitcherCoreTests/CodexFileServiceTests.swift`
  - `#功能和BUG记录.md`
- Do not rewrite the top of `#功能和BUG记录.md`. Only append new records at the bottom with a timestamp when actual feature implementation lands.
- Update `README.md` after the UX refactor ships so the main window and menu bar behavior descriptions stay accurate.
- This plan only covers `P0-1` through `P0-6`. Leave `P1/P2` for follow-up plans.

### Task 1: Add testable preset validation and live-match primitives

**Files:**
- Create: `Sources/CodexConfigSwitcherCore/PresetValidation.swift`
- Modify: `Sources/CodexConfigSwitcherCore/Models.swift`
- Create: `Tests/CodexConfigSwitcherCoreTests/PresetValidationTests.swift`

**Step 1: Write the failing tests**

Add tests for:
- invalid `baseURL`
- empty required fields
- missing API key when `authMode == "apikey"`
- invalid numeric values
- managed-field equality between two presets that differ only in display-only fields

Suggested test names:

```swift
@Test func validationRejectsInvalidBaseURL() throws
@Test func validationRejectsMissingRequiredFields() throws
@Test func validationRequiresAPIKeyForAPIKeyMode() throws
@Test func validationRejectsNonPositiveNumericFields() throws
@Test func managedFingerprintIgnoresPresetNameAndIdentifier() throws
```

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter PresetValidationTests
```

Expected:

- FAIL because `PresetValidationTests.swift` and validation types do not exist yet

**Step 3: Write minimal implementation**

Implement in `Sources/CodexConfigSwitcherCore/PresetValidation.swift`:

```swift
public enum PresetValidationIssue: Equatable, Sendable {
    case emptyName
    case invalidBaseURL
    case emptyModel
    case emptyReviewModel
    case emptyAuthMode
    case missingAPIKey
    case invalidContextWindow
    case invalidAutoCompactTokenLimit
}

public struct PresetValidationResult: Equatable, Sendable {
    public let issues: [PresetValidationIssue]
    public var isValid: Bool { issues.isEmpty }
}

public enum PresetValidator {
    public static func validate(_ preset: CodexPreset) -> PresetValidationResult { ... }
}
```

Add to `Sources/CodexConfigSwitcherCore/Models.swift`:

```swift
public struct ManagedPresetFingerprint: Equatable, Sendable { ... }

extension CodexPreset {
    public var managedFingerprint: ManagedPresetFingerprint { ... }
}
```

Rules:
- `name`, `model`, `reviewModel`, `authMode`, `baseURL` are trimmed before validation
- `baseURL` must parse as `http` or `https`
- `modelContextWindow` and `modelAutoCompactTokenLimit` must be `> 0`
- `managedFingerprint` excludes `id` and `name`

**Step 4: Run test to verify it passes**

Run:

```bash
swift test --filter PresetValidationTests
```

Expected:

- PASS

**Step 5: Commit**

```bash
git add Sources/CodexConfigSwitcherCore/PresetValidation.swift Sources/CodexConfigSwitcherCore/Models.swift Tests/CodexConfigSwitcherCoreTests/PresetValidationTests.swift
git commit -m "feat: add preset validation primitives"
```

### Task 2: Extend persisted settings and AppModel state for live/dirty tracking

**Files:**
- Modify: `Sources/CodexConfigSwitcherCore/Models.swift`
- Modify: `Sources/CodexConfigSwitcherCore/PresetStore.swift`
- Modify: `Tests/CodexConfigSwitcherCoreTests/CodexFileServiceTests.swift`
- Modify: `Sources/CodexConfigSwitcher/AppModel.swift`

**Step 1: Write the failing tests**

Add tests that prove legacy settings still decode and new settings fields round-trip:

```swift
@Test func settingsStorePersistsLastAppliedMetadata() throws
@Test func settingsStoreLoadsLegacySettingsWithoutLastAppliedMetadata() throws
```

Use `AppSettings` to persist:

```swift
lastAppliedPresetID: UUID?
lastAppliedAt: Date?
```

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter settingsStorePersistsLastAppliedMetadata
swift test --filter settingsStoreLoadsLegacySettingsWithoutLastAppliedMetadata
```

Expected:

- FAIL because `AppSettings` does not contain the new fields

**Step 3: Write minimal implementation**

Update `Sources/CodexConfigSwitcherCore/Models.swift`:
- add `lastAppliedPresetID`
- add `lastAppliedAt`
- keep decoding backward compatible with `decodeIfPresent`

Update `Sources/CodexConfigSwitcher/AppModel.swift`:
- load and persist the new metadata
- add derived properties:
  - `var validationResult: PresetValidationResult`
  - `var hasUnsavedChanges: Bool`
  - `var livePresetID: UUID?`
  - `var lastAppliedPresetID: UUID?`
- compute `hasUnsavedChanges` by comparing `draft` to the selected stored preset
- compute `livePresetID` by comparing each preset’s `managedFingerprint` to `lastLoaded?.preset.managedFingerprint`
- when applying succeeds, persist `lastAppliedPresetID` and `lastAppliedAt`

**Step 4: Run tests**

Run:

```bash
swift test --filter settingsStorePersistsLastAppliedMetadata
swift test --filter settingsStoreLoadsLegacySettingsWithoutLastAppliedMetadata
swift test
```

Expected:

- PASS

**Step 5: Commit**

```bash
git add Sources/CodexConfigSwitcherCore/Models.swift Sources/CodexConfigSwitcherCore/PresetStore.swift Sources/CodexConfigSwitcher/AppModel.swift Tests/CodexConfigSwitcherCoreTests/CodexFileServiceTests.swift
git commit -m "feat: track live and applied preset state"
```

### Task 3: Create reusable UI components for sidebar rows and summary cards

**Files:**
- Create: `Sources/CodexConfigSwitcher/Views/Components/PresetStatusBadge.swift`
- Create: `Sources/CodexConfigSwitcher/Views/Components/PresetSidebarRow.swift`
- Create: `Sources/CodexConfigSwitcher/Views/Components/CurrentStatusSummaryCard.swift`
- Modify: `Sources/CodexConfigSwitcher/Views/MainWindowView.swift`

**Step 1: Write the minimal preview/manual scaffold**

Create the component files with temporary preview or fixture data using `CodexPreset.sample(...)` so layout can be iterated without touching the full editor yet.

Target component responsibilities:
- `PresetStatusBadge`: render `当前生效` / `未保存` / `最近应用`
- `PresetSidebarRow`: show name, base URL summary, model summary, and up to 2 badges
- `CurrentStatusSummaryCard`: show live environment, selected preset, draft status, last applied time, and target app availability

**Step 2: Run the app for visual inspection**

Run:

```bash
swift run CodexConfigSwitcher
```

Expected:

- Build succeeds even if the new components are not wired in yet

**Step 3: Replace inline sidebar row rendering**

Update `Sources/CodexConfigSwitcher/Views/MainWindowView.swift` so the preset list row uses `PresetSidebarRow` fed by:
- `model.livePresetID`
- `model.selectedPresetID`
- `model.lastAppliedPresetID`
- `model.hasUnsavedChanges` for the selected item

Do not move button actions yet. Only switch to reusable presentation components.

**Step 4: Run manual smoke check**

Run:

```bash
swift run CodexConfigSwitcher
```

Verify:

- sidebar rows still render
- selected item still changes when clicked
- no regressions in the delete/new/save toolbar

**Step 5: Commit**

```bash
git add Sources/CodexConfigSwitcher/Views/Components/PresetStatusBadge.swift Sources/CodexConfigSwitcher/Views/Components/PresetSidebarRow.swift Sources/CodexConfigSwitcher/Views/Components/CurrentStatusSummaryCard.swift Sources/CodexConfigSwitcher/Views/MainWindowView.swift
git commit -m "feat: add status-oriented sidebar components"
```

### Task 4: Refactor the main window into workspace + settings entry

**Files:**
- Modify: `Sources/CodexConfigSwitcher/Views/MainWindowView.swift`
- Create: `Sources/CodexConfigSwitcher/Views/SettingsSheetView.swift`
- Modify: `Sources/CodexConfigSwitcher/CodexConfigSwitcherApp.swift`

**Step 1: Wire the new layout shell**

In `Sources/CodexConfigSwitcher/Views/MainWindowView.swift`:
- keep `NavigationSplitView`
- add a top toolbar row or header above the editor with:
  - `CurrentStatusSummaryCard`
  - settings button
  - refresh button
  - load-live-into-draft button

**Step 2: Move low-frequency settings out of the main editor**

Create `Sources/CodexConfigSwitcher/Views/SettingsSheetView.swift` and move these groups there:
- config/auth file paths
- restart prompt toggle
- target app fields
- restart target app button

Keep `PresetEditorView` focused on preset editing only.

**Step 3: Present the settings sheet**

Add app state in `AppModel` or local view state in `MainWindowView`:

```swift
@Published var isShowingSettingsSheet = false
```

Present:

```swift
.sheet(isPresented: ...)
```

**Step 4: Run manual smoke check**

Run:

```bash
swift run CodexConfigSwitcher
```

Verify:

- main window first screen no longer starts with file paths
- settings sheet opens and closes cleanly
- settings sheet changes still persist

**Step 5: Commit**

```bash
git add Sources/CodexConfigSwitcher/Views/MainWindowView.swift Sources/CodexConfigSwitcher/Views/SettingsSheetView.swift Sources/CodexConfigSwitcher/CodexConfigSwitcherApp.swift
git commit -m "feat: separate global settings from preset editor"
```

### Task 5: Simplify PresetEditorView into basic and advanced sections

**Files:**
- Modify: `Sources/CodexConfigSwitcher/Views/PresetEditorView.swift`
- Possibly Create: `Sources/CodexConfigSwitcher/Views/Components/LabeledFieldHelp.swift`

**Step 1: Rewrite the editor structure**

Refactor `Sources/CodexConfigSwitcher/Views/PresetEditorView.swift` into:
- header / action row
- basic info section
- authentication section
- advanced disclosure section
- status section

Basic section should include:
- `预设名称`
- `接口地址` (`base_url`)
- `主模型` (`model`)
- `评审模型` (`review_model`)
- `认证模式` (`auth_mode`)
- `API Key`

Advanced section should include:
- provider-related fields
- reasoning/network fields
- runtime toggles
- numeric windows and retained retry values

**Step 2: Add user-facing helper copy**

For each basic field, display the user-facing label first and the raw config key as helper text:

```swift
Text("接口地址")
Text("base_url")
    .font(.caption)
    .foregroundStyle(.secondary)
```

Do not expose low-frequency raw keys as the main heading anymore.

**Step 3: Surface validation and dirty state in the editor**

Show:
- `未保存修改` when `model.hasUnsavedChanges`
- inline validation summary when `!model.validationResult.isValid`
- disable or visually downgrade the apply button until validation passes

**Step 4: Run manual smoke check**

Run:

```bash
swift run CodexConfigSwitcher
```

Verify:

- default view shows a much shorter form
- advanced configuration is collapsed by default
- validation summary appears when URL/API key are invalid

**Step 5: Commit**

```bash
git add Sources/CodexConfigSwitcher/Views/PresetEditorView.swift Sources/CodexConfigSwitcher/Views/Components/LabeledFieldHelp.swift
git commit -m "feat: simplify preset editor for common tasks"
```

### Task 6: Add apply guardrails and deletion confirmation

**Files:**
- Modify: `Sources/CodexConfigSwitcher/AppModel.swift`
- Modify: `Sources/CodexConfigSwitcher/Views/MainWindowView.swift`
- Modify: `Sources/CodexConfigSwitcher/Views/PresetEditorView.swift`

**Step 1: Prevent invalid apply actions**

Change `applyDraft()` to:
- early-return when `validationResult.isValid == false`
- populate `errorMessage` or a dedicated validation message for fatal preflight failure

If the current UI allows clicking the button while invalid, show a clear reason instead of silently doing nothing.

**Step 2: Add a delete-confirmation flow**

Track pending deletion state in `AppModel`:

```swift
@Published var presetPendingDeletion: CodexPreset?
```

Use a confirmation dialog or alert in `MainWindowView` before calling the destructive delete path.

**Step 3: Make the destructive path explicit**

Split the old method into:

```swift
func requestDeleteSelectedPreset()
func confirmDeleteSelectedPreset()
func cancelDeletePreset()
```

Keep actual deletion in `confirmDeleteSelectedPreset()`.

**Step 4: Run manual smoke check**

Run:

```bash
swift run CodexConfigSwitcher
```

Verify:

- invalid drafts cannot be applied
- delete requires explicit confirmation
- canceling delete leaves selection unchanged

**Step 5: Commit**

```bash
git add Sources/CodexConfigSwitcher/AppModel.swift Sources/CodexConfigSwitcher/Views/MainWindowView.swift Sources/CodexConfigSwitcher/Views/PresetEditorView.swift
git commit -m "feat: add validation guardrails and delete confirmation"
```

### Task 7: Replace manual path entry with system pickers in the settings sheet

**Files:**
- Create: `Sources/CodexConfigSwitcher/SystemPickerService.swift`
- Modify: `Sources/CodexConfigSwitcher/Views/SettingsSheetView.swift`
- Modify: `Sources/CodexConfigSwitcher/AppModel.swift`

**Step 1: Implement picker helpers**

Create `Sources/CodexConfigSwitcher/SystemPickerService.swift` with AppKit wrappers:

```swift
struct SystemPickerService {
    func pickFile(allowedExtensions: [String], startingAt path: String?) -> String? { ... }
    func pickApplication(startingAt path: String?) -> ManagedAppTarget? { ... }
}
```

Rules:
- config picker filters `toml`
- auth picker filters `json`
- app picker uses `.app`

**Step 2: Add buttons in settings**

In `Sources/CodexConfigSwitcher/Views/SettingsSheetView.swift`, add buttons:
- `选择 config.toml`
- `选择 auth.json`
- `选择目标 App`

Keep manual text fields visible for fallback editing.

**Step 3: Persist picked values**

In `Sources/CodexConfigSwitcher/AppModel.swift`, add methods:

```swift
func chooseConfigFile()
func chooseAuthFile()
func chooseTargetApplication()
```

Each method:
- opens picker
- updates state if a value is returned
- calls `persistSettings()`

**Step 4: Run manual smoke check**

Run:

```bash
swift run CodexConfigSwitcher
```

Verify:

- selecting files updates the fields
- canceling leaves existing values untouched
- selecting an app updates display name and app path sensibly

**Step 5: Commit**

```bash
git add Sources/CodexConfigSwitcher/SystemPickerService.swift Sources/CodexConfigSwitcher/Views/SettingsSheetView.swift Sources/CodexConfigSwitcher/AppModel.swift
git commit -m "feat: add system pickers for settings"
```

### Task 8: Upgrade the menu bar into a true quick-switch surface

**Files:**
- Modify: `Sources/CodexConfigSwitcher/Views/MenuBarContentView.swift`
- Reuse: `Sources/CodexConfigSwitcher/Views/Components/PresetStatusBadge.swift`

**Step 1: Rework the menu bar sections**

Reorder content to:
- app title
- current live environment summary
- quick switch list
- secondary actions
- status/error footer

**Step 2: Highlight the actual live preset**

Use `model.livePresetID` for the strongest highlight, not just `selectedPresetID`.

If `selectedPresetID != livePresetID`, show a lighter secondary state so the user understands that “selected” and “running” differ.

**Step 3: Add instant feedback after apply**

After menu apply succeeds, ensure the menu can render a concise status line such as:

```swift
"已切换到：\(preset.name)"
```

If the target app restart prompt is enabled, reflect that in the compact status line after the apply completes.

**Step 4: Run manual smoke check**

Run:

```bash
swift run CodexConfigSwitcher
```

Verify:

- menu bar shows the current live environment first
- currently active preset is visually obvious
- switching from the menu updates status feedback immediately

**Step 5: Commit**

```bash
git add Sources/CodexConfigSwitcher/Views/MenuBarContentView.swift Sources/CodexConfigSwitcher/Views/Components/PresetStatusBadge.swift
git commit -m "feat: improve menu bar quick switch experience"
```

### Task 9: Documentation, release notes, and feature log updates

**Files:**
- Modify: `README.md`
- Modify: `#功能和BUG记录.md`
- Optional: `CHANGELOG.md`

**Step 1: Update README**

Document:
- simplified main window structure
- settings sheet location
- menu bar live-state highlighting
- validation-before-apply behavior

**Step 2: Append the feature log entry**

Append at the bottom of `#功能和BUG记录.md` with timestamp. Include:
- 类型：新功能
- 内容：P0 产品体验改版
- 思路
- 处理步骤
- 原因

Do not insert at the top.

**Step 3: Optional version note**

If this work is being released as a visible milestone, append an entry to `CHANGELOG.md`.

**Step 4: Final verification**

Run:

```bash
swift test
swift run CodexConfigSwitcher
```

Manual checklist:
- can identify current live preset from both main window and menu bar
- can tell when draft is dirty
- cannot apply obviously invalid draft
- can delete only after confirmation
- can open settings and pick files/apps via system dialog

**Step 5: Commit**

```bash
git add README.md "#功能和BUG记录.md" CHANGELOG.md
git commit -m "docs: record p0 ux refactor"
```

---

## Suggested Execution Order

1. `Task 1`
2. `Task 2`
3. `Task 3`
4. `Task 4`
5. `Task 5`
6. `Task 6`
7. `Task 7`
8. `Task 8`
9. `Task 9`

## Risks To Watch

- `AppModel` is currently doing state orchestration, persistence, and side effects together. Keep changes incremental or it will become harder to reason about.
- `PresetEditorView.swift` is already large and currently modified in the worktree. Re-read before each edit and avoid overwriting unrelated user changes.
- Menu bar highlighting should use live config, not just selected preset, or the new UX will still be misleading.
- File picker and app picker code will introduce AppKit coupling; keep wrappers small.
- Validation rules must stay aligned with `CodexFileService.apply(...)` so the UI does not reject valid data that the writer supports.

## Definition Of Done

- Main window shows status-first layout and no longer starts with low-frequency global settings
- Users can identify live preset, selected preset, and dirty draft without guessing
- Apply is guarded by validation
- Delete requires confirmation
- Settings can use system pickers for files and target app
- Menu bar clearly highlights the live environment and gives immediate feedback after switching
- `README.md` and `#功能和BUG记录.md` are updated after implementation
