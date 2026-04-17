# API说明

本文档记录项目中最近新增的公共 API，包含名称、参数、返回值、示例代码和测试代码。

## 1. `PresetValidator.validate(_:)`

- API 名称：`PresetValidator.validate(_ preset: CodexPreset) -> PresetValidationResult`
- 参数：
  - `preset`：待校验的预设对象。
- 返回值：
  - `PresetValidationResult`，包含 `issues` 和 `isValid`。
- 示例代码：

```swift
import CodexConfigSwitcherCore

let preset = CodexPreset(
    name: "官方接口",
    baseURL: "https://api.openai.com/v1",
    model: "gpt-5.4",
    reviewModel: "gpt-5.4",
    authMode: "apikey",
    apiKey: "sk-demo"
)

let result = PresetValidator.validate(preset)
print(result.isValid)
print(result.issues)
```

- 测试代码：

```swift
@Test
func validationRejectsInvalidBaseURL() {
    let preset = CodexPreset(name: "bad", baseURL: "not a url")
    let result = PresetValidator.validate(preset)
    #expect(result.issues.contains(.invalidBaseURL))
}
```

## 2. `PresetDiffer.diff(from:to:)`

- API 名称：`PresetDiffer.diff(from source: CodexPreset?, to target: CodexPreset) -> [PresetFieldDiff]`
- 参数：
  - `source`：基准预设，可为 `nil`。
  - `target`：目标预设。
- 返回值：
  - `[PresetFieldDiff]`，包含字段键名、显示标题、前后值和差异类型。
- 示例代码：

```swift
import CodexConfigSwitcherCore

let source = CodexPreset(name: "当前", baseURL: "https://api.openai.com/v1", apiKey: "old")
let target = CodexPreset(name: "代理", baseURL: "https://proxy.example.com/v1", apiKey: "new")

let diffs = PresetDiffer.diff(from: source, to: target)
for diff in diffs where diff.kind != .unchanged {
    print(diff.title, diff.oldValue, "->", diff.newValue)
}
```

- 测试代码：

```swift
@Test
func diffRedactsAPIKeyValues() {
    let source = CodexPreset(name: "旧", apiKey: "")
    let target = CodexPreset(name: "新", apiKey: "secret")
    let diff = PresetDiffer.diff(from: source, to: target)
        .first(where: { $0.key == "OPENAI_API_KEY" })
    #expect(diff?.newValue == "已填写")
}
```

## 3. `CodexFileService.latestBackupSummary()`

- API 名称：`CodexFileService.latestBackupSummary() throws -> BackupSnapshotSummary?`
- 参数：
  - 无。
- 返回值：
  - `BackupSnapshotSummary?`，如果存在备份则返回最近一次备份的目录路径、时间和文件路径，否则返回 `nil`。
- 示例代码：

```swift
import CodexConfigSwitcherCore

let service = try CodexFileService()
if let backup = try service.latestBackupSummary() {
    print(backup.directoryPath)
    print(backup.createdAt)
}
```

- 测试代码：

```swift
@Test
func latestBackupSummaryReturnsNewestBackup() throws {
    let workspace = try TemporaryWorkspace()
    let service = try CodexFileService(appSupportDirectory: workspace.appSupportDirectory)
    let summary = try service.latestBackupSummary()
    #expect(summary == nil || summary?.createdAt != .distantPast)
}
```

## 4. `CodexFileService.restoreLatestBackup(paths:)`

- API 名称：`CodexFileService.restoreLatestBackup(paths: AppPaths) throws -> RestoreResult`
- 参数：
  - `paths`：当前配置文件和认证文件路径。
- 返回值：
  - `RestoreResult`，包含恢复时间、源备份目录和恢复前自动创建的回滚备份路径。
- 示例代码：

```swift
import CodexConfigSwitcherCore

let service = try CodexFileService()
let result = try service.restoreLatestBackup(paths: .default)
print(result.sourceBackupDirectoryPath)
print(result.rollbackConfigBackupPath ?? "no rollback config")
```

- 测试代码：

```swift
@Test
func restoreLatestBackupRestoresMostRecentBackupAndCreatesRollbackBackup() throws {
    let workspace = try TemporaryWorkspace()
    let service = try CodexFileService(appSupportDirectory: workspace.appSupportDirectory)
    let result = try service.restoreLatestBackup(paths: workspace.paths)
    #expect(result.rollbackConfigBackupPath != nil)
}
```

## 5. `PresetTransferService.exportPresets(_:)`

- API 名称：`PresetTransferService.exportPresets(_ presets: [CodexPreset]) throws -> Data`
- 参数：
  - `presets`：要导出的预设数组。
- 返回值：
  - `Data`，内容为 JSON 格式的导出结果。
- 示例代码：

```swift
import CodexConfigSwitcherCore

let service = PresetTransferService()
let data = try service.exportPresets([
    CodexPreset(name: "官方", baseURL: "https://api.openai.com/v1", apiKey: "sk-demo")
])
try data.write(to: URL(fileURLWithPath: "/tmp/codex-preset.json"))
```

- 测试代码：

```swift
@Test
func exportAndImportRoundTripsPayload() throws {
    let service = PresetTransferService()
    let data = try service.exportPresets([CodexPreset(name: "官方")])
    let imported = try service.importPresets(from: data)
    #expect(imported.count == 1)
}
```

## 6. `PresetTransferService.importPresets(from:)`

- API 名称：`PresetTransferService.importPresets(from data: Data) throws -> [CodexPreset]`
- 参数：
  - `data`：待导入的 JSON 数据。
- 返回值：
  - `[CodexPreset]`，支持读取单个预设对象、预设数组或带 `version/presets` 的导出 payload。
- 示例代码：

```swift
import CodexConfigSwitcherCore

let service = PresetTransferService()
let data = try Data(contentsOf: URL(fileURLWithPath: "/tmp/codex-preset.json"))
let presets = try service.importPresets(from: data)
print(presets.map(\.name))
```

