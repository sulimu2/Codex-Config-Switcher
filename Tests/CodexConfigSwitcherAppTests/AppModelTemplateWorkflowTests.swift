@testable import CodexConfigSwitcher
import CodexConfigSwitcherCore
import Foundation
import Testing

@MainActor
struct AppModelTemplateWorkflowTests {
    @Test
    func loadTemplateIntoDraftKeepsSelectedPresetAndDoesNotMutateStoredPreset() throws {
        let workspace = try AppModelWorkspace()
        try workspace.writeConfig(
            """
            model_provider = "OpenAI"
            model = "gpt-5.4"
            review_model = "gpt-5.4"

            [model_providers.OpenAI]
            name = "OpenAI"
            base_url = "https://api.openai.com/v1"
            wire_api = "responses"
            requires_openai_auth = true
            """
        )
        try workspace.writeAuth(
            """
            {
              "auth_mode": "apikey",
              "OPENAI_API_KEY": "existing-live-key"
            }
            """
        )

        let preset = CodexPreset(
            id: UUID(uuidString: "14598C60-00AA-4E0D-B241-98E34EF92793")!,
            name: "当前预设",
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
            requestMaxRetries: 2,
            streamMaxRetries: 2,
            streamIdleTimeoutMs: 5_000,
            providerName: "OpenAI",
            baseURL: "https://api.openai.com/v1",
            wireAPI: "responses",
            requiresOpenAIAuth: true,
            authMode: "apikey",
            apiKey: "selected-preset-key"
        )
        let template = CodexTemplate(
            id: UUID(uuidString: "6C39A2E6-667B-4541-A935-9B90F7176731")!,
            name: "代理模板",
            environmentTag: .proxy,
            modelProvider: "OpenAI",
            model: "gpt-5.4-mini",
            reviewModel: "gpt-5.4",
            modelReasoningEffort: "high",
            disableResponseStorage: false,
            networkAccess: "enabled",
            windowsWSLSetupAcknowledged: true,
            modelContextWindow: 200_000,
            modelAutoCompactTokenLimit: 180_000,
            requestMaxRetries: 4,
            streamMaxRetries: 4,
            streamIdleTimeoutMs: 9_000,
            providerName: "Proxy",
            baseURL: "https://proxy.example.com/v1",
            wireAPI: "responses",
            requiresOpenAIAuth: false,
            authMode: "apikey"
        )

        let presetStore = try PresetStore(fileURL: workspace.presetsURL)
        let settingsStore = try SettingsStore(fileURL: workspace.settingsURL)
        let templateStore = try TemplateStore(fileURL: workspace.templatesURL)
        try presetStore.savePresets([preset])
        try templateStore.saveTemplates([template])
        try settingsStore.saveSettings(
            AppSettings(
                paths: workspace.paths,
                selectedPresetID: preset.id
            )
        )

        let model = try workspace.makeAppModel()

        model.loadTemplateIntoDraft(id: template.id)

        #expect(model.selectedPresetID == preset.id)
        #expect(model.selectedPreset?.baseURL == "https://api.openai.com/v1")
        #expect(model.selectedPreset?.apiKey == "selected-preset-key")
        #expect(model.draft.id == preset.id)
        #expect(model.draft.name == "当前预设")
        #expect(model.draft.baseURL == "https://proxy.example.com/v1")
        #expect(model.draft.environmentTag == .proxy)
        #expect(model.draft.apiKey.isEmpty)
        #expect(model.hasUnsavedChanges)
    }

