import CodexConfigSwitcherCore
import Foundation
import Testing

struct CodexFileServiceTests {
    @Test
    func loadSnapshotReadsCurrentConfigFields() throws {
        let workspace = try TemporaryWorkspace()
        let service = try CodexFileService(appSupportDirectory: workspace.appSupportDirectory)

        try workspace.writeConfig(
            """
            model_provider = "OpenAI"
            model = "gpt-5.4"
            review_model = "gpt-5.4"
            model_reasoning_effort = "xhigh"
            disable_response_storage = true
            network_access = "enabled"
            windows_wsl_setup_acknowledged = true
            model_context_window = 1000000
            model_auto_compact_token_limit = 900000
            request_max_retries = 20
            stream_max_retries = 20
            stream_idle_timeout_ms = 600000

            [model_providers.OpenAI]
            name = "OpenAI"
            base_url = "http://localhost:8080"
            wire_api = "responses"
            requires_openai_auth = true

            [[skills.config]]
            path = "/tmp/example"
            enabled = false
            """
        )

        try workspace.writeAuth(
            """
            {
              "auth_mode": "apikey",
              "OPENAI_API_KEY": "test-api-key-old"
            }
            """
        )

        let snapshot = try service.loadSnapshot(paths: workspace.paths)

        #expect(snapshot.preset.baseURL == "http://localhost:8080")
        #expect(snapshot.preset.requestMaxRetries == 20)
        #expect(snapshot.preset.streamMaxRetries == 20)
        #expect(snapshot.preset.streamIdleTimeoutMs == 600000)
        #expect(snapshot.preset.authMode == "apikey")
        #expect(snapshot.preset.apiKey == "test-api-key-old")
        #expect(snapshot.preset.environmentTag == .test)
    }

    @Test
    func applyPreservesUnmanagedFieldsAndCreatesBackups() throws {
        let workspace = try TemporaryWorkspace()
        let service = try CodexFileService(appSupportDirectory: workspace.appSupportDirectory)

        try workspace.writeConfig(
            """
            model_provider = "OpenAI"
            model = "gpt-5.4"
            review_model = "gpt-5.4"
            model_reasoning_effort = "xhigh"
            disable_response_storage = true
            network_access = "enabled"
            windows_wsl_setup_acknowledged = true
            model_context_window = 1000000
            model_auto_compact_token_limit = 900000
            request_max_retries = 20
            stream_max_retries = 20
            stream_idle_timeout_ms = 600000

            [model_providers.OpenAI]
            name = "OpenAI"
            base_url = "http://localhost:8080"
            wire_api = "responses"
            requires_openai_auth = true

            [[skills.config]]
            path = "/tmp/example"
            enabled = false
            """
        )

        try workspace.writeAuth(
            """
            {
              "auth_mode": "apikey",
              "OPENAI_API_KEY": "test-api-key-old",
              "other": "keep-me"
            }
            """
        )

        let preset = CodexPreset(
            name: "切换后",
            model: "gpt-5.4",
            reviewModel: "gpt-5.4",
            baseURL: "https://api.openai.com/v1",
            apiKey: "test-api-key-new"
        )

        let result = try service.apply(preset: preset, paths: workspace.paths)
        let updatedConfig = try workspace.readConfig()
        let updatedAuth = try workspace.readAuthJSONObject()

        #expect(updatedConfig.contains("base_url = \"https://api.openai.com/v1\""))
        #expect(updatedConfig.contains("request_max_retries = 20"))
        #expect(updatedConfig.contains("[[skills.config]]"))
        #expect(updatedAuth["auth_mode"] as? String == "apikey")
        #expect(updatedAuth["OPENAI_API_KEY"] as? String == "test-api-key-new")
        #expect(updatedAuth["other"] as? String == "keep-me")
        #expect(result.configBackupPath != nil)
        #expect(result.authBackupPath != nil)
    }

    @Test
    func applyCreatesOpenAISectionWhenConfigStartsEmpty() throws {
        let workspace = try TemporaryWorkspace()
        let service = try CodexFileService(appSupportDirectory: workspace.appSupportDirectory)

        try workspace.writeConfig("")
        try workspace.writeAuth("{}")

        let preset = CodexPreset(
            name: "新配置",
            baseURL: "https://api.openai.com/v1",
            apiKey: "test-api-key-new"
        )

        _ = try service.apply(preset: preset, paths: workspace.paths)
        let updatedConfig = try workspace.readConfig()

        #expect(updatedConfig.contains("[model_providers.OpenAI]"))
        #expect(updatedConfig.contains("base_url = \"https://api.openai.com/v1\""))
    }