- 测试代码：

```swift
@Test
func importAcceptsSinglePresetObject() throws {
    let service = PresetTransferService()
    let data = try JSONEncoder().encode(CodexPreset(name: "单个导入"))
    let imported = try service.importPresets(from: data)
    #expect(imported.first?.name == "单个导入")
}
```

## 7. `AppSettings.favoritePresetIDs / recentPresetIDs`

- API 名称：
  - `AppSettings.favoritePresetIDs`
  - `AppSettings.recentPresetIDs`
- 参数：
  - 无。
- 返回值：
  - `favoritePresetIDs`：`[UUID]`，表示收藏预设 ID 列表。
  - `recentPresetIDs`：`[UUID]`，表示最近使用预设 ID 列表，按最近优先排序。
- 示例代码：

```swift
import CodexConfigSwitcherCore

let favoriteID = UUID()
let recentID = UUID()
let settings = AppSettings(
    favoritePresetIDs: [favoriteID],
    recentPresetIDs: [recentID]
)

print(settings.favoritePresetIDs)
print(settings.recentPresetIDs)
```

- 测试代码：

```swift
@Test
func settingsStorePersistsLastAppliedMetadata() throws {
    let favoriteID = UUID()
    let recentID = UUID()
    let settings = AppSettings(
        favoritePresetIDs: [favoriteID],
        recentPresetIDs: [recentID]
    )
    #expect(settings.favoritePresetIDs == [favoriteID])
    #expect(settings.recentPresetIDs == [recentID])
}
```

## 8. `ConnectionTestService.testConnection(for:)`

- API 名称：`ConnectionTestService.testConnection(for preset: CodexPreset) async -> ConnectionTestResult`
- 参数：
  - `preset`：当前要测试连接的预设，使用其中的 `baseURL`、`authMode`、`apiKey`、`model`。
- 返回值：
  - `ConnectionTestResult`，包含 `outcome`、`endpoint`、`statusCode`、`title`、`message`。
- 示例代码：

```swift
import CodexConfigSwitcherCore

let service = ConnectionTestService()
let result = await service.testConnection(
    for: CodexPreset(
        name: "官方",
        model: "gpt-5.4",
        reviewModel: "gpt-5.4",
        baseURL: "https://api.openai.com/v1",
        authMode: "apikey",
        apiKey: "sk-demo"
    )
)

print(result.outcome)
print(result.message)
```

- 测试代码：

```swift
@Test
func connectionTestFailsOnUnauthorizedResponse() async {
    let service = ConnectionTestService { request in
        let response = HTTPURLResponse(
            url: try #require(request.url),
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )
        return (Data(), try #require(response))
    }

    let result = await service.testConnection(
        for: CodexPreset(
            name: "bad",
            model: "gpt-5.4",
            reviewModel: "gpt-5.4",
            baseURL: "https://proxy.example.com/v1",
            authMode: "apikey",
            apiKey: "bad-key"
        )
    )

    #expect(result.title == "鉴权失败")
}
```

## 9. `CodexFileService.listBackupSummaries(limit:)`

- API 名称：`CodexFileService.listBackupSummaries(limit: Int? = nil) throws -> [BackupSnapshotSummary]`
- 参数：
  - `limit`：可选，限制返回的备份数量；为 `nil` 时返回全部备份。
- 返回值：
  - `[BackupSnapshotSummary]`，按最新优先排序的备份摘要列表。
- 示例代码：

```swift
import CodexConfigSwitcherCore

let service = try CodexFileService()
let backups = try service.listBackupSummaries(limit: 5)
for backup in backups {
    print(backup.createdAt, backup.directoryPath)
}
```

- 测试代码：

```swift
@Test
func listBackupSummariesReturnsNewestFirst() throws {
    let workspace = try TemporaryWorkspace()
    let service = try CodexFileService(appSupportDirectory: workspace.appSupportDirectory)
    let summaries = try service.listBackupSummaries(limit: 5)
    #expect(summaries.count >= 0)
}
```

## 10. `CodexFileService.restoreBackup(_:paths:)`

- API 名称：`CodexFileService.restoreBackup(_ backup: BackupSnapshotSummary, paths: AppPaths) throws -> RestoreResult`
- 参数：
  - `backup`：要恢复的备份摘要。
  - `paths`：当前配置文件和认证文件路径。
- 返回值：
  - `RestoreResult`，包含恢复时间、源备份目录和恢复前自动创建的回滚备份路径。
- 示例代码：

```swift
import CodexConfigSwitcherCore

let service = try CodexFileService()
if let backup = try service.listBackupSummaries(limit: 1).first {
    let result = try service.restoreBackup(backup, paths: .default)
    print(result.sourceBackupDirectoryPath)
}
```

- 测试代码：

```swift
@Test
func restoreBackupRestoresChosenSnapshot() throws {
    let workspace = try TemporaryWorkspace()
    let service = try CodexFileService(appSupportDirectory: workspace.appSupportDirectory)
    let backups = try service.listBackupSummaries(limit: 5)
    if let backup = backups.last {
        let result = try service.restoreBackup(backup, paths: workspace.paths)
        #expect(result.sourceBackupDirectoryPath == backup.directoryPath)
    }
}
```

## 11. `PresetTransferService.importPresets(from:)` 错误校验行为

- API 名称：`PresetTransferService.importPresets(from data: Data) throws -> [CodexPreset]`
- 参数：
  - `data`：待导入的 JSON 数据。
- 返回值：
  - `[CodexPreset]`，成功时返回导入的预设列表；失败时抛出包含详细中文原因的错误。
- 行为补充：
  - 非法 JSON 会提示“导入文件不是合法的 JSON”。
  - 空数组会提示“导入文件中没有可用的预设”。
  - 结构像数组或对象但字段缺失时，会提示对应结构解析失败。
  - 单个预设字段不合法时，会提示第几个预设、预设名以及具体字段问题。
