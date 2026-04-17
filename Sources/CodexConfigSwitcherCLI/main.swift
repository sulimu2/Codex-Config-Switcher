import CodexConfigSwitcherCore
import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif os(Windows)
import ucrt
#endif

@main
struct CodexConfigSwitcherCLI {
    static func main() {
        do {
            let command = try CLICommand.parse(arguments: Array(CommandLine.arguments.dropFirst()))
            var workspace = try CLIWorkspace()
            try command.run(in: &workspace)
        } catch let error as CLIError {
            fputs("错误：\(error.localizedDescription)\n", stderr)
            if error.showsUsage {
                print(CLICommand.usageText)
            }
            Foundation.exit(EXIT_FAILURE)
        } catch {
            fputs("错误：\(error.localizedDescription)\n", stderr)
            Foundation.exit(EXIT_FAILURE)
        }
    }
}

private enum CLICommand {
    case help
    case status(asJSON: Bool)
    case listPresets
    case apply(presetName: String, restartTargetApp: Bool)
    case captureLive(name: String)
    case listTemplates
    case saveTemplate(presetName: String, templateName: String?)
    case createFromTemplate(templateName: String, presetName: String?)
    case targetStatus(asJSON: Bool)
    case targetSetPath(path: String)
    case targetReset
    case targetRestart

    static var usageText: String {
        """
        Codex Config Switcher CLI

        用法：
          swift run CodexConfigSwitcherCLI status [--json]
          swift run CodexConfigSwitcherCLI list-presets
          swift run CodexConfigSwitcherCLI apply --preset <名称> [--restart]
          swift run CodexConfigSwitcherCLI capture-live --name <名称>
          swift run CodexConfigSwitcherCLI list-templates
          swift run CodexConfigSwitcherCLI save-template --preset <预设名称> [--name <模板名称>]
          swift run CodexConfigSwitcherCLI create-from-template --template <模板名称> [--name <新预设名称>]
          swift run CodexConfigSwitcherCLI target status [--json]
          swift run CodexConfigSwitcherCLI target set-path --path <Codex.exe 或 App 路径>
          swift run CodexConfigSwitcherCLI target reset
          swift run CodexConfigSwitcherCLI target restart

        说明：
          - CLI 会复用当前平台的默认 `~/.codex` 路径与 `settings.json / presets.json / templates.json` 存储。
          - macOS 下可与桌面版共享同一套数据；Windows 当前版本先以 CLI 形式提供核心工作流与目标应用管理。
        """
    }

    static func parse(arguments: [String]) throws -> CLICommand {
        guard let first = arguments.first else {
            return .help
        }

        let remainingArguments = Array(arguments.dropFirst())

        switch first {
        case "help", "--help", "-h":
            return .help
        case "status":
            return .status(asJSON: containsFlag("--json", in: remainingArguments))
        case "list-presets":
            return .listPresets
        case "apply":
            return .apply(
                presetName: try optionValue("--preset", in: remainingArguments),
                restartTargetApp: containsFlag("--restart", in: remainingArguments)
            )
        case "capture-live":
            return .captureLive(name: try optionValue("--name", in: remainingArguments))
        case "list-templates":
            return .listTemplates
        case "save-template":
            return .saveTemplate(
                presetName: try optionValue("--preset", in: remainingArguments),
                templateName: optionalValue("--name", in: remainingArguments)
            )
        case "create-from-template":
            return .createFromTemplate(
                templateName: try optionValue("--template", in: remainingArguments),
                presetName: optionalValue("--name", in: remainingArguments)
            )
        case "target":
            return try parseTargetCommand(arguments: remainingArguments)
        default:
            throw CLIError.unknownCommand(first)
        }
    }

    func run(in workspace: inout CLIWorkspace) throws {
        switch self {
        case .help:
            print(Self.usageText)
        case .status(let asJSON):
            try printStatus(using: workspace, asJSON: asJSON)
        case .listPresets:
            printPresets(using: workspace)
        case .apply(let presetName, let restartTargetApp):
            try applyPreset(named: presetName, restartTargetApp: restartTargetApp, using: &workspace)
        case .captureLive(let name):
            try captureLive(named: name, using: &workspace)
        case .listTemplates:
            printTemplates(using: workspace)
        case .saveTemplate(let presetName, let templateName):
            try saveTemplate(fromPresetNamed: presetName, templateName: templateName, using: &workspace)
        case .createFromTemplate(let templateName, let presetName):
            try createPreset(fromTemplateNamed: templateName, presetName: presetName, using: &workspace)
        case .targetStatus(let asJSON):
            try printTargetStatus(using: workspace, asJSON: asJSON)
        case .targetSetPath(let path):
            try setTargetPath(path, using: &workspace)
        case .targetReset:
            try resetTargetApp(using: &workspace)
        case .targetRestart:
            try restartTargetApp(using: workspace)
        }
    }