    @Test
    func restoreLatestBackupRestoresMostRecentBackupAndCreatesRollbackBackup() throws {
        let workspace = try TemporaryWorkspace()
        let service = try CodexFileService(appSupportDirectory: workspace.appSupportDirectory)

        try workspace.writeConfig(
            """
            model_provider = "OpenAI"
            model = "gpt-5.4"
            review_model = "gpt-5.4"

            [model_providers.OpenAI]
            name = "OpenAI"
            base_url = "https://initial.example.com/v1"
            wire_api = "responses"
            requires_openai_auth = true
            """
        )
        try workspace.writeAuth(
            """
            {
              "auth_mode": "apikey",
              "OPENAI_API_KEY": "initial-key"
            }
            """
        )

        _ = try service.apply(
            preset: CodexPreset(
                name: "预设 B",
                model: "gpt-5.4",
                reviewModel: "gpt-5.4",
                baseURL: "https://preset-b.example.com/v1",
                apiKey: "key-b"
            ),
            paths: workspace.paths
        )

        Thread.sleep(forTimeInterval: 1.1)

        _ = try service.apply(
            preset: CodexPreset(
                name: "预设 C",
                model: "gpt-5.5",
                reviewModel: "gpt-5.5",
                baseURL: "https://preset-c.example.com/v1",
                apiKey: "key-c"
            ),
            paths: workspace.paths
        )

        let result = try service.restoreLatestBackup(paths: workspace.paths)
        let restoredConfig = try workspace.readConfig()
        let restoredAuth = try workspace.readAuthJSONObject()
        let latestBackupSummary = try service.latestBackupSummary()
        let latestBackup = try #require(latestBackupSummary)

        #expect(restoredConfig.contains("base_url = \"https://preset-b.example.com/v1\""))
        #expect(restoredConfig.contains("model = \"gpt-5.4\""))
        #expect(restoredAuth["OPENAI_API_KEY"] as? String == "key-b")
        #expect(result.rollbackConfigBackupPath != nil)
        #expect(result.rollbackAuthBackupPath != nil)
        #expect(latestBackup.directoryPath != result.sourceBackupDirectoryPath)
    }

    @Test
    func latestBackupSummaryReturnsNewestBackup() throws {
        let workspace = try TemporaryWorkspace()
        let service = try CodexFileService(appSupportDirectory: workspace.appSupportDirectory)

        try workspace.writeConfig("model = \"gpt-5.4\"\n")
        try workspace.writeAuth("{\"auth_mode\":\"apikey\",\"OPENAI_API_KEY\":\"old\"}")

        _ = try service.apply(
            preset: CodexPreset(name: "first", baseURL: "https://one.example.com/v1", apiKey: "one"),
            paths: workspace.paths
        )

        Thread.sleep(forTimeInterval: 1.1)

        _ = try service.apply(
            preset: CodexPreset(name: "second", baseURL: "https://two.example.com/v1", apiKey: "two"),
            paths: workspace.paths
        )

        let latestBackupSummary = try service.latestBackupSummary()
        let summary = try #require(latestBackupSummary)

        #expect(summary.configBackupPath?.contains("config.toml") == true)
        #expect(summary.authBackupPath?.contains("auth.json") == true)
        #expect(summary.createdAt > Date.distantPast)
    }

    @Test
    func listBackupSummariesReturnsNewestFirst() throws {
        let workspace = try TemporaryWorkspace()
        let service = try CodexFileService(appSupportDirectory: workspace.appSupportDirectory)

        try workspace.writeConfig("model = \"gpt-5.4\"\n")
        try workspace.writeAuth("{\"auth_mode\":\"apikey\",\"OPENAI_API_KEY\":\"old\"}")

        _ = try service.apply(
            preset: CodexPreset(name: "first", baseURL: "https://one.example.com/v1", apiKey: "one"),
            paths: workspace.paths
        )

        Thread.sleep(forTimeInterval: 1.1)

        _ = try service.apply(
            preset: CodexPreset(name: "second", baseURL: "https://two.example.com/v1", apiKey: "two"),
            paths: workspace.paths
        )

        let summaries = try service.listBackupSummaries(limit: 5)

        #expect(summaries.count == 2)
        #expect(summaries[0].createdAt >= summaries[1].createdAt)
    }