    @Test
    func overwriteTemplatePersistsSanitizedDraft() throws {
        let workspace = try AppModelWorkspace()
        try workspace.writeConfig("model = \"gpt-5.4\"\n")
        try workspace.writeAuth("{\"auth_mode\":\"apikey\",\"OPENAI_API_KEY\":\"live-key\"}")

        let originalTemplate = CodexTemplate(
            id: UUID(uuidString: "B1AC7752-0AD1-445D-9944-5D2629189C37")!,
            name: "官方模板",
            environmentTag: .official,
            model: "gpt-5.4",
            reviewModel: "gpt-5.4",
            baseURL: "https://api.openai.com/v1",
            authMode: "apikey"
        )
        let templateStore = try TemplateStore(fileURL: workspace.templatesURL)
        try templateStore.saveTemplates([originalTemplate])

        let model = try workspace.makeAppModel()
        model.draft = CodexPreset(
            name: "临时草稿",
            environmentTag: .proxy,
            modelProvider: "OpenAI",
            model: "gpt-5.4-mini",
            reviewModel: "gpt-5.4",
            modelReasoningEffort: "medium",
            disableResponseStorage: false,
            networkAccess: "enabled",
            windowsWSLSetupAcknowledged: true,
            modelContextWindow: 300_000,
            modelAutoCompactTokenLimit: 240_000,
            requestMaxRetries: 5,
            streamMaxRetries: 6,
            streamIdleTimeoutMs: 7_000,
            providerName: "Proxy",
            baseURL: "https://proxy.example.com/v1",
            wireAPI: "responses",
            requiresOpenAIAuth: false,
            authMode: "oauth",
            apiKey: "super-secret-key"
        )

        model.overwriteTemplate(id: originalTemplate.id)

        let raw = try String(contentsOf: workspace.templatesURL, encoding: .utf8)
        let templates = try templateStore.loadTemplates()
        let savedTemplate = try #require(templates.first)

        #expect(savedTemplate.id == originalTemplate.id)
        #expect(savedTemplate.name == "官方模板")
        #expect(savedTemplate.baseURL == "https://proxy.example.com/v1")
        #expect(savedTemplate.authMode == "oauth")
        #expect(raw.contains("super-secret-key") == false)
        #expect(raw.contains("apiKey") == false)
    }

    @Test
    func renameAndDeleteTemplatePersistChanges() throws {
        let workspace = try AppModelWorkspace()
        try workspace.writeConfig("model = \"gpt-5.4\"\n")
        try workspace.writeAuth("{\"auth_mode\":\"apikey\",\"OPENAI_API_KEY\":\"live-key\"}")

        let firstTemplate = CodexTemplate(
            id: UUID(uuidString: "E65DC5A0-A3CE-4C46-8983-D33E8E8D968C")!,
            name: "官方模板",
            environmentTag: .official,
            model: "gpt-5.4",
            reviewModel: "gpt-5.4",
            baseURL: "https://api.openai.com/v1",
            authMode: "apikey"
        )
        let secondTemplate = CodexTemplate(
            id: UUID(uuidString: "BC83B0F5-1A6A-4F44-8682-BBC6C3117B7E")!,
            name: "代理模板",
            environmentTag: .proxy,
            model: "gpt-5.4-mini",
            reviewModel: "gpt-5.4",
            baseURL: "https://proxy.example.com/v1",
            authMode: "apikey"
        )
        let templateStore = try TemplateStore(fileURL: workspace.templatesURL)
        try templateStore.saveTemplates([firstTemplate, secondTemplate])

        let model = try workspace.makeAppModel()

        model.renameTemplate(id: firstTemplate.id, to: "个人骨架")
        model.renameTemplate(id: secondTemplate.id, to: "个人骨架")
        model.deleteTemplate(id: firstTemplate.id)

        let templates = try templateStore.loadTemplates()

        #expect(templates.count == 1)
        #expect(templates[0].id == secondTemplate.id)
        #expect(templates[0].name == "个人骨架 2")
    }