    private func printStatus(using workspace: CLIWorkspace, asJSON: Bool) throws {
        let snapshot = try workspace.fileService.loadSnapshot(paths: workspace.settings.paths)
        let livePresetName = workspace.presets.first(where: {
            $0.managedFingerprint == snapshot.preset.managedFingerprint
        })?.name ?? "未匹配到已保存预设"
        let targetAvailability = workspace.runtimeService.availability(for: workspace.settings.targetApp)
        var sanitizedLivePreset = snapshot.preset
        sanitizedLivePreset.apiKey = ""

        if asJSON {
            try printJSON(
                CLIStatusPayload(
                    platform: platformName,
                    configPath: workspace.settings.paths.configPath,
                    authPath: workspace.settings.paths.authPath,
                    presetCount: workspace.presets.count,
                    templateCount: workspace.templates.count,
                    livePreset: sanitizedLivePreset,
                    matchedPresetName: livePresetName,
                    lastAppliedAt: workspace.settings.lastAppliedAt,
                    targetApp: workspace.settings.targetApp,
                    targetAvailability: targetAvailability.rawValue,
                    targetAvailabilityTitle: targetAvailability.title
                )
            )
            return
        }

        print("平台：\(platformName)")
        print("config.toml：\(workspace.settings.paths.configPath)")
        print("auth.json：\(workspace.settings.paths.authPath)")
        print("已保存预设：\(workspace.presets.count)")
        print("已保存模板：\(workspace.templates.count)")
        print("当前 live：\(snapshot.preset.environmentTag.title) | \(snapshot.preset.baseURL) | \(snapshot.preset.model)")
        print("匹配预设：\(livePresetName)")
        print("目标应用：\(workspace.settings.targetApp.displayName)")
        print("目标路径：\(workspace.settings.targetApp.appPath)")
        print("目标状态：\(targetAvailability.title)")

        if let lastAppliedAt = workspace.settings.lastAppliedAt {
            print("最近应用：\(iso8601String(from: lastAppliedAt))")
        }
    }

    private func printPresets(using workspace: CLIWorkspace) {
        guard !workspace.presets.isEmpty else {
            print("当前还没有已保存预设。")
            return
        }

        for preset in workspace.presets {
            let selectedMarker = workspace.settings.selectedPresetID == preset.id ? "*" : "-"
            print("\(selectedMarker) \(preset.name) | \(preset.environmentTag.title) | \(preset.baseURL) | \(preset.model)")
        }
    }

    private func applyPreset(
        named presetName: String,
        restartTargetApp: Bool,
        using workspace: inout CLIWorkspace
    ) throws {
        let preset = try workspace.requirePreset(named: presetName)
        let result = try workspace.fileService.apply(preset: preset, paths: workspace.settings.paths)

        workspace.settings.selectedPresetID = preset.id
        workspace.settings.lastAppliedPresetID = preset.id
        workspace.settings.lastAppliedAt = result.appliedAt
        workspace.settings.recentPresetIDs = moveIDToFront(preset.id, in: workspace.settings.recentPresetIDs)
        try workspace.saveSettings()

        print("已应用预设：\(preset.name)")
        print("接口地址：\(preset.baseURL)")
        print("模型：\(preset.model)")
        if let configBackupPath = result.configBackupPath {
            print("config 备份：\(configBackupPath)")
        }
        if let authBackupPath = result.authBackupPath {
            print("auth 备份：\(authBackupPath)")
        }

        if restartTargetApp {
            try workspace.runtimeService.restart(workspace.settings.targetApp)
            print("已重启目标应用：\(workspace.settings.targetApp.displayName)")
        }
    }

    private func captureLive(named name: String, using workspace: inout CLIWorkspace) throws {
        let snapshot = try workspace.fileService.loadSnapshot(paths: workspace.settings.paths)
        var preset = snapshot.preset
        preset.id = UUID()
        preset.name = uniqueName(basedOn: name, existingNames: workspace.presets.map(\.name))

        workspace.presets.append(preset)
        workspace.settings.selectedPresetID = preset.id
        try workspace.savePresets()
        try workspace.saveSettings()

        print("已从 live 配置生成预设：\(preset.name)")
    }