    @Test
    func restoreBackupRestoresChosenSnapshot() throws {
        let workspace = try TemporaryWorkspace()
        let service = try CodexFileService(appSupportDirectory: workspace.appSupportDirectory)

        try workspace.writeConfig(
            """
            model_provider = "OpenAI"
            model = "gpt-5.4"
            review_model = "gpt-5.4"

            [model_providers.OpenAI]
            name = "OpenAI"
            base_url = "https://initial.example.com/v1"
            wire_api = "responses"
            requires_openai_auth = true
            """
        )
        try workspace.writeAuth(
            """
            {
              "auth_mode": "apikey",
              "OPENAI_API_KEY": "initial-key"
            }
            """
        )

        _ = try service.apply(
            preset: CodexPreset(
                name: "预设 B",
                model: "gpt-5.4",
                reviewModel: "gpt-5.4",
                baseURL: "https://preset-b.example.com/v1",
                apiKey: "key-b"
            ),
            paths: workspace.paths
        )

        Thread.sleep(forTimeInterval: 1.1)

        _ = try service.apply(
            preset: CodexPreset(
                name: "预设 C",
                model: "gpt-5.5",
                reviewModel: "gpt-5.5",
                baseURL: "https://preset-c.example.com/v1",
                apiKey: "key-c"
            ),
            paths: workspace.paths
        )

        let summaries = try service.listBackupSummaries(limit: 5)
        let chosenBackup = try #require(summaries.last)

        _ = try service.restoreBackup(chosenBackup, paths: workspace.paths)
        let restoredConfig = try workspace.readConfig()
        let restoredAuth = try workspace.readAuthJSONObject()

        #expect(restoredConfig.contains("base_url = \"https://initial.example.com/v1\""))
        #expect(restoredAuth["OPENAI_API_KEY"] as? String == "initial-key")
    }

    @Test
    func presetStoreCanSaveAndLoadPresets() throws {
        let workspace = try TemporaryWorkspace()
        let store = try PresetStore(fileURL: workspace.rootDirectory.appendingPathComponent("presets.json"))

        try store.savePresets([
            CodexPreset(name: "本地"),
            CodexPreset(name: "线上", baseURL: "https://api.openai.com/v1", apiKey: "demo-api-key"),
        ])

        let presets = try store.loadPresets()

        #expect(presets.count == 2)
        #expect(presets[0].name == "本地")
        #expect(presets[1].baseURL == "https://api.openai.com/v1")
    }

    @Test
    func presetStoreLoadsLegacyPresetsWithoutEnvironmentTag() throws {
        let workspace = try TemporaryWorkspace()
        let fileURL = workspace.rootDirectory.appendingPathComponent("presets.json")
        let store = try PresetStore(fileURL: fileURL)

        try """
        [
          {
            "id": "A19B824F-34A4-4E36-92D3-A853DAD5E8E3",
            "name": "老代理预设",
            "baseURL": "https://proxy.example.com/v1",
            "apiKey": "legacy-key"
          }
        ]
        """.write(to: fileURL, atomically: true, encoding: .utf8)

        let presets = try store.loadPresets()

        #expect(presets.count == 1)
        #expect(presets[0].environmentTag == .proxy)
        #expect(presets[0].name == "老代理预设")
    }

    @Test
    func templateStoreCanSaveAndLoadTemplates() throws {
        let workspace = try TemporaryWorkspace()
        let store = try TemplateStore(fileURL: workspace.rootDirectory.appendingPathComponent("templates.json"))

        try store.saveTemplates([
            CodexTemplate(
                name: "代理模板",
                environmentTag: .proxy,
                modelProvider: "OpenAI",
                model: "gpt-5.4",
                reviewModel: "gpt-5.4",
                modelReasoningEffort: "high",
                disableResponseStorage: false,
                networkAccess: "enabled",
                windowsWSLSetupAcknowledged: true,
                modelContextWindow: 200_000,
                modelAutoCompactTokenLimit: 180_000,
                requestMaxRetries: 3,
                streamMaxRetries: 4,
                streamIdleTimeoutMs: 5_000,
                providerName: "Proxy",
                baseURL: "https://proxy.example.com/v1",
                wireAPI: "responses",
                requiresOpenAIAuth: false,
                authMode: "apikey"
            )
        ])

        let templates = try store.loadTemplates()

        #expect(templates.count == 1)
        #expect(templates[0].name == "代理模板")
        #expect(templates[0].environmentTag == .proxy)
        #expect(templates[0].baseURL == "https://proxy.example.com/v1")
        #expect(templates[0].modelContextWindow == 200_000)
        #expect(templates[0].requestMaxRetries == 3)
    }