    @Test
    func selectingAnotherPresetWithUnsavedChangesRequiresConfirmation() throws {
        let workspace = try AppModelWorkspace()
        try workspace.writeConfig("model = \"gpt-5.4\"\n")
        try workspace.writeAuth("{\"auth_mode\":\"apikey\",\"OPENAI_API_KEY\":\"live-key\"}")

        let firstPreset = CodexPreset(
            id: UUID(uuidString: "0B8EAA67-9B48-4A8B-BCEC-593D7BBEC02B")!,
            name: "官方环境",
            environmentTag: .official,
            baseURL: "https://api.openai.com/v1",
            authMode: "apikey",
            apiKey: "first-key"
        )
        let secondPreset = CodexPreset(
            id: UUID(uuidString: "C333AD0C-A406-4C6F-9561-D299E38760C3")!,
            name: "代理环境",
            environmentTag: .proxy,
            baseURL: "https://proxy.example.com/v1",
            authMode: "apikey",
            apiKey: "second-key"
        )

        let presetStore = try PresetStore(fileURL: workspace.presetsURL)
        let settingsStore = try SettingsStore(fileURL: workspace.settingsURL)
        try presetStore.savePresets([firstPreset, secondPreset])
        try settingsStore.saveSettings(
            AppSettings(
                paths: workspace.paths,
                selectedPresetID: firstPreset.id
            )
        )

        let model = try workspace.makeAppModel()
        model.draft.baseURL = "https://draft.example.com/v1"

        model.selectPreset(id: secondPreset.id)

        #expect(model.selectedPresetID == firstPreset.id)
        #expect(model.presetPendingSelection?.id == secondPreset.id)
        #expect(model.draft.baseURL == "https://draft.example.com/v1")

        model.confirmDiscardAndSelectPendingPreset()

        #expect(model.selectedPresetID == secondPreset.id)
        #expect(model.presetPendingSelection == nil)
        #expect(model.draft.baseURL == secondPreset.baseURL)
    }

    @Test
    func confirmingSaveBeforeSwitchingPersistsCurrentPresetThenSwitches() throws {
        let workspace = try AppModelWorkspace()
        try workspace.writeConfig("model = \"gpt-5.4\"\n")
        try workspace.writeAuth("{\"auth_mode\":\"apikey\",\"OPENAI_API_KEY\":\"live-key\"}")

        let firstPreset = CodexPreset(
            id: UUID(uuidString: "96C112A7-E70A-4167-9CB4-F8AC1B6983DE")!,
            name: "当前预设",
            environmentTag: .official,
            baseURL: "https://api.openai.com/v1",
            authMode: "apikey",
            apiKey: "first-key"
        )
        let secondPreset = CodexPreset(
            id: UUID(uuidString: "33EE4B44-DC7A-4E1C-A930-4CF6ED68C7C1")!,
            name: "备用预设",
            environmentTag: .official,
            baseURL: "https://backup.example.com/v1",
            authMode: "apikey",
            apiKey: "second-key"
        )

        let presetStore = try PresetStore(fileURL: workspace.presetsURL)
        let settingsStore = try SettingsStore(fileURL: workspace.settingsURL)
        try presetStore.savePresets([firstPreset, secondPreset])
        try settingsStore.saveSettings(
            AppSettings(
                paths: workspace.paths,
                selectedPresetID: firstPreset.id
            )
        )

        let model = try workspace.makeAppModel()
        model.draft.baseURL = "https://saved-draft.example.com/v1"

        model.selectPreset(id: secondPreset.id)
        model.confirmSaveAndSelectPendingPreset()

        let persistedPresets = try presetStore.loadPresets()
        let persistedFirstPreset = try #require(persistedPresets.first(where: { $0.id == firstPreset.id }))

        #expect(persistedFirstPreset.baseURL == "https://saved-draft.example.com/v1")
        #expect(model.selectedPresetID == secondPreset.id)
        #expect(model.draft.baseURL == secondPreset.baseURL)
        #expect(model.presetPendingSelection == nil)
    }