    private func printTemplates(using workspace: CLIWorkspace) {
        guard !workspace.templates.isEmpty else {
            print("当前还没有模板。")
            return
        }

        for template in workspace.templates {
            print("- \(template.name) | \(template.environmentTag.title) | \(template.baseURL) | \(template.model)")
        }
    }

    private func saveTemplate(
        fromPresetNamed presetName: String,
        templateName: String?,
        using workspace: inout CLIWorkspace
    ) throws {
        let preset = try workspace.requirePreset(named: presetName)
        let resolvedTemplateName = uniqueName(
            basedOn: templateName ?? preset.name,
            existingNames: workspace.templates.map(\.name)
        )
        let template = CodexTemplate(preset: preset, name: resolvedTemplateName)

        workspace.templates.append(template)
        workspace.templates.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        try workspace.saveTemplates()

        print("已保存模板：\(template.name)")
    }

    private func createPreset(
        fromTemplateNamed templateName: String,
        presetName: String?,
        using workspace: inout CLIWorkspace
    ) throws {
        let template = try workspace.requireTemplate(named: templateName)
        let resolvedPresetName = uniqueName(
            basedOn: presetName ?? template.name,
            existingNames: workspace.presets.map(\.name)
        )
        let preset = template.makePreset(name: resolvedPresetName)

        workspace.presets.append(preset)
        workspace.settings.selectedPresetID = preset.id
        try workspace.savePresets()
        try workspace.saveSettings()

        print("已从模板创建预设：\(preset.name)")
    }

    private func printTargetStatus(using workspace: CLIWorkspace, asJSON: Bool) throws {
        let target = workspace.settings.targetApp
        let status = workspace.runtimeService.availability(for: target)

        if asJSON {
            try printJSON(
                CLITargetStatusPayload(
                    targetApp: target,
                    availability: status.rawValue,
                    availabilityTitle: status.title
                )
            )
            return
        }

        print("目标应用：\(target.displayName)")
        print("Bundle ID：\(target.bundleIdentifier.isEmpty ? "未配置" : target.bundleIdentifier)")
        print("应用路径：\(target.appPath)")
        print("状态：\(status.title)")
    }

    private func setTargetPath(_ path: String, using workspace: inout CLIWorkspace) throws {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            throw CLIError.missingOption("--path")
        }

        let displayName = inferredDisplayName(from: trimmedPath) ?? workspace.settings.targetApp.displayName
        workspace.settings.targetApp = ManagedAppTarget(
            displayName: displayName,
            bundleIdentifier: "",
            appPath: trimmedPath
        )
        try workspace.saveSettings()

        print("已更新目标应用路径：\(trimmedPath)")
        print("当前状态：\(workspace.runtimeService.availability(for: workspace.settings.targetApp).title)")
    }

    private func resetTargetApp(using workspace: inout CLIWorkspace) throws {
        workspace.settings.targetApp = .codex
        try workspace.saveSettings()

        print("已恢复默认目标应用：\(workspace.settings.targetApp.appPath)")
        print("当前状态：\(workspace.runtimeService.availability(for: workspace.settings.targetApp).title)")
    }

    private func restartTargetApp(using workspace: CLIWorkspace) throws {
        try workspace.runtimeService.restart(workspace.settings.targetApp)
        print("已重启目标应用：\(workspace.settings.targetApp.displayName)")
    }

    private static func parseTargetCommand(arguments: [String]) throws -> CLICommand {
        guard let action = arguments.first else {
            throw CLIError.missingOption("target <status|set-path|reset|restart>")
        }

        let remainingArguments = Array(arguments.dropFirst())
        switch action {
        case "status":
            return .targetStatus(asJSON: containsFlag("--json", in: remainingArguments))
        case "set-path":
            return .targetSetPath(path: try optionValue("--path", in: remainingArguments))
        case "reset":
            return .targetReset
        case "restart":
            return .targetRestart
        default:
            throw CLIError.unknownCommand("target \(action)")
        }
    }
}

private struct CLIWorkspace {
    let fileService: CodexFileService
    let presetStore: PresetStore
    let settingsStore: SettingsStore
    let templateStore: TemplateStore
    let runtimeService: ManagedAppRuntimeService
    var settings: AppSettings
    var presets: [CodexPreset]
    var templates: [CodexTemplate]