    @Test
    func templateStoreDoesNotPersistAPIKey() throws {
        let workspace = try TemporaryWorkspace()
        let fileURL = workspace.rootDirectory.appendingPathComponent("templates.json")
        let store = try TemplateStore(fileURL: fileURL)
        let preset = CodexPreset(
            name: "敏感代理",
            environmentTag: .proxy,
            modelProvider: "OpenAI",
            model: "gpt-5.4",
            reviewModel: "gpt-5.4",
            modelReasoningEffort: "high",
            disableResponseStorage: false,
            networkAccess: "enabled",
            windowsWSLSetupAcknowledged: true,
            modelContextWindow: 200_000,
            modelAutoCompactTokenLimit: 180_000,
            requestMaxRetries: 3,
            streamMaxRetries: 4,
            streamIdleTimeoutMs: 5_000,
            providerName: "Proxy",
            baseURL: "https://proxy.example.com/v1",
            wireAPI: "responses",
            requiresOpenAIAuth: false,
            authMode: "apikey",
            apiKey: "super-secret-key"
        )

        try store.saveTemplates([CodexTemplate(preset: preset)])

        let raw = try String(contentsOf: fileURL, encoding: .utf8)
        let templates = try store.loadTemplates()

        #expect(raw.contains("super-secret-key") == false)
        #expect(raw.contains("apiKey") == false)
        #expect(templates[0].authMode == "apikey")
        #expect(templates[0].requiresOpenAIAuth == false)
    }

    @Test
    func templateCreatesPresetWithFreshIDAndEmptyAPIKey() {
        let template = CodexTemplate(
            id: UUID(uuidString: "B570A56B-EC1D-4E55-8188-429F3D0A9FAE")!,
            name: "官方模板",
            environmentTag: .official,
            modelProvider: "OpenAI",
            model: "gpt-5.4",
            reviewModel: "gpt-5.4",
            modelReasoningEffort: "xhigh",
            disableResponseStorage: true,
            networkAccess: "enabled",
            windowsWSLSetupAcknowledged: true,
            modelContextWindow: 1_000_000,
            modelAutoCompactTokenLimit: 900_000,
            requestMaxRetries: nil,
            streamMaxRetries: nil,
            streamIdleTimeoutMs: nil,
            providerName: "OpenAI",
            baseURL: "https://api.openai.com/v1",
            wireAPI: "responses",
            requiresOpenAIAuth: true,
            authMode: "apikey"
        )

        let firstPreset = template.makePreset()
        let secondPreset = template.makePreset()

        #expect(firstPreset.id != template.id)
        #expect(secondPreset.id != template.id)
        #expect(firstPreset.id != secondPreset.id)
        #expect(firstPreset.apiKey.isEmpty)
        #expect(secondPreset.apiKey.isEmpty)
        #expect(firstPreset.baseURL == template.baseURL)
    }

    @Test
    func applicationSupportProvidesTemplatesPath() throws {
        let templatesURL = try ApplicationSupportPaths.templatesFileURL(fileManager: .default)

        #expect(templatesURL.lastPathComponent == "templates.json")
        #expect(templatesURL.path.contains("CodexConfigSwitcher"))
    }

    @Test
    func defaultPathsUseCurrentHomeDirectory() {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)

