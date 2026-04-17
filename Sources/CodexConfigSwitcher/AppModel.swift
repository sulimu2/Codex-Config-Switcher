import AppKit
import CodexConfigSwitcherCore
import Foundation

enum PresetListSortMode: String, CaseIterable, Identifiable {
    case recentUsage
    case nameAscending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recentUsage:
            "最近使用优先"
        case .nameAscending:
            "名称排序"
        }
    }
}

struct MainWindowContextBannerContext: Equatable {
    let livePresetID: UUID
    let livePresetName: String
    let liveEnvironmentTag: PresetEnvironmentTag
    let selectedPresetName: String
    let selectedEnvironmentTag: PresetEnvironmentTag?
    let title: String
    let message: String
}

@MainActor
final class AppModel: ObservableObject {
    private enum PresetImportMode {
        case appendWithRename
        case replaceByName
    }

    private enum ApplySource {
        case editor
        case menuPreservingDraft
    }

    private let maxOperationHistoryEntries = 20

    @Published var presets: [CodexPreset] = []
    @Published var draft: CodexPreset = .sample()
    @Published var selectedPresetID: UUID?
    @Published var paths: AppPaths = .default
    @Published var restartPromptEnabled = true
    @Published var targetApp: ManagedAppTarget = .codex
    @Published var favoritePresetIDs: [UUID] = []
    @Published var recentPresetIDs: [UUID] = []
    @Published var operationHistory: [PresetOperationHistoryEntry] = []
    @Published var templates: [CodexTemplate] = []
    @Published var statusMessage = "准备就绪"
    @Published var errorMessage: String?
    @Published var lastLoaded: LiveConfigurationSnapshot?
    @Published var lastApplied: ApplyResult?
    @Published var latestBackup: BackupSnapshotSummary?
    @Published var recentBackups: [BackupSnapshotSummary] = []
    @Published var isTestingConnection = false
    @Published var lastConnectionTestResult: ConnectionTestResult?
    @Published var presetPendingDeletion: CodexPreset?
    @Published var backupPendingRestore: BackupSnapshotSummary?
    @Published var presetPendingApplyConfirmation: CodexPreset?
    @Published var presetPendingSelection: CodexPreset?
    @Published var isShowingSettingsSheet = false
    @Published var presetEditorMode: PresetEditorMode = .basic
    @Published private var storedLastAppliedPresetID: UUID?
    @Published private var storedLastAppliedAt: Date?
    @Published private var recentAppliedPresetName: String?
    @Published private var recentStatusLine: String?
    private var pendingApplySource: ApplySource = .editor

    private let fileService: CodexFileService
    private let presetStore: PresetStore
    private let settingsStore: SettingsStore
    private let templateStore: TemplateStore
    private let connectionTestService: ConnectionTestService
    private let transferService: PresetTransferService
    private let targetAppService: TargetAppService
    private let pickerService: SystemPickerService

    convenience init() {
        do {
            let fileService = try CodexFileService()
            let presetStore = try PresetStore()
            let settingsStore = try SettingsStore()
            let templateStore = try TemplateStore()
            self.init(
                fileService: fileService,
                presetStore: presetStore,
                settingsStore: settingsStore,
                templateStore: templateStore
            )
        } catch {
            fatalError("无法初始化存储目录：\(error.localizedDescription)")
        }
    }

    init(
        fileService: CodexFileService,
        presetStore: PresetStore,
        settingsStore: SettingsStore,
        templateStore: TemplateStore,
        connectionTestService: ConnectionTestService = ConnectionTestService(),
        transferService: PresetTransferService = PresetTransferService(),
        targetAppService: TargetAppService = TargetAppService(),
        pickerService: SystemPickerService = SystemPickerService()
    ) {
        self.fileService = fileService
        self.presetStore = presetStore
        self.settingsStore = settingsStore
        self.templateStore = templateStore
        self.connectionTestService = connectionTestService
        self.transferService = transferService
        self.targetAppService = targetAppService
        self.pickerService = pickerService

        bootstrap()
    }

    var compactStatusLine: String? {
        if let recentStatusLine {
            return recentStatusLine
        }

        if let recentAppliedPresetName,
           let lastAppliedDate {
            return "已切换到：\(recentAppliedPresetName) · \(format(date: lastAppliedDate))"
        }

        if let lastApplied {
            return "最近应用：\(format(date: lastApplied.appliedAt))"
        }

        if let storedLastAppliedAt {
            return "最近应用：\(format(date: storedLastAppliedAt))"
        }

        if let lastLoaded {
            return "最近读取：\(format(date: lastLoaded.loadedAt))"
        }

        return statusMessage.isEmpty ? nil : statusMessage
    }

    var validationResult: PresetValidationResult {
        PresetValidator.validate(draft)
    }

    var validationSummary: String? {
        validationResult.summary
    }

    var selectedPreset: CodexPreset? {
        guard let selectedPresetID else {
            return nil
        }

        return presets.first(where: { $0.id == selectedPresetID })
    }

    var hasUnsavedChanges: Bool {
        guard let selectedPreset else {
            return false
        }

        return draft != selectedPreset
    }