    @Test
    func menuApplyKeepsUnsavedDraftIntact() throws {
        let workspace = try AppModelWorkspace()
        try workspace.writeConfig(
            """
            model_provider = "OpenAI"
            model = "gpt-5.4"
            review_model = "gpt-5.4"

            [model_providers.OpenAI]
            name = "OpenAI"
            base_url = "https://api.openai.com/v1"
            wire_api = "responses"
            requires_openai_auth = true
            """
        )
        try workspace.writeAuth(
            """
            {
              "auth_mode": "apikey",
              "OPENAI_API_KEY": "live-key"
            }
            """
        )

        let firstPreset = CodexPreset(
            id: UUID(uuidString: "B1464D10-E0EB-43D1-8C81-21306F1A383D")!,
            name: "当前编辑预设",
            environmentTag: .official,
            modelProvider: "OpenAI",
            model: "gpt-5.4",
            reviewModel: "gpt-5.4",
            providerName: "OpenAI",
            baseURL: "https://api.openai.com/v1",
            wireAPI: "responses",
            requiresOpenAIAuth: true,
            authMode: "apikey",
            apiKey: "first-key"
        )
        let secondPreset = CodexPreset(
            id: UUID(uuidString: "10A8C45D-9BF0-4E33-83D6-654136CF577C")!,
            name: "菜单栏切换目标",
            environmentTag: .official,
            modelProvider: "OpenAI",
            model: "gpt-5.4-mini",
            reviewModel: "gpt-5.4",
            providerName: "OpenAI",
            baseURL: "https://api.openai.com/v1",
            wireAPI: "responses",
            requiresOpenAIAuth: true,
            authMode: "apikey",
            apiKey: "second-key"
        )

        let presetStore = try PresetStore(fileURL: workspace.presetsURL)
        let settingsStore = try SettingsStore(fileURL: workspace.settingsURL)
        try presetStore.savePresets([firstPreset, secondPreset])
        try settingsStore.saveSettings(
            AppSettings(
                paths: workspace.paths,
                selectedPresetID: firstPreset.id,
                restartPromptEnabled: false
            )
        )

        let model = try workspace.makeAppModel()
        model.restartPromptEnabled = false
        model.draft.baseURL = "https://draft-preserved.example.com/v1"
        model.draft.model = "gpt-5.4-nano"

        model.applyPresetFromMenu(id: secondPreset.id)

        #expect(model.selectedPresetID == firstPreset.id)
        #expect(model.draft.baseURL == "https://draft-preserved.example.com/v1")
        #expect(model.draft.model == "gpt-5.4-nano")
        #expect(model.lastAppliedPresetID == secondPreset.id)
        #expect(model.statusMessage.contains("当前草稿已保留"))
        #expect(model.shouldShowMainWindowContextBanner)
        let context = try #require(model.mainWindowContextBannerContext)
        #expect(context.livePresetID == secondPreset.id)
        #expect(context.livePresetName == "菜单栏切换目标")
        #expect(context.selectedPresetName == "当前编辑预设")
        #expect(context.message.contains("未保存草稿"))
    }

    @Test
    func contextBannerStaysHiddenWhenLiveMatchesSelectedPreset() throws {
        let workspace = try AppModelWorkspace()
        try workspace.writeConfig(
            """
            model_provider = "OpenAI"
            model = "gpt-5.4"
            review_model = "gpt-5.4"

            [model_providers.OpenAI]
            name = "OpenAI"
            base_url = "https://api.openai.com/v1"
            wire_api = "responses"
            requires_openai_auth = true
            """
        )
        try workspace.writeAuth("{\"auth_mode\":\"apikey\",\"OPENAI_API_KEY\":\"live-key\"}")

        let preset = CodexPreset(
            id: UUID(uuidString: "4452B5CC-56D2-47FE-8C48-4A63477A7D47")!,
            name: "当前预设",
            environmentTag: .official,
            modelProvider: "OpenAI",
            model: "gpt-5.4",
            reviewModel: "gpt-5.4",
            providerName: "OpenAI",
            baseURL: "https://api.openai.com/v1",
            wireAPI: "responses",
            requiresOpenAIAuth: true,
            authMode: "apikey",
            apiKey: "first-key"
        )

        let presetStore = try PresetStore(fileURL: workspace.presetsURL)
        let settingsStore = try SettingsStore(fileURL: workspace.settingsURL)
        try presetStore.savePresets([preset])
        try settingsStore.saveSettings(
            AppSettings(
                paths: workspace.paths,
                selectedPresetID: preset.id,
                restartPromptEnabled: false
            )
        )

        let model = try workspace.makeAppModel()
        model.lastLoaded = LiveConfigurationSnapshot(preset: preset)
        model.draft.model = "gpt-5.4-nano"

        #expect(model.hasUnsavedChanges)
        #expect(model.livePresetID == preset.id)
        #expect(model.shouldShowMainWindowContextBanner == false)
        #expect(model.mainWindowContextBannerContext == nil)
    }