        #expect(AppPaths.default.configPath == homeDirectory.appendingPathComponent("config.toml").path)
        #expect(AppPaths.default.authPath == homeDirectory.appendingPathComponent("auth.json").path)
    }

    @Test
    func settingsStorePersistsRestartSettings() throws {
        let workspace = try TemporaryWorkspace()
        let store = try SettingsStore(fileURL: workspace.rootDirectory.appendingPathComponent("settings.json"))

        try store.saveSettings(
            AppSettings(
                paths: workspace.paths,
                selectedPresetID: UUID(),
                restartPromptEnabled: false,
                targetApp: ManagedAppTarget(
                    displayName: "Codex",
                    bundleIdentifier: "com.openai.codex",
                    appPath: "/Applications/Codex.app"
                )
            )
        )

        let settings = try store.loadSettings()

        #expect(settings.restartPromptEnabled == false)
        #expect(settings.targetApp.bundleIdentifier == "com.openai.codex")
        #expect(settings.targetApp.appPath == "/Applications/Codex.app")
    }

    @Test
    func settingsStorePersistsLastAppliedMetadata() throws {
        let workspace = try TemporaryWorkspace()
        let store = try SettingsStore(fileURL: workspace.rootDirectory.appendingPathComponent("settings.json"))
        let presetID = UUID()
        let appliedAt = Date(timeIntervalSince1970: 1_234_567_890)
        let favoriteID = UUID()
        let recentID = UUID()

        try store.saveSettings(
            AppSettings(
                paths: workspace.paths,
                selectedPresetID: nil,
                restartPromptEnabled: true,
                targetApp: .codex,
                lastAppliedPresetID: presetID,
                lastAppliedAt: appliedAt,
                favoritePresetIDs: [favoriteID],
                recentPresetIDs: [recentID]
            )
        )

        let settings = try store.loadSettings()

        #expect(settings.lastAppliedPresetID == presetID)
        #expect(settings.lastAppliedAt == appliedAt)
        #expect(settings.favoritePresetIDs == [favoriteID])
        #expect(settings.recentPresetIDs == [recentID])
    }

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

    @Test
    func settingsStoreMarksFreshWorkspaceAsNotOnboarded() throws {
        let workspace = try TemporaryWorkspace()
        let store = try SettingsStore(fileURL: workspace.rootDirectory.appendingPathComponent("settings.json"))

        let settings = try store.loadSettings(defaultPaths: workspace.paths)

        #expect(settings.hasCompletedOnboarding == false)
        #expect(settings.onboardingVersion == 1)
    }

    @Test
    func settingsStorePersistsOperationHistory() throws {
        let workspace = try TemporaryWorkspace()
        let store = try SettingsStore(fileURL: workspace.rootDirectory.appendingPathComponent("settings.json"))
        let presetID = UUID()
        let operatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let historyEntry = PresetOperationHistoryEntry(
            operatedAt: operatedAt,
            kind: .applyPreset,
            outcome: .success,
            presetID: presetID,
            presetName: "官方环境",
            environmentTag: .official,
            detail: "已应用预设并完成配置写入。"
        )

        try store.saveSettings(
            AppSettings(
                paths: workspace.paths,
                operationHistory: [historyEntry]
            )
        )

        let settings = try store.loadSettings()

        #expect(settings.operationHistory.count == 1)
        #expect(settings.operationHistory[0].presetID == presetID)
        #expect(settings.operationHistory[0].presetName == "官方环境")
        #expect(settings.operationHistory[0].operatedAt == operatedAt)
        #expect(settings.operationHistory[0].outcome == .success)
    }

    @Test
    func settingsStoreLoadsLegacySettingsWithRestartDefaults() throws {
        let workspace = try TemporaryWorkspace()
        let fileURL = workspace.rootDirectory.appendingPathComponent("settings.json")
        let store = try SettingsStore(fileURL: fileURL)

        try """
        {
          "paths": {
            "configPath": "\(workspace.configURL.path)",
            "authPath": "\(workspace.authURL.path)"
          },
          "selectedPresetID": null
        }
        """.write(to: fileURL, atomically: true, encoding: .utf8)

        let settings = try store.loadSettings()

        #expect(settings.restartPromptEnabled == true)
        #expect(settings.targetApp == .codex)
    }

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
          },
          "selectedPresetID": null,
          "restartPromptEnabled": true,
          "targetApp": {
            "displayName": "Codex",
            "bundleIdentifier": "com.openai.codex",
            "appPath": "/Applications/Codex.app"
          }
        }
        """.write(to: fileURL, atomically: true, encoding: .utf8)

        let settings = try store.loadSettings()

        #expect(settings.lastAppliedPresetID == nil)
        #expect(settings.lastAppliedAt == nil)
        #expect(settings.favoritePresetIDs.isEmpty)
        #expect(settings.recentPresetIDs.isEmpty)
        #expect(settings.presetEditorMode == .basic)
        #expect(settings.operationHistory.isEmpty)
        #expect(settings.hasCompletedOnboarding == true)
        #expect(settings.onboardingVersion == 0)
    }
}

private struct TemporaryWorkspace {
    let rootDirectory: URL
    let appSupportDirectory: URL
    let configURL: URL
    let authURL: URL

    var paths: AppPaths {
        AppPaths(configPath: configURL.path, authPath: authURL.path)
    }

    init() throws {
        let baseDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        rootDirectory = baseDirectory
        appSupportDirectory = baseDirectory.appendingPathComponent("ApplicationSupport", isDirectory: true)
        configURL = baseDirectory.appendingPathComponent("config.toml")
        authURL = baseDirectory.appendingPathComponent("auth.json")

        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
    }

    func writeConfig(_ text: String) throws {
        try text.write(to: configURL, atomically: true, encoding: .utf8)
    }

    func writeAuth(_ text: String) throws {
        try text.write(to: authURL, atomically: true, encoding: .utf8)
    }

    func readConfig() throws -> String {
        try String(contentsOf: configURL, encoding: .utf8)
    }

    func readAuthJSONObject() throws -> [String: Any] {
        let data = try Data(contentsOf: authURL)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        return jsonObject as? [String: Any] ?? [:]
    }
}