- 示例代码：

```swift
import CodexConfigSwitcherCore

let service = PresetTransferService()
do {
    let data = try Data(contentsOf: URL(fileURLWithPath: "/tmp/presets.json"))
    let presets = try service.importPresets(from: data)
    print("导入成功：", presets.count)
} catch {
    print("导入失败：", error.localizedDescription)
}
```

- 测试代码：

```swift
@Test
func importRejectsPresetWithInvalidFields() throws {
    let service = PresetTransferService()
    let data = Data("[{\"name\":\"坏预设\",\"model\":\"\",\"baseURL\":\"bad-url\"}]".utf8)

    do {
        _ = try service.importPresets(from: data)
        Issue.record("expected invalid preset fields to fail")
    } catch {
        #expect(error.localizedDescription.contains("第 1 个预设"))
    }
}
```

## 12. `AppModel.importPresetsByAppending()`

- API 名称：`AppModel.importPresetsByAppending()`
- 参数：
  - 无。调用后会弹出文件选择器，让用户选择要导入的 JSON 文件。
- 返回值：
  - 无。成功时会把导入预设追加到现有列表；若出现同名预设，会自动重命名为“名称 2 / 名称 3 ...”避免冲突。
- 示例代码：

```swift
import SwiftUI

struct ImportAppendButton: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Button("追加导入（同名自动重命名）") {
            model.importPresetsByAppending()
        }
    }
}
```

- 测试代码：

```swift
@Test
func importAppendModeRenamesDuplicatedName() throws {
    let transfer = PresetTransferService()
    let data = Data("[{\"name\":\"官方\",\"model\":\"gpt-5.4\",\"reviewModel\":\"gpt-5.4\",\"baseURL\":\"https://api.openai.com/v1\"}]".utf8)
    let imported = try transfer.importPresets(from: data)
    #expect(imported.count == 1)
    // App 层追加模式会在写入现有列表时自动处理同名重命名。
}
```

## 13. `AppModel.importPresetsByReplacingSameName()`

- API 名称：`AppModel.importPresetsByReplacingSameName()`
- 参数：
  - 无。调用后会弹出文件选择器，让用户选择要导入的 JSON 文件。
- 返回值：
  - 无。成功时会按名称匹配并覆盖同名预设，未命中的导入项会新增到列表中。
- 示例代码：

```swift
import SwiftUI

struct ImportReplaceButton: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Button("导入并覆盖同名") {
            model.importPresetsByReplacingSameName()
        }
    }
}
```

- 测试代码：

```swift
@Test
func importReplaceModeKeepsPresetCountStableWhenNameMatches() throws {
    let transfer = PresetTransferService()
    let data = Data("[{\"name\":\"官方\",\"model\":\"gpt-5.4\",\"reviewModel\":\"gpt-5.4\",\"baseURL\":\"https://api.openai.com/v1\"}]".utf8)
    let imported = try transfer.importPresets(from: data)
    #expect(imported.first?.name == "官方")
    // App 层覆盖模式会把该名称映射到已有预设并原位替换。
}
```

## 14. `PresetEditorMode`

- API 名称：`PresetEditorMode`
- 参数：
  - 无。它是一个用于描述预设编辑视图层级的枚举。
- 返回值：
  - `.basic`：基础模式，只展示高频字段。
  - `.advanced`：高级模式，展示完整字段。
- 示例代码：

```swift
import CodexConfigSwitcherCore

let mode: PresetEditorMode = .basic
print(mode.rawValue)
```

- 测试代码：

```swift
@Test
func settingsStorePersistsPresetEditorMode() throws {
    let workspace = try TemporaryWorkspace()
    let store = try SettingsStore(fileURL: workspace.rootDirectory.appendingPathComponent("settings.json"))

    try store.saveSettings(
        AppSettings(
            paths: workspace.paths,
            presetEditorMode: .advanced
        )
    )

    let settings = try store.loadSettings()
    #expect(settings.presetEditorMode == .advanced)
}
```

## 15. `AppModel.setPresetEditorMode(_:)`

- API 名称：`AppModel.setPresetEditorMode(_ mode: PresetEditorMode)`
- 参数：
  - `mode`：目标编辑模式，可选 `basic` 或 `advanced`。
- 返回值：
  - 无。调用后会更新当前编辑器模式，并将结果写入 `settings.json`。
- 示例代码：

```swift
import SwiftUI

struct EditorModeToggle: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Picker("编辑模式", selection: Binding(
            get: { model.presetEditorMode },
            set: { model.setPresetEditorMode($0) }
        )) {
            Text("基础模式").tag(PresetEditorMode.basic)
            Text("高级模式").tag(PresetEditorMode.advanced)
        }
        .pickerStyle(.segmented)
    }
}
```

- 测试代码：

```swift
@Test
func settingsStoreLoadsLegacySettingsWithoutLastAppliedMetadata() throws {
    let workspace = try TemporaryWorkspace()
    let fileURL = workspace.rootDirectory.appendingPathComponent("settings.json")
    let store = try SettingsStore(fileURL: fileURL)

    try """
    {
      "paths": {
        "configPath": "\(workspace.configURL.path)",
        "authPath": "\(workspace.authURL.path)"
      }
    }
    """.write(to: fileURL, atomically: true, encoding: .utf8)

    let settings = try store.loadSettings()
    #expect(settings.presetEditorMode == .basic)
}
```

## 16. `PresetEnvironmentTag.infer(from:)`

- API 名称：`PresetEnvironmentTag.infer(from baseURL: String) -> PresetEnvironmentTag`
- 参数：
  - `baseURL`：用于推断环境类型的接口地址。
- 返回值：
  - `PresetEnvironmentTag`。当前内置规则会返回 `official / proxy / test / backup` 中的一个；其中 `api.openai.com` 会识别为 `official`，本地地址或包含 `test/staging/sandbox` 的地址会识别为 `test`，其余地址默认识别为 `proxy`。
