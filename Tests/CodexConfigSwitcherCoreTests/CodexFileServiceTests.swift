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