    var livePresetID: UUID? {
        guard let liveFingerprint = lastLoaded?.preset.managedFingerprint else {
            return nil
        }

        return presets.first(where: { $0.managedFingerprint == liveFingerprint })?.id
    }

    var lastAppliedPresetID: UUID? {
        storedLastAppliedPresetID
    }

    var lastAppliedDate: Date? {
        lastApplied?.appliedAt ?? storedLastAppliedAt
    }

    var diffPreview: [PresetFieldDiff] {
        PresetDiffer.diff(from: lastLoaded?.preset, to: draft)
    }

    var changedDiffPreview: [PresetFieldDiff] {
        diffPreview.filter { $0.kind != .unchanged }
    }

    var livePresetName: String {
        if let livePresetID,
           let preset = presets.first(where: { $0.id == livePresetID }) {
            return preset.name
        }

        if let baseURL = lastLoaded?.preset.baseURL, !baseURL.isEmpty {
            return "当前 live 配置"
        }

        return "未识别"
    }

    var livePresetEnvironmentTag: PresetEnvironmentTag {
        if let livePresetID,
           let preset = presets.first(where: { $0.id == livePresetID }) {
            return preset.environmentTag
        }

        return lastLoaded?.preset.environmentTag ?? .official
    }

    var selectedPresetEnvironmentTag: PresetEnvironmentTag? {
        selectedPreset?.environmentTag
    }

    var mainWindowContextBannerContext: MainWindowContextBannerContext? {
        guard
            hasUnsavedChanges,
            let selectedPreset,
            let livePresetID,
            livePresetID != selectedPreset.id,
            let livePreset = presets.first(where: { $0.id == livePresetID })
        else {
            return nil
        }

        return MainWindowContextBannerContext(
            livePresetID: livePreset.id,
            livePresetName: livePreset.name,
            liveEnvironmentTag: livePreset.environmentTag,
            selectedPresetName: selectedPreset.name,
            selectedEnvironmentTag: selectedPreset.environmentTag,
            title: "当前生效配置已切换，编辑区仍停留在旧草稿",
            message: "现在生效的是“\(livePreset.name)”，你正在编辑“\(selectedPreset.name)”的未保存草稿。继续编辑不会影响当前 live，直到你主动保存并应用。"
        )
    }

    var shouldShowMainWindowContextBanner: Bool {
        mainWindowContextBannerContext != nil
    }

    var targetAppStatusText: String {
        switch targetAppService.availability(for: targetApp) {
        case .running:
            "运行中"
        case .installed:
            "已安装，未运行"
        case .missing:
            "未找到"
        }
    }

    var latestBackupDisplayText: String {
        guard let latestBackup else {
            return "暂无可恢复备份"
        }

        return format(date: latestBackup.createdAt)
    }

    var canExportSelectedPreset: Bool {
        selectedPreset != nil
    }

    var canExportAllPresets: Bool {
        !presets.isEmpty
    }

    var canExportFavoritePresets: Bool {
        !favoritePresets.isEmpty
    }

    var canCreatePresetFromTemplate: Bool {
        !templates.isEmpty
    }

    var isAdvancedEditorMode: Bool {
        presetEditorMode == .advanced
    }

    var favoritePresets: [CodexPreset] {
        favoritePresetIDs.compactMap { favoriteID in
            presets.first(where: { $0.id == favoriteID })
        }
    }

    var recentPresets: [CodexPreset] {
        recentPresetIDs.compactMap { recentID in
            presets.first(where: { $0.id == recentID })
        }
    }

    var recentOperationHistory: [PresetOperationHistoryEntry] {
        Array(operationHistory.prefix(8))
    }

    func filteredPresets(
        from presets: [CodexPreset],
        query: String,
        environmentFilter: PresetEnvironmentTag?,
        sortMode: PresetListSortMode
    ) -> [CodexPreset] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredPresets = presets.filter { preset in
            if let environmentFilter,
               preset.environmentTag != environmentFilter {
                return false
            }

            guard !trimmedQuery.isEmpty else {
                return true
            }

            let haystacks = [
                preset.name,
                preset.environmentTag.title,
                preset.environmentTag.rawValue,
                preset.baseURL,
                preset.model,
                preset.reviewModel,
            ]

            return haystacks.contains { value in
                value.localizedCaseInsensitiveContains(trimmedQuery)
            }
        }