- 示例代码：

```swift
import CodexConfigSwitcherCore

let official = PresetEnvironmentTag.infer(from: "https://api.openai.com/v1")
let proxy = PresetEnvironmentTag.infer(from: "https://proxy.example.com/v1")

print(official.title)
print(proxy.isHighRisk)
```

- 测试代码：

```swift
@Test
func loadSnapshotReadsCurrentConfigFields() throws {
    let workspace = try TemporaryWorkspace()
    let service = try CodexFileService(appSupportDirectory: workspace.appSupportDirectory)

    try workspace.writeConfig("""
    [model_providers.OpenAI]
    base_url = "http://localhost:8080"
    """)
    try workspace.writeAuth("{\"auth_mode\":\"apikey\",\"OPENAI_API_KEY\":\"key\"}")

    let snapshot = try service.loadSnapshot(paths: workspace.paths)
    #expect(snapshot.preset.environmentTag == .test)
}
```

## 17. `CodexPreset.environmentTag`

- API 名称：`CodexPreset.environmentTag`
- 参数：
  - 无。它是 `CodexPreset` 上的预设元数据字段。
- 返回值：
  - `PresetEnvironmentTag`，表示当前预设所属环境类型。
- 示例代码：

```swift
import CodexConfigSwitcherCore

let preset = CodexPreset(
    name: "公司代理",
    environmentTag: .proxy,
    baseURL: "https://proxy.example.com/v1"
)

print(preset.environmentTag.title)
```

- 测试代码：

```swift
@Test
func presetStoreLoadsLegacyPresetsWithoutEnvironmentTag() throws {
    let workspace = try TemporaryWorkspace()
    let fileURL = workspace.rootDirectory.appendingPathComponent("presets.json")

    try """
    [
      {
        "name": "老代理预设",
        "baseURL": "https://proxy.example.com/v1"
      }
    ]
    """.write(to: fileURL, atomically: true, encoding: .utf8)

let presets = try PresetStore(fileURL: fileURL).loadPresets()
#expect(presets.first?.environmentTag == .proxy)
}
```

## 18. `AppSettings.operationHistory`

- API 名称：`AppSettings.operationHistory`
- 参数：
  - 无。
- 返回值：
  - `[PresetOperationHistoryEntry]`，按最近优先排序的操作历史列表。
  - 单条记录包含 `kind`、`outcome`、`operatedAt`、`presetID`、`presetName`、`environmentTag` 和 `detail`，用于追踪预设应用与备份恢复结果。
- 示例代码：

```swift
import CodexConfigSwitcherCore

let historyEntry = PresetOperationHistoryEntry(
    kind: .applyPreset,
    outcome: .success,
    presetID: UUID(),
    presetName: "官方环境",
    environmentTag: .official,
    detail: "已应用预设并完成配置写入。"
)

let settings = AppSettings(operationHistory: [historyEntry])
print(settings.operationHistory.first?.kind.title ?? "")
```

- 测试代码：

```swift
@Test
func settingsStorePersistsOperationHistory() throws {
    let workspace = try TemporaryWorkspace()
    let store = try SettingsStore(fileURL: workspace.rootDirectory.appendingPathComponent("settings.json"))

    try store.saveSettings(
        AppSettings(
            paths: workspace.paths,
            operationHistory: [
                PresetOperationHistoryEntry(
                    kind: .applyPreset,
                    outcome: .success,
                    presetID: UUID(),
                    presetName: "官方环境",
                    environmentTag: .official,
                    detail: "已应用预设并完成配置写入。"
                )
            ]
        )
    )

    let settings = try store.loadSettings()
    #expect(settings.operationHistory.count == 1)
}
```

## 19. `ApplicationSupportPaths.templatesFileURL(fileManager:)`

- API 名称：`ApplicationSupportPaths.templatesFileURL(fileManager: FileManager = .default) throws -> URL`
- 参数：
  - `fileManager`：用于定位并创建 `Application Support` 目录的文件管理器，默认值为 `.default`。
- 返回值：
  - `URL`，指向本地模板库文件 `templates.json` 的保存位置。
- 示例代码：

```swift
import CodexConfigSwitcherCore

let templatesURL = try ApplicationSupportPaths.templatesFileURL()
print(templatesURL.path)
```

- 测试代码：

```swift
@Test
func applicationSupportProvidesTemplatesPath() throws {
    let templatesURL = try ApplicationSupportPaths.templatesFileURL(fileManager: .default)
    #expect(templatesURL.lastPathComponent == "templates.json")
}
```

## 20. `CodexTemplate.init(id:preset:name:)`

- API 名称：`CodexTemplate.init(id: UUID = UUID(), preset: CodexPreset, name: String? = nil)`
- 参数：
  - `id`：模板 ID，默认自动生成。
  - `preset`：要转成模板的预设。
  - `name`：可选模板名；未传时沿用预设名。
- 返回值：
  - `CodexTemplate`，包含模板白名单字段，不包含 `apiKey` 等敏感认证值。
- 示例代码：

```swift
import CodexConfigSwitcherCore

let preset = CodexPreset(
    name: "代理环境",
    environmentTag: .proxy,
    baseURL: "https://proxy.example.com/v1",
    model: "gpt-5.4",
    reviewModel: "gpt-5.4",
    authMode: "apikey",
    apiKey: "secret"
)

let template = CodexTemplate(preset: preset, name: "代理模板")
print(template.name)
print(template.baseURL)
```

- 测试代码：

```swift
@Test
func templateStoreDoesNotPersistAPIKey() throws {
    let preset = CodexPreset(name: "敏感代理", apiKey: "super-secret-key")
    let template = CodexTemplate(preset: preset)
    #expect(template.authMode == preset.authMode)
}
```

