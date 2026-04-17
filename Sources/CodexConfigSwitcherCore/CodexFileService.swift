import Foundation

public struct CodexFileService {
    private let fileManager: FileManager
    private let appSupportDirectory: URL

    public init(fileManager: FileManager = .default, appSupportDirectory: URL? = nil) throws {
        self.fileManager = fileManager
        if let appSupportDirectory {
            self.appSupportDirectory = appSupportDirectory
            try fileManager.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
        } else {
            self.appSupportDirectory = try ApplicationSupportPaths.rootDirectory(fileManager: fileManager)
        }
    }

    public func loadSnapshot(paths: AppPaths) throws -> LiveConfigurationSnapshot {
        let configURL = expandedURL(for: paths.configPath)
        let authURL = expandedURL(for: paths.authPath)

        guard fileManager.fileExists(atPath: configURL.path) else {
            throw ConfigSwitchError.fileMissing("找不到 config.toml：\(configURL.path)")
        }

        guard fileManager.fileExists(atPath: authURL.path) else {
            throw ConfigSwitchError.fileMissing("找不到 auth.json：\(authURL.path)")
        }

        let configText = try String(contentsOf: configURL, encoding: .utf8)
        let authData = try Data(contentsOf: authURL)

        let parsedConfig = parseConfigText(configText)
        let authObject = try parseAuthData(authData)

        let preset = CodexPreset(
            name: "当前配置",
            environmentTag: PresetEnvironmentTag.infer(from: parsedConfig.openAI["base_url"] ?? ""),
            modelProvider: parsedConfig.topLevel["model_provider"] ?? "OpenAI",
            model: parsedConfig.topLevel["model"] ?? "gpt-5.4",
            reviewModel: parsedConfig.topLevel["review_model"] ?? "gpt-5.4",
            modelReasoningEffort: parsedConfig.topLevel["model_reasoning_effort"] ?? "xhigh",
            disableResponseStorage: boolValue(parsedConfig.topLevel["disable_response_storage"], default: true),
            networkAccess: parsedConfig.topLevel["network_access"] ?? "enabled",
            windowsWSLSetupAcknowledged: boolValue(parsedConfig.topLevel["windows_wsl_setup_acknowledged"], default: true),
            modelContextWindow: intValue(parsedConfig.topLevel["model_context_window"], default: 1_000_000),
            modelAutoCompactTokenLimit: intValue(parsedConfig.topLevel["model_auto_compact_token_limit"], default: 900_000),
            requestMaxRetries: optionalIntValue(parsedConfig.topLevel["request_max_retries"]),
            streamMaxRetries: optionalIntValue(parsedConfig.topLevel["stream_max_retries"]),
            streamIdleTimeoutMs: optionalIntValue(parsedConfig.topLevel["stream_idle_timeout_ms"]),
            providerName: parsedConfig.openAI["name"] ?? "OpenAI",
            baseURL: parsedConfig.openAI["base_url"] ?? "",
            wireAPI: parsedConfig.openAI["wire_api"] ?? "responses",
            requiresOpenAIAuth: boolValue(parsedConfig.openAI["requires_openai_auth"], default: true),
            authMode: authObject["auth_mode"] as? String ?? "apikey",
            apiKey: authObject["OPENAI_API_KEY"] as? String ?? ""
        )

        return LiveConfigurationSnapshot(preset: preset)
    }