        return sortPresets(filteredPresets, mode: sortMode)
    }

    func bootstrap() {
        do {
            let settings = try settingsStore.loadSettings(defaultPaths: .default)
            self.paths = settings.paths
            self.restartPromptEnabled = settings.restartPromptEnabled
            self.targetApp = settings.targetApp
            self.presets = try presetStore.loadPresets()
            self.selectedPresetID = settings.selectedPresetID
            self.storedLastAppliedPresetID = settings.lastAppliedPresetID
            self.storedLastAppliedAt = settings.lastAppliedAt
            self.favoritePresetIDs = settings.favoritePresetIDs
            self.recentPresetIDs = settings.recentPresetIDs
            self.presetEditorMode = settings.presetEditorMode
            self.operationHistory = Array(settings.operationHistory.prefix(maxOperationHistoryEntries))
            self.favoritePresetIDs.removeAll(where: { favoriteID in
                !presets.contains(where: { $0.id == favoriteID })
            })
            self.recentPresetIDs.removeAll(where: { recentID in
                !presets.contains(where: { $0.id == recentID })
            })
            self.recentAppliedPresetName = presets.first(where: { $0.id == settings.lastAppliedPresetID })?.name

            if let selectedPresetID,
               let selectedPreset = presets.first(where: { $0.id == selectedPresetID }) {
                draft = selectedPreset
            } else if let firstPreset = presets.first {
                draft = firstPreset
                self.selectedPresetID = firstPreset.id
            }

            reloadLiveConfiguration(bootstrapPresetIfNeeded: presets.isEmpty)
            refreshLatestBackupSummary()
        } catch {
            statusMessage = "已使用默认状态启动。"
            errorMessage = error.localizedDescription

            if presets.isEmpty {
                let preset = CodexPreset.sample()
                presets = [preset]
                draft = preset
                selectedPresetID = preset.id
                persistAll()
            }
        }

        do {
            templates = sortTemplatesByName(try templateStore.loadTemplates())
        } catch {
            templates = []
            errorMessage = "模板加载失败：\(error.localizedDescription)"
        }
    }

    func selectPreset(id: UUID?) {
        guard let id else {
            return
        }

        guard id != selectedPresetID else {
            return
        }

        guard let preset = presets.first(where: { $0.id == id }) else {
            return
        }

        if hasUnsavedChanges {
            presetPendingSelection = preset
            recentStatusLine = nil
            statusMessage = "当前草稿有未保存修改，请先决定是保存还是放弃。"
            return
        }

        performPresetSelection(id: id)
    }

    func addBlankPreset() {
        let preset = CodexPreset.sample(name: nextPresetName())
        presets.append(preset)
        draft = preset
        selectedPresetID = preset.id
        recentStatusLine = nil
        statusMessage = "已创建空白预设。"
        persistAll()
    }

    func saveDraftToSelectedPreset() {
        guard let selectedPresetID,
              let index = presets.firstIndex(where: { $0.id == selectedPresetID }) else {
            saveDraftAsNewPreset()
            return
        }

        presets[index] = draft
        updateRecentAppliedPresetNameIfNeeded(for: presets[index])
        recentStatusLine = nil
        statusMessage = "已覆盖当前预设。"
        persistAll()
    }

    func saveDraftAsNewPreset() {
        var newPreset = draft
        newPreset.id = UUID()
        if newPreset.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            newPreset.name = nextPresetName()
        }

        presets.append(newPreset)
        draft = newPreset
        selectedPresetID = newPreset.id
        updateRecentAppliedPresetNameIfNeeded(for: newPreset)
        recentStatusLine = nil
        statusMessage = "已另存为新预设。"
        persistAll()
    }

    func saveDraftAsTemplate() {
        let templateName = uniqueTemplateName(basedOn: resolvedTemplateBaseName(from: draft.name))
        let template = CodexTemplate(preset: draft, name: templateName)

        templates.append(template)
        templates = sortTemplatesByName(templates)
        recentStatusLine = nil
        statusMessage = "已保存为模板：\(template.name)（未包含 API Key）"
        persistTemplates()
    }

    func loadTemplateIntoDraft(id: UUID) {
        guard let template = templates.first(where: { $0.id == id }) else {
            errorMessage = "未找到对应模板。"
            return
        }

        let nextDraft = template.makePreset(
            id: draft.id,
            name: resolvedTemplateDraftName(currentDraftName: draft.name, templateName: template.name)
        )

        draft = nextDraft
        lastConnectionTestResult = nil
        recentStatusLine = nil
        statusMessage = "已将模板载入草稿：\(template.name)。当前预设尚未改写。"
    }

    func createPresetFromTemplate(id: UUID) {
        guard let template = templates.first(where: { $0.id == id }) else {
            errorMessage = "未找到对应模板。"
            return
        }

        let presetName = uniquePresetName(basedOn: resolvedTemplateBaseName(from: template.name))
        let preset = template.makePreset(name: presetName)

        presets.append(preset)
        draft = preset
        selectedPresetID = preset.id
        recentStatusLine = nil
        statusMessage = "已从模板创建新预设：\(preset.name)。请按需补充认证信息。"
        persistAll()
    }

    func overwriteTemplate(id: UUID) {
        guard let index = templates.firstIndex(where: { $0.id == id }) else {
            errorMessage = "未找到对应模板。"
            return
        }

        let preservedName = templates[index].name
        templates[index] = CodexTemplate(id: templates[index].id, preset: draft, name: preservedName)
        templates = sortTemplatesByName(templates)
        recentStatusLine = nil
        statusMessage = "已用当前草稿更新模板：\(preservedName)（未包含 API Key）"
        persistTemplates()
    }

    func renameTemplate(id: UUID, to proposedName: String) {
        guard let index = templates.firstIndex(where: { $0.id == id }) else {
            errorMessage = "未找到对应模板。"
            return
        }

        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "模板名称不能为空。"
            return
        }

        let previousName = templates[index].name
        let resolvedName = uniqueTemplateName(basedOn: trimmedName, excluding: id)
        guard previousName != resolvedName else {
            return
        }

        templates[index].name = resolvedName
        templates = sortTemplatesByName(templates)
        recentStatusLine = nil
        statusMessage = resolvedName == trimmedName
            ? "已重命名模板：\(resolvedName)"
            : "模板重名，已调整为：\(resolvedName)"
        persistTemplates()
    }

    func deleteTemplate(id: UUID) {
        guard let index = templates.firstIndex(where: { $0.id == id }) else {
            errorMessage = "未找到对应模板。"
            return
        }

        let deletedName = templates[index].name
        templates.remove(at: index)
        recentStatusLine = nil
        statusMessage = "已删除模板：\(deletedName)"
        persistTemplates()
    }

    func duplicateSelectedPreset() {
        guard let selectedPreset else {
            errorMessage = "请先选择一个要复制的预设。"
            return
        }

        var duplicatedPreset = selectedPreset
        duplicatedPreset.id = UUID()
        duplicatedPreset.name = uniquePresetName(basedOn: "\(selectedPreset.name) 副本")

        presets.append(duplicatedPreset)
        draft = duplicatedPreset
        selectedPresetID = duplicatedPreset.id
        recentStatusLine = nil
        statusMessage = "已复制当前预设。"
        persistAll()
    }

    func toggleFavoriteSelectedPreset() {
        guard let selectedPresetID else {
            errorMessage = "请先选择一个预设。"
            return
        }

        if favoritePresetIDs.contains(selectedPresetID) {
            favoritePresetIDs.removeAll(where: { $0 == selectedPresetID })
            recentStatusLine = nil
            statusMessage = "已取消收藏当前预设。"
        } else {
            favoritePresetIDs.insert(selectedPresetID, at: 0)
            recentStatusLine = nil
            statusMessage = "已收藏当前预设。"
        }

        persistSettings()
    }

    func isFavoritePreset(id: UUID) -> Bool {
        favoritePresetIDs.contains(id)
    }

    func importPresetsByAppending() {
        importPresetsFromFile(mode: .appendWithRename)
    }

    func importPresetsByReplacingSameName() {
        importPresetsFromFile(mode: .replaceByName)
    }

    private func importPresetsFromFile(mode: PresetImportMode) {
        guard let path = pickerService.pickFile(allowedExtensions: ["json"], startingAt: nil) else {
            return
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let importedPresets = try transferService.importPresets(from: data)
            let importResult = applyImportedPresets(importedPresets, mode: mode)
            recentStatusLine = nil
            if mode == .appendWithRename {
                statusMessage = "已追加导入 \(importResult.totalCount) 个预设。"
            } else {
                statusMessage = "已导入 \(importResult.totalCount) 个预设（新增 \(importResult.addedCount)，覆盖 \(importResult.replacedCount)）。"
            }

            if let selectedID = importResult.firstAffectedPresetID,
               let importedPreset = presets.first(where: { $0.id == selectedID }) {
                selectedPresetID = importedPreset.id
                draft = importedPreset
            }
            persistAll()
        } catch {
            errorMessage = "导入失败：\(error.localizedDescription)"
        }
    }

    func exportSelectedPreset() {
        guard let selectedPreset else {
            errorMessage = "请先选择一个要导出的预设。"
            return
        }

        let defaultFileName = "\(sanitizedFileName(selectedPreset.name)).json"
        guard let path = pickerService.pickSaveFile(defaultFileName: defaultFileName, allowedExtension: "json") else {
            return
        }

        do {
            let data = try transferService.exportPresets([selectedPreset])
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            recentStatusLine = nil
            statusMessage = "已导出预设：\(selectedPreset.name)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportAllPresets() {
        guard !presets.isEmpty else {
            errorMessage = "当前没有可导出的预设。"
            return
        }

        let defaultFileName = "codex-presets-\(exportTimestamp()).json"
        guard let path = pickerService.pickSaveFile(defaultFileName: defaultFileName, allowedExtension: "json") else {
            return
        }

        do {
            let data = try transferService.exportPresets(presets)
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            recentStatusLine = nil
            statusMessage = "已导出全部预设（\(presets.count) 个）。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportFavoritePresets() {
        let favorites = favoritePresets
        guard !favorites.isEmpty else {
            errorMessage = "当前没有可导出的收藏预设。"
            return
        }

        let defaultFileName = "codex-favorite-presets-\(exportTimestamp()).json"
        guard let path = pickerService.pickSaveFile(defaultFileName: defaultFileName, allowedExtension: "json") else {
            return
        }

        do {
            let data = try transferService.exportPresets(favorites)
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            recentStatusLine = nil
            statusMessage = "已导出收藏预设（\(favorites.count) 个）。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSelectedPreset() {
        guard let selectedPresetID,
              let index = presets.firstIndex(where: { $0.id == selectedPresetID }) else {
            return
        }

        presets.remove(at: index)
        if storedLastAppliedPresetID == selectedPresetID {
            storedLastAppliedPresetID = nil
            recentAppliedPresetName = nil
        }
        favoritePresetIDs.removeAll(where: { $0 == selectedPresetID })
        recentPresetIDs.removeAll(where: { $0 == selectedPresetID })

        if let nextPreset = presets.first {
            draft = nextPreset
            self.selectedPresetID = nextPreset.id
        } else {
            let preset = CodexPreset.sample()
            presets = [preset]
            draft = preset
            self.selectedPresetID = preset.id
        }

        statusMessage = "已删除预设。"
        persistAll()
    }

    func requestDeleteSelectedPreset() {
        guard let selectedPreset else {
            return
        }

        presetPendingDeletion = selectedPreset
    }

    func confirmDeleteSelectedPreset() {
        deleteSelectedPreset()
        presetPendingDeletion = nil
    }

    func cancelDeletePreset() {
        presetPendingDeletion = nil
    }

    func loadLiveConfigurationIntoDraft() {
        if let snapshot = lastLoaded {
            var preset = snapshot.preset
            if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                preset.name = nextPresetName()
            } else {
                preset.name = draft.name
            }
            draft = preset
            statusMessage = "已把当前 live 配置载入编辑区。"
        } else {
            reloadLiveConfiguration()
            if let snapshot = lastLoaded {
                draft = snapshot.preset
            }
        }
    }

    func reloadLiveConfiguration(bootstrapPresetIfNeeded: Bool = false) {
        do {
            let snapshot = try fileService.loadSnapshot(paths: paths)
            lastLoaded = snapshot
            recentStatusLine = nil
            statusMessage = "已读取当前 Codex 配置。"

            if bootstrapPresetIfNeeded && presets.isEmpty {
                let preset = snapshot.preset
                presets = [preset]
                draft = preset
                selectedPresetID = preset.id
                persistAll()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        persistSettings()
    }

    func applyDraft() {
        guard validationResult.isValid else {
            let message = validationSummary ?? "当前配置校验未通过，请修正后再试。"
            errorMessage = message
            recordPresetOperation(
                kind: .applyPreset,
                outcome: .failure,
                preset: draft,
                presetID: selectedPresetID,
                detail: message
            )
            persistSettings()
            return
        }

        requestApply(for: draft)
    }

    func confirmPendingPresetApply() {
        guard let preset = presetPendingApplyConfirmation else {
            return
        }

        let source = pendingApplySource
        presetPendingApplyConfirmation = nil
        pendingApplySource = .editor
        performApply(preset, source: source)
    }

    func cancelPendingPresetApply() {
        presetPendingApplyConfirmation = nil
        pendingApplySource = .editor
    }

    func confirmSaveAndSelectPendingPreset() {
        guard let pendingPreset = presetPendingSelection else {
            return
        }

        saveDraftToSelectedPreset()
        clearPendingPresetSelection()
        performPresetSelection(id: pendingPreset.id)
        recentStatusLine = nil
        statusMessage = "已保存当前修改，并切换到：\(pendingPreset.name)"
    }

    func confirmDiscardAndSelectPendingPreset() {
        guard let pendingPreset = presetPendingSelection else {
            return
        }

        clearPendingPresetSelection()
        performPresetSelection(id: pendingPreset.id)
        recentStatusLine = nil
        statusMessage = "已放弃未保存修改，并切换到：\(pendingPreset.name)"
    }

    func cancelPendingPresetSelection() {
        clearPendingPresetSelection()
    }

    private func requestApply(for preset: CodexPreset, source: ApplySource = .editor) {
        if preset.environmentTag.isHighRisk {
            presetPendingApplyConfirmation = preset
            pendingApplySource = source
            recentStatusLine = nil
            statusMessage = "即将切换到高风险环境，请先确认。"
            return
        }

        performApply(preset, source: source)
    }

    private func performApply(_ preset: CodexPreset, source: ApplySource) {
        do {
            let result = try fileService.apply(preset: preset, paths: paths)
            let applyStatusMessage: String
            lastApplied = result
            storedLastAppliedPresetID = matchingPresetID(for: preset)
            storedLastAppliedAt = result.appliedAt
            recentAppliedPresetName = preset.name
            recentStatusLine = "已切换到：\(preset.name) · \(format(date: result.appliedAt))"
            switch source {
            case .editor:
                applyStatusMessage = "已应用预设：\(preset.name)"
            case .menuPreservingDraft:
                applyStatusMessage = "已从菜单栏切换到：\(preset.name)。当前草稿已保留。"
            }
            statusMessage = applyStatusMessage
            if let appliedPresetID = storedLastAppliedPresetID {
                markPresetAsRecentlyUsed(id: appliedPresetID)
            }
            recordPresetOperation(
                kind: .applyPreset,
                outcome: .success,
                preset: preset,
                presetID: storedLastAppliedPresetID,
                detail: "已应用预设并完成配置写入。",
                operatedAt: result.appliedAt
            )
            reloadLiveConfiguration()
            statusMessage = applyStatusMessage
            refreshLatestBackupSummary()
            persistSettings()
            promptToRestartTargetAppIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
            recordPresetOperation(
                kind: .applyPreset,
                outcome: .failure,
                preset: preset,
                presetID: matchingPresetID(for: preset) ?? selectedPresetID,
                detail: error.localizedDescription
            )
            persistSettings()
        }
    }

    func testDraftConnection() {
        guard validationResult.isValid else {
            errorMessage = validationSummary ?? "当前配置校验未通过，请先修正后再测试连接。"
            return
        }

        let preset = draft
        isTestingConnection = true
        lastConnectionTestResult = nil
        recentStatusLine = nil
        statusMessage = "正在测试连接..."

        Task {
            let result = await connectionTestService.testConnection(for: preset)
            await MainActor.run {
                self.isTestingConnection = false
                self.lastConnectionTestResult = result
                self.statusMessage = result.title
            }
        }
    }

    func applyPresetFromMenu(id: UUID) {
        guard let preset = presets.first(where: { $0.id == id }) else {
            return
        }

        if hasUnsavedChanges {
            requestApply(for: preset, source: .menuPreservingDraft)
            return
        }

        performPresetSelection(id: id)
        requestApply(for: preset)
    }

    func revealFile(at path: String) {
        let expandedPath = fileService.expandedPath(path)
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: expandedPath)])
    }

    func revealBackupFolder() {
        do {
            let backupsDirectory = try ApplicationSupportPaths.backupsDirectory()
            NSWorkspace.shared.open(backupsDirectory)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshLatestBackupSummary() {
        do {
            recentBackups = try fileService.listBackupSummaries(limit: 5)
            latestBackup = recentBackups.first
        } catch {
            latestBackup = nil
            recentBackups = []
            errorMessage = error.localizedDescription
        }
    }

    func requestRestoreLatestBackup() {
        refreshLatestBackupSummary()
        guard let latestBackup else {
            errorMessage = "当前还没有可恢复的备份。"
            return
        }

        backupPendingRestore = latestBackup
    }

    func requestRestoreBackup(_ backup: BackupSnapshotSummary) {
        backupPendingRestore = backup
    }

    func confirmRestoreLatestBackup() {
        guard backupPendingRestore != nil else {
            return
        }

        do {
            guard let selectedBackup = backupPendingRestore else {
                return
            }

            let result = try fileService.restoreBackup(selectedBackup, paths: paths)
            backupPendingRestore = nil
            lastApplied = nil
            storedLastAppliedPresetID = nil
            storedLastAppliedAt = nil
            recentAppliedPresetName = nil
            recentStatusLine = "已恢复备份 · \(format(date: result.restoredAt))"
            statusMessage = "已恢复所选备份。"
            reloadLiveConfiguration()
            if let restoredPresetID = livePresetID {
                markPresetAsRecentlyUsed(id: restoredPresetID)
            }
            recordOperation(
                kind: .restoreBackup,
                outcome: .success,
                presetID: livePresetID,
                presetName: resolvedRestoredPresetName(),
                environmentTag: resolvedRestoredEnvironmentTag(),
                detail: "已恢复 \(format(date: selectedBackup.createdAt)) 的备份。",
                operatedAt: result.restoredAt
            )
            refreshLatestBackupSummary()
            persistSettings()
            promptToRestartTargetAppIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
            recordOperation(
                kind: .restoreBackup,
                outcome: .failure,
                presetID: nil,
                presetName: "恢复备份",
                environmentTag: nil,
                detail: error.localizedDescription
            )
            persistSettings()
        }
    }

    func cancelRestoreLatestBackup() {
        backupPendingRestore = nil
    }

    func clearError() {
        errorMessage = nil
    }

    func restartTargetAppNow() {
        Task { @MainActor in
            do {
                try await targetAppService.restart(targetApp)
                statusMessage = "已触发 \(targetApp.displayName) 重启。"
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func chooseConfigFile() {
        guard let path = pickerService.pickFile(allowedExtensions: ["toml"], startingAt: paths.configPath) else {
            return
        }

        paths.configPath = path
        persistSettings()
    }

    func chooseAuthFile() {
        guard let path = pickerService.pickFile(allowedExtensions: ["json"], startingAt: paths.authPath) else {
            return
        }

        paths.authPath = path
        persistSettings()
    }

    func resetPathsToDefault() {
        paths = .default
        recentStatusLine = nil
        statusMessage = "已恢复默认配置文件路径。"
        persistSettings()
    }

    func chooseTargetApplication() {
        guard let target = pickerService.pickApplication(startingAt: targetApp.appPath) else {
            return
        }

        targetApp = target
        persistSettings()
    }

    func resetTargetApplicationToDefault() {
        targetApp = .codex
        recentStatusLine = nil
        statusMessage = "已恢复默认目标应用。"
        persistSettings()
    }

    func setPresetEditorMode(_ mode: PresetEditorMode) {
        guard presetEditorMode != mode else {
            return
        }

        presetEditorMode = mode
        recentStatusLine = nil
        statusMessage = mode == .basic ? "已切换到基础模式。" : "已切换到高级模式。"
        persistSettings()
    }

    func persistSettings() {
        do {
            try settingsStore.saveSettings(
                AppSettings(
                    paths: paths,
                    selectedPresetID: selectedPresetID,
                    restartPromptEnabled: restartPromptEnabled,
                    targetApp: targetApp,
                    lastAppliedPresetID: storedLastAppliedPresetID,
                    lastAppliedAt: storedLastAppliedAt,
                    favoritePresetIDs: favoritePresetIDs,
                    recentPresetIDs: recentPresetIDs,
                    presetEditorMode: presetEditorMode,
                    operationHistory: operationHistory
                )
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persistAll() {
        persistSettings()
        do {
            try presetStore.savePresets(presets)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persistTemplates() {
        do {
            try templateStore.saveTemplates(templates)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performPresetSelection(id: UUID) {
        guard let preset = presets.first(where: { $0.id == id }) else {
            return
        }

        selectedPresetID = id
        draft = preset
        clearPendingPresetSelection()
        persistSettings()
    }

    private func clearPendingPresetSelection() {
        presetPendingSelection = nil
    }

    private func nextPresetName() -> String {
        "预设 \(presets.count + 1)"
    }

    private func matchingPresetID(for preset: CodexPreset) -> UUID? {
        presets.first(where: { $0.managedFingerprint == preset.managedFingerprint })?.id
    }

    private func uniquePresetName(basedOn preferredName: String) -> String {
        let trimmedName = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = trimmedName.isEmpty ? nextPresetName() : trimmedName
        var candidate = fallbackName
        var suffix = 2

        while presets.contains(where: { $0.name == candidate }) {
            candidate = "\(fallbackName) \(suffix)"
            suffix += 1
        }

        return candidate
    }

    private func uniqueTemplateName(basedOn preferredName: String, excluding excludedID: UUID? = nil) -> String {
        let trimmedName = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = trimmedName.isEmpty ? "模板 \(templates.count + 1)" : trimmedName
        var candidate = fallbackName
        var suffix = 2

        while templates.contains(where: { $0.id != excludedID && $0.name == candidate }) {
            candidate = "\(fallbackName) \(suffix)"
            suffix += 1
        }

        return candidate
    }

    private func sortTemplatesByName(_ templates: [CodexTemplate]) -> [CodexTemplate] {
        templates.sorted { lhs, rhs in
            let nameOrder = lhs.name.localizedStandardCompare(rhs.name)
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private func normalizedImportedPreset(_ preset: CodexPreset, existingNames: inout Set<String>) -> CodexPreset {
        var normalizedPreset = preset
        normalizedPreset.id = UUID()
        let baseName = preset.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "导入预设" : preset.name
        var candidate = baseName
        var suffix = 2

        while existingNames.contains(candidate) {
            candidate = "\(baseName) \(suffix)"
            suffix += 1
        }

        existingNames.insert(candidate)
        normalizedPreset.name = candidate
        return normalizedPreset
    }

    private func applyImportedPresets(_ importedPresets: [CodexPreset], mode: PresetImportMode) -> PresetImportResult {
        guard !importedPresets.isEmpty else {
            return PresetImportResult(totalCount: 0, addedCount: 0, replacedCount: 0, firstAffectedPresetID: nil)
        }

        switch mode {
        case .appendWithRename:
            var existingNames = Set(presets.map(\.name))
            let normalizedPresets = importedPresets.map { importedPreset in
                normalizedImportedPreset(importedPreset, existingNames: &existingNames)
            }

            presets.append(contentsOf: normalizedPresets)
            return PresetImportResult(
                totalCount: normalizedPresets.count,
                addedCount: normalizedPresets.count,
                replacedCount: 0,
                firstAffectedPresetID: normalizedPresets.first?.id
            )

        case .replaceByName:
            var addedCount = 0
            var replacedCount = 0
            var firstAffectedPresetID: UUID?
            var nameToIndex: [String: Int] = [:]

            for (index, preset) in presets.enumerated() {
                nameToIndex[preset.name] = index
            }

            for importedPreset in importedPresets {
                let baseName = importedPreset.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "导入预设" : importedPreset.name

                if let existingIndex = nameToIndex[baseName] {
                    var replacement = importedPreset
                    replacement.id = presets[existingIndex].id
                    replacement.name = baseName
                    presets[existingIndex] = replacement
                    replacedCount += 1
                    if firstAffectedPresetID == nil {
                        firstAffectedPresetID = replacement.id
                    }
                } else {
                    var newPreset = importedPreset
                    newPreset.id = UUID()
                    newPreset.name = baseName
                    presets.append(newPreset)
                    nameToIndex[baseName] = presets.count - 1
                    addedCount += 1
                    if firstAffectedPresetID == nil {
                        firstAffectedPresetID = newPreset.id
                    }
                }
            }

            return PresetImportResult(
                totalCount: importedPresets.count,
                addedCount: addedCount,
                replacedCount: replacedCount,
                firstAffectedPresetID: firstAffectedPresetID
            )
        }
    }

    private struct PresetImportResult {
        var totalCount: Int
        var addedCount: Int
        var replacedCount: Int
        var firstAffectedPresetID: UUID?
    }

    private func sanitizedFileName(_ value: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = value.components(separatedBy: invalidCharacters).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "codex-preset" : cleaned
    }

    private func exportTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: .now)
    }

    private func markPresetAsRecentlyUsed(id: UUID) {
        recentPresetIDs.removeAll(where: { $0 == id })
        recentPresetIDs.insert(id, at: 0)
        recentPresetIDs = Array(recentPresetIDs.prefix(5))
    }

    private func sortPresets(_ presets: [CodexPreset], mode: PresetListSortMode) -> [CodexPreset] {
        switch mode {
        case .recentUsage:
            return presets.sorted(by: comparePresetsByRecentUsage)
        case .nameAscending:
            return presets.sorted(by: comparePresetsByName)
        }
    }

    private func comparePresetsByRecentUsage(_ lhs: CodexPreset, _ rhs: CodexPreset) -> Bool {
        let lhsDate = lastSuccessfulOperationDate(for: lhs.id)
        let rhsDate = lastSuccessfulOperationDate(for: rhs.id)

        if lhsDate != rhsDate {
            switch (lhsDate, rhsDate) {
            case let (.some(lhsDate), .some(rhsDate)):
                return lhsDate > rhsDate
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }
        }

        let lhsRecentIndex = recentPresetIDs.firstIndex(of: lhs.id)
        let rhsRecentIndex = recentPresetIDs.firstIndex(of: rhs.id)
        if lhsRecentIndex != rhsRecentIndex {
            switch (lhsRecentIndex, rhsRecentIndex) {
            case let (.some(lhsIndex), .some(rhsIndex)):
                return lhsIndex < rhsIndex
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }
        }

        return comparePresetsByName(lhs, rhs)
    }

    private func comparePresetsByName(_ lhs: CodexPreset, _ rhs: CodexPreset) -> Bool {
        let nameOrder = lhs.name.localizedStandardCompare(rhs.name)
        if nameOrder != .orderedSame {
            return nameOrder == .orderedAscending
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func lastSuccessfulOperationDate(for presetID: UUID) -> Date? {
        operationHistory.first(where: { entry in
            entry.outcome == .success && entry.presetID == presetID
        })?.operatedAt
    }

    private func recordPresetOperation(
        kind: PresetOperationKind,
        outcome: PresetOperationOutcome,
        preset: CodexPreset,
        presetID: UUID?,
        detail: String,
        operatedAt: Date = .now
    ) {
        recordOperation(
            kind: kind,
            outcome: outcome,
            presetID: presetID ?? matchingPresetID(for: preset),
            presetName: resolvedPresetName(for: preset),
            environmentTag: preset.environmentTag,
            detail: detail,
            operatedAt: operatedAt
        )
    }

    private func recordOperation(
        kind: PresetOperationKind,
        outcome: PresetOperationOutcome,
        presetID: UUID?,
        presetName: String,
        environmentTag: PresetEnvironmentTag?,
        detail: String,
        operatedAt: Date = .now
    ) {
        let entry = PresetOperationHistoryEntry(
            operatedAt: operatedAt,
            kind: kind,
            outcome: outcome,
            presetID: presetID,
            presetName: presetName,
            environmentTag: environmentTag,
            detail: detail
        )

        operationHistory.insert(entry, at: 0)
        operationHistory = Array(operationHistory.prefix(maxOperationHistoryEntries))
    }

    private func updateRecentAppliedPresetNameIfNeeded(for preset: CodexPreset) {
        guard storedLastAppliedPresetID == preset.id else {
            return
        }

        recentAppliedPresetName = preset.name
    }

    private func promptToRestartTargetAppIfNeeded() {
        guard restartPromptEnabled else {
            return
        }

        let availability = targetAppService.availability(for: targetApp)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "配置已经生效"

        switch availability {
        case .running:
            alert.informativeText = "是否现在自动重启 \(targetApp.displayName)？新的配置会在重启后立即生效。"
            alert.addButton(withTitle: "立即重启")
            alert.addButton(withTitle: "稍后")

            if alert.runModal() == .alertFirstButtonReturn {
                restartTargetAppNow()
            } else {
                statusMessage = "配置已应用，你可以稍后手动重启 \(targetApp.displayName)。"
            }
        case .installed:
            alert.informativeText = "\(targetApp.displayName) 当前未运行。是否现在自动启动它？"
            alert.addButton(withTitle: "立即启动")
            alert.addButton(withTitle: "稍后")

            if alert.runModal() == .alertFirstButtonReturn {
                restartTargetAppNow()
            } else {
                statusMessage = "配置已应用，\(targetApp.displayName) 尚未启动。"
            }
        case .missing:
            alert.informativeText = "没有找到 \(targetApp.displayName) 应用，已完成配置写入。你可以稍后手动打开目标软件。"
            alert.addButton(withTitle: "知道了")
            _ = alert.runModal()
            statusMessage = "配置已应用，但未找到 \(targetApp.displayName) 应用。"
        }
    }

    private func resolvedPresetName(for preset: CodexPreset) -> String {
        let trimmedName = preset.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "未命名预设" : trimmedName
    }

    private func resolvedTemplateDraftName(currentDraftName: String, templateName: String) -> String {
        let trimmedCurrentName = currentDraftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCurrentName.isEmpty {
            return trimmedCurrentName
        }

        return resolvedTemplateBaseName(from: templateName)
    }

    private func resolvedTemplateBaseName(from rawName: String) -> String {
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "模板" : trimmedName
    }

    private func resolvedRestoredPresetName() -> String {
        if let livePresetID,
           let preset = presets.first(where: { $0.id == livePresetID }) {
            return preset.name
        }

        if let baseURL = lastLoaded?.preset.baseURL,
           !baseURL.isEmpty {
            return "恢复到当前 live 配置"
        }

        return "恢复备份"
    }

    private func resolvedRestoredEnvironmentTag() -> PresetEnvironmentTag? {
        if let livePresetID,
           let preset = presets.first(where: { $0.id == livePresetID }) {
            return preset.environmentTag
        }

        return lastLoaded?.preset.environmentTag
    }

    private func format(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