## 21. `CodexTemplate.makePreset(id:name:)`

- API 名称：`CodexTemplate.makePreset(id: UUID = UUID(), name: String? = nil) -> CodexPreset`
- 参数：
  - `id`：新预设 ID，默认自动生成。
  - `name`：可选新预设名；未传时沿用模板名。
- 返回值：
  - `CodexPreset`，复用模板白名单字段，并将 `apiKey` 置空，供用户补充新的认证信息。
- 示例代码：

```swift
import CodexConfigSwitcherCore

let template = CodexTemplate(
    name: "官方模板",
    environmentTag: .official,
    baseURL: "https://api.openai.com/v1",
    model: "gpt-5.4",
    reviewModel: "gpt-5.4",
    authMode: "apikey"
)

let preset = template.makePreset(name: "官方环境 2")
print(preset.id)
print(preset.apiKey.isEmpty)
```

- 测试代码：

```swift
@Test
func templateCreatesPresetWithFreshIDAndEmptyAPIKey() {
    let template = CodexTemplate(name: "官方模板")
    let preset = template.makePreset()
    #expect(preset.id != template.id)
    #expect(preset.apiKey.isEmpty)
}
```

## 22. `TemplateStore.loadTemplates()`

- API 名称：`TemplateStore.loadTemplates() throws -> [CodexTemplate]`
- 参数：
  - 无。
- 返回值：
  - `[CodexTemplate]`，从 `templates.json` 读取到的本地模板列表；如果文件不存在，则返回空数组。
- 示例代码：

```swift
import CodexConfigSwitcherCore

let store = try TemplateStore()
let templates = try store.loadTemplates()
print(templates.map(\.name))
```

- 测试代码：

```swift
@Test
func templateStoreCanSaveAndLoadTemplates() throws {
    let workspace = try TemporaryWorkspace()
    let store = try TemplateStore(fileURL: workspace.rootDirectory.appendingPathComponent("templates.json"))
    try store.saveTemplates([CodexTemplate(name: "代理模板")])
    let templates = try store.loadTemplates()
    #expect(templates.count == 1)
}
```

## 23. `TemplateStore.saveTemplates(_:)`

- API 名称：`TemplateStore.saveTemplates(_ templates: [CodexTemplate]) throws`
- 参数：
  - `templates`：要持久化保存的模板数组。
- 返回值：
  - 无；成功时会将模板列表写入 `templates.json`。
- 示例代码：

```swift
import CodexConfigSwitcherCore

let store = try TemplateStore()
try store.saveTemplates([
    CodexTemplate(name: "代理模板", environmentTag: .proxy, baseURL: "https://proxy.example.com/v1")
])
```

- 测试代码：

```swift
@Test
func templateStoreDoesNotPersistAPIKey() throws {
    let workspace = try TemporaryWorkspace()
    let fileURL = workspace.rootDirectory.appendingPathComponent("templates.json")
    let store = try TemplateStore(fileURL: fileURL)
    try store.saveTemplates([CodexTemplate(preset: CodexPreset(name: "敏感代理", apiKey: "super-secret-key"))])

    let raw = try String(contentsOf: fileURL, encoding: .utf8)
    #expect(raw.contains("apiKey") == false)
    #expect(raw.contains("super-secret-key") == false)
}
```

## 24. `AppModel.loadTemplateIntoDraft(id:)`

- API 名称：`AppModel.loadTemplateIntoDraft(id: UUID)`
- 参数：
  - `id`：要载入到当前草稿的模板 ID。
- 返回值：
  - 无；会更新当前 `draft`，但不会直接改写当前已选预设。
- 示例代码：

```swift
@testable import CodexConfigSwitcher

let model = try workspace.makeAppModel()
model.loadTemplateIntoDraft(id: template.id)
print(model.draft.baseURL)
print(model.hasUnsavedChanges)
```

- 测试代码：

```swift
@Test
func loadTemplateIntoDraftKeepsSelectedPresetAndDoesNotMutateStoredPreset() throws {
    let model = try workspace.makeAppModel()
    model.loadTemplateIntoDraft(id: template.id)
    #expect(model.selectedPresetID == preset.id)
    #expect(model.draft.apiKey.isEmpty)
}
```

## 25. `AppModel.overwriteTemplate(id:)`

- API 名称：`AppModel.overwriteTemplate(id: UUID)`
- 参数：
  - `id`：要被当前草稿覆盖的模板 ID。
- 返回值：
  - 无；会使用当前草稿的白名单字段更新模板，并保持模板名不变。
- 示例代码：

```swift
@testable import CodexConfigSwitcher

let model = try workspace.makeAppModel()
model.draft.baseURL = "https://proxy.example.com/v1"
model.overwriteTemplate(id: template.id)
```

- 测试代码：

```swift
@Test
func overwriteTemplatePersistsSanitizedDraft() throws {
    let model = try workspace.makeAppModel()
    model.overwriteTemplate(id: template.id)
    let raw = try String(contentsOf: workspace.templatesURL, encoding: .utf8)
    #expect(raw.contains("apiKey") == false)
}
```

## 26. `AppModel.renameTemplate(id:to:)`

- API 名称：`AppModel.renameTemplate(id: UUID, to proposedName: String)`
- 参数：
  - `id`：要重命名的模板 ID。
  - `proposedName`：期望的新模板名；为空时会报错，重名时会自动追加序号。
- 返回值：
  - 无；会更新模板名并持久化到 `templates.json`。
- 示例代码：

```swift
@testable import CodexConfigSwitcher

let model = try workspace.makeAppModel()
model.renameTemplate(id: template.id, to: "个人骨架")
```

- 测试代码：

```swift
@Test
func renameAndDeleteTemplatePersistChanges() throws {
    let model = try workspace.makeAppModel()
    model.renameTemplate(id: firstTemplate.id, to: "个人骨架")
    model.renameTemplate(id: secondTemplate.id, to: "个人骨架")
    #expect(model.templates.last?.name == "个人骨架 2")
}
```