    public func apply(preset: CodexPreset, paths: AppPaths) throws -> ApplyResult {
        let configURL = expandedURL(for: paths.configPath)
        let authURL = expandedURL(for: paths.authPath)

        try ensureParentDirectory(for: configURL)
        try ensureParentDirectory(for: authURL)

        let configText = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        let authData = (try? Data(contentsOf: authURL)) ?? Data("{}".utf8)

        let updatedConfigText = updateConfigText(configText, using: preset)
        let updatedAuthData = try updateAuthData(authData, using: preset)

        let backupDirectory = try createBackupDirectory()
        let configBackupPath = try backupIfNeeded(sourceURL: configURL, destinationURL: backupDirectory.appendingPathComponent("config.toml"))
        let authBackupPath = try backupIfNeeded(sourceURL: authURL, destinationURL: backupDirectory.appendingPathComponent("auth.json"))

        try updatedConfigText.write(to: configURL, atomically: true, encoding: .utf8)
        try updatedAuthData.write(to: authURL, options: .atomic)

        return ApplyResult(
            configBackupPath: configBackupPath,
            authBackupPath: authBackupPath
        )
    }

    public func latestBackupSummary() throws -> BackupSnapshotSummary? {
        try listBackupSummaries(limit: 1).first
    }

    public func restoreLatestBackup(paths: AppPaths) throws -> RestoreResult {
        guard let latestBackup = try latestBackupSummary() else {
            throw ConfigSwitchError.fileMissing("没有找到可恢复的备份。")
        }

        return try restoreBackup(latestBackup, paths: paths)
    }

    public func listBackupSummaries(limit: Int? = nil) throws -> [BackupSnapshotSummary] {
        let summaries = try backupDirectories()
            .compactMap { try backupSummary(for: $0) }
            .sorted(by: { $0.createdAt > $1.createdAt })

        if let limit {
            return Array(summaries.prefix(limit))
        }

        return summaries
    }

    public func restoreBackup(_ backup: BackupSnapshotSummary, paths: AppPaths) throws -> RestoreResult {
        let configURL = expandedURL(for: paths.configPath)
        let authURL = expandedURL(for: paths.authPath)

        try ensureParentDirectory(for: configURL)
        try ensureParentDirectory(for: authURL)

        let rollbackDirectory = try createBackupDirectory()
        let rollbackConfigBackupPath = try backupIfNeeded(
            sourceURL: configURL,
            destinationURL: rollbackDirectory.appendingPathComponent("config.toml")
        )
        let rollbackAuthBackupPath = try backupIfNeeded(
            sourceURL: authURL,
            destinationURL: rollbackDirectory.appendingPathComponent("auth.json")
        )

        if let configBackupPath = backup.configBackupPath {
            let sourceURL = URL(fileURLWithPath: configBackupPath)
            if fileManager.fileExists(atPath: configURL.path) {
                try fileManager.removeItem(at: configURL)
            }
            try fileManager.copyItem(at: sourceURL, to: configURL)
        }

        if let authBackupPath = backup.authBackupPath {
            let sourceURL = URL(fileURLWithPath: authBackupPath)
            if fileManager.fileExists(atPath: authURL.path) {
                try fileManager.removeItem(at: authURL)
            }
            try fileManager.copyItem(at: sourceURL, to: authURL)
        }

        return RestoreResult(
            sourceBackupDirectoryPath: backup.directoryPath,
            rollbackConfigBackupPath: rollbackConfigBackupPath,
            rollbackAuthBackupPath: rollbackAuthBackupPath
        )
    }

    public func expandedPath(_ path: String) -> String {
        expandedURL(for: path).path
    }

    private func ensureParentDirectory(for url: URL) throws {
        let parent = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
    }