    @Test
    func contextBannerStaysHiddenWithoutLiveSnapshot() throws {
        let workspace = try AppModelWorkspace()
        try workspace.writeConfig("model = \"gpt-5.4\"\n")
        try workspace.writeAuth("{\"auth_mode\":\"apikey\",\"OPENAI_API_KEY\":\"live-key\"}")

        let preset = CodexPreset(
            id: UUID(uuidString: "971D4E25-45B4-4B6D-8D8A-DB2A6B425F7D")!,
            name: "当前预设",
            environmentTag: .official,
            baseURL: "https://api.openai.com/v1",
            authMode: "apikey",
            apiKey: "first-key"
        )

        let presetStore = try PresetStore(fileURL: workspace.presetsURL)
        let settingsStore = try SettingsStore(fileURL: workspace.settingsURL)
        try presetStore.savePresets([preset])
        try settingsStore.saveSettings(
            AppSettings(
                paths: workspace.paths,
                selectedPresetID: preset.id
            )
        )

        let model = try workspace.makeAppModel()
        model.draft.baseURL = "https://draft.example.com/v1"
        model.lastLoaded = nil

        #expect(model.hasUnsavedChanges)
        #expect(model.livePresetID == nil)
        #expect(model.shouldShowMainWindowContextBanner == false)
        #expect(model.mainWindowContextBannerContext == nil)
    }

    @Test
    func testDraftConnectionClearsOldResultAndMarksLoading() async throws {
        let workspace = try AppModelWorkspace()
        try workspace.writeConfig("model = \"gpt-5.4\"\n")
        try workspace.writeAuth("{\"auth_mode\":\"apikey\",\"OPENAI_API_KEY\":\"live-key\"}")

        let preset = CodexPreset(
            id: UUID(uuidString: "DB25C64D-B899-4B71-B0DB-FB454B69A767")!,
            name: "连接测试预设",
            environmentTag: .official,
            model: "gpt-5.4",
            reviewModel: "gpt-5.4",
            baseURL: "https://api.openai.com/v1",
            authMode: "apikey",
            apiKey: "live-key"
        )

        let presetStore = try PresetStore(fileURL: workspace.presetsURL)
        let settingsStore = try SettingsStore(fileURL: workspace.settingsURL)
        try presetStore.savePresets([preset])
        try settingsStore.saveSettings(
            AppSettings(
                paths: workspace.paths,
                selectedPresetID: preset.id
            )
        )

        let responder = DeferredConnectionResponder()
        let model = try workspace.makeAppModel(
            connectionTestService: ConnectionTestService(sendRequest: responder.handle)
        )
        model.lastConnectionTestResult = ConnectionTestResult(
            outcome: .failure,
            endpoint: "https://stale.example.com/models",
            title: "旧结果",
            message: "should clear"
        )

        model.testDraftConnection()

        #expect(model.isTestingConnection)
        #expect(model.lastConnectionTestResult == nil)
        #expect(model.statusMessage == "正在测试连接...")

        await responder.waitUntilPending()
        await responder.resume(
            data: """
            {"data":[{"id":"gpt-5.4"}]}
            """.data(using: .utf8)!,
            statusCode: 200
        )
        await waitForConnectionTestToFinish(on: model)

        #expect(model.isTestingConnection == false)
        #expect(model.lastConnectionTestResult?.outcome == .success)
        #expect(model.lastConnectionTestResult?.title == "连接成功")
    }