## 27. `AppModel.deleteTemplate(id:)`

- API 名称：`AppModel.deleteTemplate(id: UUID)`
- 参数：
  - `id`：要删除的模板 ID。
- 返回值：
  - 无；会从当前模板列表与 `templates.json` 中移除对应模板。
- 示例代码：

```swift
@testable import CodexConfigSwitcher

let model = try workspace.makeAppModel()
model.deleteTemplate(id: template.id)
print(model.templates.count)
```

- 测试代码：

```swift
@Test
func renameAndDeleteTemplatePersistChanges() throws {
    let model = try workspace.makeAppModel()
    model.deleteTemplate(id: firstTemplate.id)
    #expect(model.templates.count == 1)
}
```

## 28. `CodexConfigSwitcherCLI status`

- API 名称：`CodexConfigSwitcherCLI status`
- 参数：
  - 无。
- 返回值：
  - 标准输出当前平台、`config.toml` / `auth.json` 路径、预设数量、模板数量，以及当前 live 配置摘要；成功时退出码为 `0`。
- 示例代码：

```bash
swift run CodexConfigSwitcherCLI status
```

- 测试代码：

```bash
swift run CodexConfigSwitcherCLI help
swift run CodexConfigSwitcherCLI status
```

## 29. `CodexConfigSwitcherCLI list-presets`

- API 名称：`CodexConfigSwitcherCLI list-presets`
- 参数：
  - 无。
- 返回值：
  - 标准输出当前所有预设，每行包含选中标记、预设名、环境标签、`baseURL` 和 `model`；成功时退出码为 `0`。
- 示例代码：

```bash
swift run CodexConfigSwitcherCLI list-presets
```

- 测试代码：

```bash
swift run CodexConfigSwitcherCLI capture-live --name 当前机器
swift run CodexConfigSwitcherCLI list-presets
```

## 30. `CodexConfigSwitcherCLI apply --preset`

- API 名称：`CodexConfigSwitcherCLI apply --preset <名称>`
- 参数：
  - `--preset`：要应用的预设名称，按名称大小写不敏感匹配。
- 返回值：
  - 标准输出已应用预设名、接口地址、模型和备份路径；同时更新 `settings.json` 中的最近应用信息；成功时退出码为 `0`。
- 示例代码：

```bash
swift run CodexConfigSwitcherCLI apply --preset 官方环境
```

- 测试代码：

```bash
swift run CodexConfigSwitcherCLI list-presets
swift run CodexConfigSwitcherCLI apply --preset 官方环境
```

## 31. `CodexConfigSwitcherCLI capture-live --name`

- API 名称：`CodexConfigSwitcherCLI capture-live --name <名称>`
- 参数：
  - `--name`：从当前 live 配置生成的新预设名称；如果重名会自动追加序号。
- 返回值：
  - 标准输出新预设名称；同时把当前 `config.toml` / `auth.json` 读取结果追加保存到 `presets.json`；成功时退出码为 `0`。
- 示例代码：

```bash
swift run CodexConfigSwitcherCLI capture-live --name 当前机器
```

- 测试代码：

```bash
swift run CodexConfigSwitcherCLI capture-live --name 当前机器
swift run CodexConfigSwitcherCLI list-presets
```

## 32. `CodexConfigSwitcherCLI save-template --preset`

- API 名称：`CodexConfigSwitcherCLI save-template --preset <预设名称> [--name <模板名称>]`
- 参数：
  - `--preset`：要转成模板的预设名称。
  - `--name`：可选，自定义模板名；不传时默认使用预设名，并在重名时自动追加序号。
- 返回值：
  - 标准输出新模板名称；同时把脱敏后的模板写入 `templates.json`；成功时退出码为 `0`。
- 示例代码：

```bash
swift run CodexConfigSwitcherCLI save-template --preset 官方环境 --name 官方模板
```

- 测试代码：

```bash
swift run CodexConfigSwitcherCLI save-template --preset 官方环境 --name 官方模板
swift run CodexConfigSwitcherCLI list-templates
```

## 33. `CodexConfigSwitcherCLI create-from-template --template`

- API 名称：`CodexConfigSwitcherCLI create-from-template --template <模板名称> [--name <新预设名称>]`
- 参数：
  - `--template`：源模板名称。
  - `--name`：可选，新预设名称；不传时默认使用模板名，并在重名时自动追加序号。
- 返回值：
  - 标准输出新预设名称；同时把模板内容转换为新预设并写入 `presets.json`，新预设会自动生成新的 `UUID` 且 `apiKey` 为空；成功时退出码为 `0`。
- 示例代码：

```bash
swift run CodexConfigSwitcherCLI create-from-template --template 官方模板 --name 新机器模板
```

- 测试代码：

```bash
swift run CodexConfigSwitcherCLI save-template --preset 官方环境 --name 官方模板
swift run CodexConfigSwitcherCLI create-from-template --template 官方模板 --name 新机器模板
swift run CodexConfigSwitcherCLI list-presets
```

## 34. `ManagedAppRuntimeService.availability(for:)`

- API 名称：`ManagedAppRuntimeService.availability(for target: ManagedAppTarget) -> ManagedAppAvailability`
- 参数：
  - `target`：目标应用配置，包含显示名称、Bundle ID 和应用路径。
- 返回值：
  - `ManagedAppAvailability`，返回 `running / installed / missing` 之一，并可通过 `title` 获取中文状态文案。
- 示例代码：

```swift
import CodexConfigSwitcherCore

let service = ManagedAppRuntimeService()
let availability = service.availability(for: .codex)
print(availability.title)
```

- 测试代码：