    private func createBackupDirectory() throws -> URL {
        let backupsRoot = appSupportDirectory.appendingPathComponent("Backups", isDirectory: true)
        try fileManager.createDirectory(at: backupsRoot, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: .now)
        var directory = backupsRoot.appendingPathComponent(timestamp, isDirectory: true)
        var suffix = 1

        while fileManager.fileExists(atPath: directory.path) {
            directory = backupsRoot.appendingPathComponent("\(timestamp)-\(suffix)", isDirectory: true)
            suffix += 1
        }

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func backupIfNeeded(sourceURL: URL, destinationURL: URL) throws -> String? {
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            return nil
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL.path
    }

    private func backupDirectories() throws -> [URL] {
        let backupsRoot = appSupportDirectory.appendingPathComponent("Backups", isDirectory: true)
        guard fileManager.fileExists(atPath: backupsRoot.path) else {
            return []
        }

        return try fileManager.contentsOfDirectory(
            at: backupsRoot,
            includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ).filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
    }

    private func backupSummary(for directory: URL) throws -> BackupSnapshotSummary? {
        let configBackupURL = directory.appendingPathComponent("config.toml")
        let authBackupURL = directory.appendingPathComponent("auth.json")
        let configExists = fileManager.fileExists(atPath: configBackupURL.path)
        let authExists = fileManager.fileExists(atPath: authBackupURL.path)

        guard configExists || authExists else {
            return nil
        }

        let resourceValues = try directory.resourceValues(forKeys: [.creationDateKey])
        let createdAt = resourceValues.creationDate
            ?? parsedBackupDate(from: directory.lastPathComponent)
            ?? .distantPast

        return BackupSnapshotSummary(
            directoryPath: directory.path,
            createdAt: createdAt,
            configBackupPath: configExists ? configBackupURL.path : nil,
            authBackupPath: authExists ? authBackupURL.path : nil
        )
    }

    private func parsedBackupDate(from directoryName: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let candidate = String(directoryName.prefix(15))
        return formatter.date(from: candidate)
    }

    private func expandedURL(for path: String) -> URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }

    private func parseAuthData(_ data: Data) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw ConfigSwitchError.invalidFormat("auth.json 不是一个合法的 JSON 对象。")
        }

        return dictionary
    }

    private func updateAuthData(_ data: Data, using preset: CodexPreset) throws -> Data {
        var object = try parseAuthData(data)
        if object["auth_mode"] == nil {
            object["auth_mode"] = preset.authMode
        }
        object["OPENAI_API_KEY"] = preset.apiKey

        return try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }

    private func updateConfigText(_ text: String, using preset: CodexPreset) -> String {
        let lineEnding = text.contains("\r\n") ? "\r\n" : "\n"
        var lines = normalizedLines(from: text)

        let topLevelValues: [(String, String)] = [
            ("model_provider", renderString(preset.modelProvider)),
            ("model", renderString(preset.model)),
            ("review_model", renderString(preset.reviewModel)),
            ("model_reasoning_effort", renderString(preset.modelReasoningEffort)),
            ("disable_response_storage", renderBool(preset.disableResponseStorage)),
            ("network_access", renderString(preset.networkAccess)),
            ("windows_wsl_setup_acknowledged", renderBool(preset.windowsWSLSetupAcknowledged)),
            ("model_context_window", renderInt(preset.modelContextWindow)),
            ("model_auto_compact_token_limit", renderInt(preset.modelAutoCompactTokenLimit)),
        ]

        let openAIValues: [(String, String)] = [
            ("name", renderString(preset.providerName)),
            ("base_url", renderString(preset.baseURL)),
            ("wire_api", renderString(preset.wireAPI)),
            ("requires_openai_auth", renderBool(preset.requiresOpenAIAuth)),
        ]

        upsertTopLevelValues(&lines, values: topLevelValues)
        upsertSectionValues(&lines, sectionName: "model_providers.OpenAI", values: openAIValues)

        return lines.joined(separator: lineEnding) + lineEnding
    }

    private func upsertTopLevelValues(_ lines: inout [String], values: [(String, String)]) {
        let firstSectionIndex = lines.firstIndex(where: { parseSectionName(from: $0.trimmingCharacters(in: .whitespaces)) != nil }) ?? lines.count
        var insertionIndex = firstSectionIndex

        for (key, value) in values {
            if let existingIndex = lines[..<insertionIndex].firstIndex(where: { lineMatchesKey($0, key: key) }) {
                lines[existingIndex] = "\(key) = \(value)"
            } else {
                lines.insert("\(key) = \(value)", at: insertionIndex)
                insertionIndex += 1
            }
        }
    }

    private func upsertSectionValues(_ lines: inout [String], sectionName: String, values: [(String, String)]) {
        if let headerIndex = lines.firstIndex(where: { parseSectionName(from: $0.trimmingCharacters(in: .whitespaces)) == sectionName }) {
            let searchStart = headerIndex + 1
            var searchEnd = lines.count

            if searchStart < lines.count {
                for index in searchStart..<lines.count {
                    if parseSectionName(from: lines[index].trimmingCharacters(in: .whitespaces)) != nil {
                        searchEnd = index
                        break
                    }
                }
            }

            var insertionIndex = searchEnd
            for (key, value) in values {
                if let existingIndex = lines[searchStart..<insertionIndex].firstIndex(where: { lineMatchesKey($0, key: key) }) {
                    lines[existingIndex] = "\(key) = \(value)"
                } else {
                    lines.insert("\(key) = \(value)", at: insertionIndex)
                    insertionIndex += 1
                }
            }
        } else {
            if let last = lines.last, !last.isEmpty {
                lines.append("")
            }
            lines.append("[\(sectionName)]")
            for (key, value) in values {
                lines.append("\(key) = \(value)")
            }
        }
    }

    private func parseConfigText(_ text: String) -> (topLevel: [String: String], openAI: [String: String]) {
        var topLevel: [String: String] = [:]
        var openAI: [String: String] = [:]
        var currentSection: String?

        for line in normalizedLines(from: text) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            if let sectionName = parseSectionName(from: trimmed) {
                currentSection = sectionName
                continue
            }

            guard let (key, rawValue) = parseKeyValue(from: trimmed) else {
                continue
            }

            let parsedValue = decodeTomlValue(rawValue)
            if currentSection == nil {
                topLevel[key] = parsedValue
            } else if currentSection == "model_providers.OpenAI" {
                openAI[key] = parsedValue
            }
        }

        return (topLevel, openAI)
    }

    private func normalizedLines(from text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
    }

    private func parseSectionName(from line: String) -> String? {
        if line.hasPrefix("[[") && line.hasSuffix("]]") {
            return String(line.dropFirst(2).dropLast(2))
        }

        if line.hasPrefix("[") && line.hasSuffix("]") {
            return String(line.dropFirst().dropLast())
        }

        return nil
    }

    private func parseKeyValue(from line: String) -> (String, String)? {
        guard let separatorIndex = line.firstIndex(of: "=") else {
            return nil
        }

        let key = String(line[..<separatorIndex]).trimmingCharacters(in: .whitespaces)
        let value = String(line[line.index(after: separatorIndex)...]).trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else {
            return nil
        }
        return (key, value)
    }

    private func decodeTomlValue(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespaces)
        guard trimmed.first == "\"", trimmed.last == "\"" else {
            return trimmed
        }

        let body = String(trimmed.dropFirst().dropLast())
        return body
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    private func lineMatchesKey(_ line: String, key: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let (foundKey, _) = parseKeyValue(from: trimmed) else {
            return false
        }
        return foundKey == key
    }

    private func renderString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func renderBool(_ value: Bool) -> String {
        value ? "true" : "false"
    }

    private func renderInt(_ value: Int) -> String {
        String(value)
    }

    private func boolValue(_ rawValue: String?, default defaultValue: Bool) -> Bool {
        guard let rawValue else {
            return defaultValue
        }

        switch rawValue.lowercased() {
        case "true":
            return true
        case "false":
            return false
        default:
            return defaultValue
        }
    }

    private func intValue(_ rawValue: String?, default defaultValue: Int) -> Int {
        optionalIntValue(rawValue) ?? defaultValue
    }

    private func optionalIntValue(_ rawValue: String?) -> Int? {
        guard let rawValue else {
            return nil
        }
        return Int(rawValue)
    }
}
