import AppKit
import CodexConfigSwitcherCore
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var presets: [CodexPreset] = []
    @Published var draft: CodexPreset = .sample()
    @Published var selectedPresetID: UUID?
    @Published var paths: AppPaths = .default
    @Published var restartPromptEnabled = true
    @Published var targetApp: ManagedAppTarget = .codex
    @Published var statusMessage = "准备就绪"
    @Published var errorMessage: String?
    @Published var lastLoaded: LiveConfigurationSnapshot?
    @Published var lastApplied: ApplyResult?

    private let fileService: CodexFileService
    private let presetStore: PresetStore
    private let settingsStore: SettingsStore
    private let targetAppService = TargetAppService()

    init() {
        do {
            self.fileService = try CodexFileService()
            self.presetStore = try PresetStore()
            self.settingsStore = try SettingsStore()
        } catch {
            fatalError("无法初始化存储目录：\(error.localizedDescription)")
        }

        bootstrap()
    }

    var compactStatusLine: String? {
        if let lastApplied {
            return "最近应用：\(format(date: lastApplied.appliedAt))"
        }

        if let lastLoaded {
            return "最近读取：\(format(date: lastLoaded.loadedAt))"
        }

        return statusMessage.isEmpty ? nil : statusMessage
    }

    func bootstrap() {
        do {
            let settings = try settingsStore.loadSettings(defaultPaths: .default)
            self.paths = settings.paths
            self.restartPromptEnabled = settings.restartPromptEnabled
            self.targetApp = settings.targetApp
            self.presets = try presetStore.loadPresets()
            self.selectedPresetID = settings.selectedPresetID

            if let selectedPresetID,
               let selectedPreset = presets.first(where: { $0.id == selectedPresetID }) {
                draft = selectedPreset
            } else if let firstPreset = presets.first {
                draft = firstPreset
                self.selectedPresetID = firstPreset.id
            }

            reloadLiveConfiguration(bootstrapPresetIfNeeded: presets.isEmpty)
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
    }

    func selectPreset(id: UUID?) {
        selectedPresetID = id
        if let id, let preset = presets.first(where: { $0.id == id }) {
            draft = preset
        }
        persistSettings()
    }

    func addBlankPreset() {
        let preset = CodexPreset.sample(name: nextPresetName())
        presets.append(preset)
        draft = preset
        selectedPresetID = preset.id
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
        statusMessage = "已另存为新预设。"
        persistAll()
    }

    func deleteSelectedPreset() {
        guard let selectedPresetID,
              let index = presets.firstIndex(where: { $0.id == selectedPresetID }) else {
            return
        }

        presets.remove(at: index)

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
        do {
            let result = try fileService.apply(preset: draft, paths: paths)
            lastApplied = result
            statusMessage = "已写入 Codex 配置，并创建备份。"
            reloadLiveConfiguration()
            promptToRestartTargetAppIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyPresetFromMenu(id: UUID) {
        selectPreset(id: id)
        applyDraft()
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

    func persistSettings() {
        do {
            try settingsStore.saveSettings(
                AppSettings(
                    paths: paths,
                    selectedPresetID: selectedPresetID,
                    restartPromptEnabled: restartPromptEnabled,
                    targetApp: targetApp
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

    private func nextPresetName() -> String {
        "预设 \(presets.count + 1)"
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

    private func format(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