```swift
@Test
func windowsAvailabilityReturnsRunningWhenProcessIsFound() throws {
    let service = ManagedAppRuntimeService(
        platform: .windows,
        fileManager: .default,
        environment: ["SystemRoot": #"C:\Windows"#],
        runner: runner
    )
    #expect(service.availability(for: target) == .running)
}
```

## 35. `ManagedAppRuntimeService.restart(_:)`

- API 名称：`ManagedAppRuntimeService.restart(_ target: ManagedAppTarget) throws`
- 参数：
  - `target`：要重启或拉起的目标应用配置。
- 返回值：
  - 无；成功时结束旧进程并重新启动目标应用，失败时抛出 `ConfigSwitchError`。
- 示例代码：

```swift
import CodexConfigSwitcherCore

let service = ManagedAppRuntimeService()
try service.restart(.codex)
```

- 测试代码：

```swift
@Test
func windowsRestartStopsThenStartsTarget() throws {
    try service.restart(target)
    #expect(runner.commands[1].arguments.joined(separator: " ").contains("Stop-Process"))
    #expect(runner.commands[2].arguments.joined(separator: " ").contains("Start-Process"))
}
```

## 36. `CodexConfigSwitcherCLI target status`

- API 名称：`CodexConfigSwitcherCLI target status`
- 参数：
  - 无。
- 返回值：
  - 标准输出当前目标应用的显示名、Bundle ID、路径和状态；成功时退出码为 `0`。
- 示例代码：

```bash
swift run CodexConfigSwitcherCLI target status
```

- 测试代码：

```bash
swift run CodexConfigSwitcherCLI target status
```

## 37. `CodexConfigSwitcherCLI target set-path --path`

- API 名称：`CodexConfigSwitcherCLI target set-path --path <路径>`
- 参数：
  - `--path`：自定义目标应用路径，例如 Windows 下的 `Codex.exe` 路径或 macOS 下的 `.app` 路径。
- 返回值：
  - 标准输出更新后的路径和当前状态；同时把新目标应用写入 `settings.json`；成功时退出码为 `0`。
- 示例代码：

```bash
swift run CodexConfigSwitcherCLI target set-path --path "C:\\Users\\bridge\\AppData\\Local\\Programs\\Codex\\Codex.exe"
```

- 测试代码：

```bash
swift run CodexConfigSwitcherCLI target set-path --path "C:\\Users\\bridge\\AppData\\Local\\Programs\\Codex\\Codex.exe"
swift run CodexConfigSwitcherCLI target status
```

## 38. `CodexConfigSwitcherCLI target reset`

- API 名称：`CodexConfigSwitcherCLI target reset`
- 参数：
  - 无。
- 返回值：
  - 标准输出恢复后的默认路径和状态；同时把 `settings.json` 中的目标应用恢复为当前平台默认值；成功时退出码为 `0`。
- 示例代码：

```bash
swift run CodexConfigSwitcherCLI target reset
```

- 测试代码：

```bash
swift run CodexConfigSwitcherCLI target reset
swift run CodexConfigSwitcherCLI target status
```

## 39. `CodexConfigSwitcherCLI target restart`

- API 名称：`CodexConfigSwitcherCLI target restart`
- 参数：
  - 无。
- 返回值：
  - 标准输出已重启的目标应用名称；内部复用 `ManagedAppRuntimeService.restart(_:)`；成功时退出码为 `0`。
- 示例代码：

```bash
swift run CodexConfigSwitcherCLI target restart
```

- 测试代码：

```bash
swift run CodexConfigSwitcherCLI target status
swift run CodexConfigSwitcherCLI target restart
```

## 40. `CodexConfigSwitcherCLI apply --restart`

- API 名称：`CodexConfigSwitcherCLI apply --preset <名称> --restart`
- 参数：
  - `--preset`：要应用的预设名称。
  - `--restart`：可选标记；传入后在写入配置成功后立即重启当前目标应用。
- 返回值：
  - 标准输出预设应用结果、备份路径，以及可选的目标应用重启结果；成功时退出码为 `0`。
- 示例代码：

```bash
swift run CodexConfigSwitcherCLI apply --preset 官方环境 --restart
```

- 测试代码：

```bash
swift run CodexConfigSwitcherCLI target status
swift run CodexConfigSwitcherCLI apply --preset 官方环境 --restart
```

## 41. `CodexConfigSwitcherCLI status --json`

- API 名称：`CodexConfigSwitcherCLI status --json`
- 参数：
  - `--json`：可选标记；输出面向 GUI/脚本消费的 JSON 状态，而不是面向人类阅读的文本摘要。
- 返回值：
  - JSON 对象，包含 `platform`、`configPath`、`authPath`、`presetCount`、`templateCount`、`livePreset`、`matchedPresetName`、`lastAppliedAt`、`targetApp`、`targetAvailability` 和 `targetAvailabilityTitle`；其中 `livePreset.apiKey` 已做脱敏处理。
- 示例代码：

```bash
swift run CodexConfigSwitcherCLI status --json
```

- 测试代码：

```bash
swift run CodexConfigSwitcherCLI status --json
```

## 42. `CodexConfigSwitcherCLI target status --json`

- API 名称：`CodexConfigSwitcherCLI target status --json`
- 参数：
  - `--json`：可选标记；输出目标应用的 JSON 状态。
- 返回值：
  - JSON 对象，包含 `targetApp`、`availability` 和 `availabilityTitle`，适合 WinUI 3 或脚本直接反序列化使用。
- 示例代码：

```bash
swift run CodexConfigSwitcherCLI target status --json
```

- 测试代码：

```bash
swift run CodexConfigSwitcherCLI target status --json
```

## 43. `windows/CodexConfigSwitcher.WinUI`

- API 名称：`windows/CodexConfigSwitcher.WinUI`
- 参数：
  - 无；这是 Windows 原生 GUI 工程入口。
- 返回值：
  - WinUI 3 工程骨架，当前包含 `App.xaml`、`MainWindow.xaml`、本地 JSON 仓储、CLI 桥接服务和首屏 ViewModel。