    @Test
    func testDraftConnectionPublishesCompletedResult() async throws {
        let workspace = try AppModelWorkspace()
        try workspace.writeConfig("model = \"gpt-5.4\"\n")
        try workspace.writeAuth("{\"auth_mode\":\"apikey\",\"OPENAI_API_KEY\":\"live-key\"}")

        let preset = CodexPreset(
            id: UUID(uuidString: "7ED42751-6F15-4A79-AE04-3D806B9A5A5F")!,
            name: "连接测试预设",
            environmentTag: .official,
            model: "gpt-5.4",
            reviewModel: "gpt-5.4",
            baseURL: "https://api.openai.com/v1",
            authMode: "apikey",
            apiKey: "live-key"
        )

        let presetStore = try PresetStore(fileURL: workspace.presetsURL)
        let settingsStore = try SettingsStore(fileURL: workspace.settingsURL)
        try presetStore.savePresets([preset])
        try settingsStore.saveSettings(
            AppSettings(
                paths: workspace.paths,
                selectedPresetID: preset.id
            )
        )

        let model = try workspace.makeAppModel(
            connectionTestService: ConnectionTestService(sendRequest: { request in
                let response = try #require(
                    HTTPURLResponse(
                        url: request.url ?? URL(string: "https://api.openai.com/v1/models")!,
                        statusCode: 401,
                        httpVersion: nil,
                        headerFields: nil
                    )
                )
                return (Data(), response)
            })
        )

        model.testDraftConnection()
        await waitForConnectionTestToFinish(on: model)

        #expect(model.isTestingConnection == false)
        #expect(model.lastConnectionTestResult?.outcome == .failure)
        #expect(model.lastConnectionTestResult?.title == "鉴权失败")
        #expect(model.statusMessage == "鉴权失败")
    }
}

private struct AppModelWorkspace {
    let rootDirectory: URL
    let appSupportDirectory: URL
    let configURL: URL
    let authURL: URL
    let presetsURL: URL
    let settingsURL: URL
    let templatesURL: URL

    var paths: AppPaths {
        AppPaths(configPath: configURL.path, authPath: authURL.path)
    }

    init() throws {
        let baseDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        rootDirectory = baseDirectory
        appSupportDirectory = baseDirectory.appendingPathComponent("ApplicationSupport", isDirectory: true)
        configURL = baseDirectory.appendingPathComponent("config.toml")
        authURL = baseDirectory.appendingPathComponent("auth.json")
        presetsURL = baseDirectory.appendingPathComponent("presets.json")
        settingsURL = baseDirectory.appendingPathComponent("settings.json")
        templatesURL = baseDirectory.appendingPathComponent("templates.json")

        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
    }

    func writeConfig(_ text: String) throws {
        try text.write(to: configURL, atomically: true, encoding: .utf8)
    }

    func writeAuth(_ text: String) throws {
        try text.write(to: authURL, atomically: true, encoding: .utf8)
    }

    @MainActor
    func makeAppModel(
        connectionTestService: ConnectionTestService = ConnectionTestService()
    ) throws -> AppModel {
        try AppModel(
            fileService: CodexFileService(appSupportDirectory: appSupportDirectory),
            presetStore: PresetStore(fileURL: presetsURL),
            settingsStore: SettingsStore(fileURL: settingsURL),
            templateStore: TemplateStore(fileURL: templatesURL),
            connectionTestService: connectionTestService
        )
    }
}

private actor DeferredConnectionResponder {
    private var continuation: CheckedContinuation<(Data, HTTPURLResponse), Error>?

    func handle(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resume(data: Data, statusCode: Int) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.openai.com/v1/models")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        continuation?.resume(returning: (data, response))
        continuation = nil
    }

    func waitUntilPending(timeoutNanoseconds: UInt64 = 1_000_000_000) async {
        let start = DispatchTime.now().uptimeNanoseconds

        while continuation == nil {
            if DispatchTime.now().uptimeNanoseconds - start > timeoutNanoseconds {
                break
            }
            await Task.yield()
        }
    }
}

@MainActor
private func waitForConnectionTestToFinish(
    on model: AppModel,
    timeoutNanoseconds: UInt64 = 2_000_000_000
) async {
    let start = DispatchTime.now().uptimeNanoseconds

    while model.isTestingConnection {
        if DispatchTime.now().uptimeNanoseconds - start > timeoutNanoseconds {
            break
        }
        await Task.yield()
    }
}