    init() throws {
        let fileService = try CodexFileService()
        let presetStore = try PresetStore()
        let settingsStore = try SettingsStore()
        let templateStore = try TemplateStore()
        let runtimeService = ManagedAppRuntimeService()
        let settings = try settingsStore.loadSettings(defaultPaths: .default)
        let presets = try presetStore.loadPresets()
        let templates = try templateStore.loadTemplates()

        self.fileService = fileService
        self.presetStore = presetStore
        self.settingsStore = settingsStore
        self.templateStore = templateStore
        self.runtimeService = runtimeService
        self.settings = settings
        self.presets = presets
        self.templates = templates
    }

    mutating func savePresets() throws {
        try presetStore.savePresets(presets)
    }

    mutating func saveTemplates() throws {
        try templateStore.saveTemplates(templates)
    }

    mutating func saveSettings() throws {
        try settingsStore.saveSettings(settings)
    }

    func requirePreset(named name: String) throws -> CodexPreset {
        guard let preset = presets.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) else {
            throw CLIError.missingPreset(name)
        }

        return preset
    }

    func requireTemplate(named name: String) throws -> CodexTemplate {
        guard let template = templates.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) else {
            throw CLIError.missingTemplate(name)
        }

        return template
    }
}

private enum CLIError: LocalizedError {
    case unknownCommand(String)
    case missingOption(String)
    case missingPreset(String)
    case missingTemplate(String)
    case unexpectedOutputEncoding

    var showsUsage: Bool {
        switch self {
        case .unknownCommand, .missingOption:
            return true
        case .missingPreset, .missingTemplate, .unexpectedOutputEncoding:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .unknownCommand(let command):
            "不支持的命令：\(command)"
        case .missingOption(let option):
            "缺少必填参数：\(option)"
        case .missingPreset(let name):
            "没有找到名为“\(name)”的预设。"
        case .missingTemplate(let name):
            "没有找到名为“\(name)”的模板。"
        case .unexpectedOutputEncoding:
            "CLI 输出编码失败。"
        }
    }
}

private func optionValue(_ name: String, in arguments: [String]) throws -> String {
    guard let index = arguments.firstIndex(of: name),
          arguments.indices.contains(arguments.index(after: index)) else {
        throw CLIError.missingOption(name)
    }

    return arguments[arguments.index(after: index)]
}

private func optionalValue(_ name: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: name),
          arguments.indices.contains(arguments.index(after: index)) else {
        return nil
    }

    return arguments[arguments.index(after: index)]
}

private func containsFlag(_ name: String, in arguments: [String]) -> Bool {
    arguments.contains(name)
}

private func uniqueName(basedOn preferredName: String, existingNames: [String]) -> String {
    let trimmedName = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
    let fallbackName = trimmedName.isEmpty ? "未命名" : trimmedName
    var candidate = fallbackName
    var suffix = 2

    while existingNames.contains(where: { $0 == candidate }) {
        candidate = "\(fallbackName) \(suffix)"
        suffix += 1
    }

    return candidate
}

private func moveIDToFront(_ id: UUID, in currentIDs: [UUID]) -> [UUID] {
    var updated = currentIDs.filter { $0 != id }
    updated.insert(id, at: 0)
    return Array(updated.prefix(20))
}

private func iso8601String(from date: Date) -> String {
    ISO8601DateFormatter().string(from: date)
}

private func printJSON<Value: Encodable>(_ value: Value) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(value)
    guard let text = String(data: data, encoding: .utf8) else {
        throw CLIError.unexpectedOutputEncoding
    }

    print(text)
}

private func inferredDisplayName(from path: String) -> String? {
    let separators = CharacterSet(charactersIn: "/\\")
    let fileName = path.components(separatedBy: separators).last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !fileName.isEmpty else {
        return nil
    }

    if fileName.lowercased().hasSuffix(".exe") || fileName.lowercased().hasSuffix(".app") {
        return String(fileName.dropLast(4))
    }

    return fileName
}

private var platformName: String {
#if os(macOS)
    "macOS"
#elseif os(Windows)
    "Windows"
#elseif os(Linux)
    "Linux"
#else
    "Unknown"
#endif
}

private struct CLIStatusPayload: Encodable {
    let platform: String
    let configPath: String
    let authPath: String
    let presetCount: Int
    let templateCount: Int
    let livePreset: CodexPreset
    let matchedPresetName: String
    let lastAppliedAt: Date?
    let targetApp: ManagedAppTarget
    let targetAvailability: String
    let targetAvailabilityTitle: String
}

private struct CLITargetStatusPayload: Encodable {
    let targetApp: ManagedAppTarget
    let availability: String
    let availabilityTitle: String
}