- 示例代码：

```text
打开 windows/CodexConfigSwitcher.Windows.sln
使用 Visual Studio 2026 或更新版本加载并构建 windows/CodexConfigSwitcher.WinUI
```

- 测试代码：

```text
当前仓库内尚无 WinUI 自动化测试；首轮验证依赖 Windows + Visual Studio 环境编译运行。
```

## 44. `AppModel.confirmSaveAndSelectPendingPreset()`

- API 名称：`AppModel.confirmSaveAndSelectPendingPreset()`
- 参数：
  - 无；要求此前因未保存草稿而触发过 `selectPreset(id:)` 的待切换状态。
- 返回值：
  - 无；会先把当前草稿覆盖保存回当前选中预设，再切换到待选中的目标预设。
- 示例代码：

```swift
let model = try workspace.makeAppModel()
model.draft.baseURL = "https://saved-draft.example.com/v1"
model.selectPreset(id: anotherPresetID)
model.confirmSaveAndSelectPendingPreset()
```

- 测试代码：

```swift
@Test
func confirmingSaveBeforeSwitchingPersistsCurrentPresetThenSwitches() throws {
    model.selectPreset(id: secondPreset.id)
    model.confirmSaveAndSelectPendingPreset()
    #expect(model.selectedPresetID == secondPreset.id)
}
```

## 45. `AppModel.confirmDiscardAndSelectPendingPreset()`

- API 名称：`AppModel.confirmDiscardAndSelectPendingPreset()`
- 参数：
  - 无；要求此前因未保存草稿而触发过 `selectPreset(id:)` 的待切换状态。
- 返回值：
  - 无；会放弃当前未保存草稿，并切换到待选中的目标预设。
- 示例代码：

```swift
let model = try workspace.makeAppModel()
model.draft.baseURL = "https://draft.example.com/v1"
model.selectPreset(id: anotherPresetID)
model.confirmDiscardAndSelectPendingPreset()
```

- 测试代码：

```swift
@Test
func selectingAnotherPresetWithUnsavedChangesRequiresConfirmation() throws {
    model.selectPreset(id: secondPreset.id)
    model.confirmDiscardAndSelectPendingPreset()
    #expect(model.selectedPresetID == secondPreset.id)
}
```

## 46. `AppModel.cancelPendingPresetSelection()`

- API 名称：`AppModel.cancelPendingPresetSelection()`
- 参数：
  - 无；用于取消一次由未保存草稿触发的待切换预设确认流。
- 返回值：
  - 无；会清空 `presetPendingSelection`，保留当前选中预设和当前草稿不变。
- 示例代码：

```swift
let model = try workspace.makeAppModel()
model.selectPreset(id: anotherPresetID)
model.cancelPendingPresetSelection()
```

- 测试代码：

```swift
@Test
func selectingAnotherPresetWithUnsavedChangesRequiresConfirmation() throws {
    model.selectPreset(id: secondPreset.id)
    model.cancelPendingPresetSelection()
    #expect(model.selectedPresetID == firstPreset.id)
}
```

## 47. `MainWindowContextBannerContext`

- API 名称：`MainWindowContextBannerContext`
- 参数：
  - `livePresetID`：当前 live 配置匹配到的预设 ID。
  - `livePresetName`：当前生效预设名称。
  - `liveEnvironmentTag`：当前生效预设的环境标签。
  - `selectedPresetName`：当前编辑中的预设名称。
  - `selectedEnvironmentTag`：当前编辑预设的环境标签。
  - `title`：主窗口 context banner 标题。
  - `message`：主窗口 context banner 正文。
- 返回值：
  - 一个可供主窗口 banner 直接消费的上下文数据结构。
- 示例代码：

```swift
let context = MainWindowContextBannerContext(
    livePresetID: UUID(),
    livePresetName: "菜单栏切换目标",
    liveEnvironmentTag: .official,
    selectedPresetName: "当前编辑预设",
    selectedEnvironmentTag: .official,
    title: "当前生效配置已切换，编辑区仍停留在旧草稿",
    message: "继续编辑不会影响当前 live，直到你主动保存并应用。"
)
print(context.title)
```

- 测试代码：

```swift
let context = try #require(model.mainWindowContextBannerContext)
#expect(context.livePresetName == "菜单栏切换目标")
```

## 48. `AppModel.mainWindowContextBannerContext`

- API 名称：`AppModel.mainWindowContextBannerContext`
- 参数：
  - 无；基于当前 `lastLoaded`、`livePresetID`、`selectedPreset` 与 `hasUnsavedChanges` 自动派生。
- 返回值：
  - `MainWindowContextBannerContext?`；当当前 live 配置与未保存草稿发生脱节时返回上下文，否则返回 `nil`。
- 示例代码：

```swift
let model = try workspace.makeAppModel()
if let context = model.mainWindowContextBannerContext {
    print(context.livePresetName)
    print(context.selectedPresetName)
}
```

- 测试代码：

```swift
@Test
func menuApplyKeepsUnsavedDraftIntact() throws {
    model.applyPresetFromMenu(id: secondPreset.id)
    let context = try #require(model.mainWindowContextBannerContext)
    #expect(context.selectedPresetName == "当前编辑预设")
}
```

## 49. `AppModel.shouldShowMainWindowContextBanner`

- API 名称：`AppModel.shouldShowMainWindowContextBanner`
- 参数：
  - 无。
- 返回值：
  - `Bool`；当主窗口应该持续显示 context banner 时返回 `true`。
- 示例代码：

```swift
let model = try workspace.makeAppModel()
if model.shouldShowMainWindowContextBanner {
    print("show banner")
}
```

- 测试代码：

```swift
@Test
func contextBannerStaysHiddenWithoutLiveSnapshot() throws {
    model.lastLoaded = nil
    #expect(model.shouldShowMainWindowContextBanner == false)
}
```
