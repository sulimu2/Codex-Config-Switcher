import CodexConfigSwitcherCore
import Foundation
import Testing

struct PresetTransferServiceTests {
    @Test
    func exportAndImportRoundTripsPayload() throws {
        let service = PresetTransferService()
        let presets = [
            CodexPreset(name: "官方", baseURL: "https://api.openai.com/v1", apiKey: "key-1"),
            CodexPreset(name: "代理", environmentTag: .proxy, baseURL: "https://proxy.example.com/v1", apiKey: "key-2"),
        ]

        let data = try service.exportPresets(presets)
        let imported = try service.importPresets(from: data)

        #expect(imported.count == 2)
        #expect(imported[0].name == "官方")
        #expect(imported[1].baseURL == "https://proxy.example.com/v1")
        #expect(imported[1].environmentTag == .proxy)
    }

    @Test
    func importAcceptsPlainPresetArray() throws {
        let service = PresetTransferService()
        let data = try JSONEncoder().encode([
            CodexPreset(name: "数组导入", baseURL: "https://array.example.com/v1", apiKey: "array-key"),
        ])

        let imported = try service.importPresets(from: data)

        #expect(imported.count == 1)
        #expect(imported[0].name == "数组导入")
    }

    @Test
    func importAcceptsSinglePresetObject() throws {
        let service = PresetTransferService()
        let data = try JSONEncoder().encode(
            CodexPreset(name: "单个导入", baseURL: "https://single.example.com/v1", apiKey: "single-key")
        )

        let imported = try service.importPresets(from: data)

        #expect(imported.count == 1)
        #expect(imported[0].name == "单个导入")
    }

    @Test
    func importRejectsInvalidJSON() throws {
        let service = PresetTransferService()
        let data = Data("not-json".utf8)

        #expect(throws: ConfigSwitchError.self) {
            try service.importPresets(from: data)
        }
    }

    @Test
    func importRejectsEmptyPresetArray() throws {
        let service = PresetTransferService()
        let data = Data("[]".utf8)

        do {
            _ = try service.importPresets(from: data)
            Issue.record("expected empty preset array to fail")
        } catch {
            #expect(error.localizedDescription.contains("没有可用的预设"))
        }
    }

    @Test
    func importRejectsPresetWithInvalidFields() throws {
        let service = PresetTransferService()
        let data = Data(
            """
            [
              {
                "id": "A19B824F-34A4-4E36-92D3-A853DAD5E8E3",
                "name": "坏预设",
                "modelProvider": "OpenAI",
                "model": "",
                "reviewModel": "gpt-5.4",
                "modelReasoningEffort": "xhigh",
                "disableResponseStorage": true,
                "networkAccess": "enabled",
                "windowsWSLSetupAcknowledged": true,
                "modelContextWindow": 1000000,
                "modelAutoCompactTokenLimit": 900000,
                "providerName": "OpenAI",
                "baseURL": "bad-url",
                "wireAPI": "responses",
                "requiresOpenAIAuth": true,
                "authMode": "apikey",
                "apiKey": ""
              }
            ]
            """.utf8
        )

        do {
            _ = try service.importPresets(from: data)
            Issue.record("expected invalid preset fields to fail")
        } catch {
            #expect(error.localizedDescription.contains("第 1 个预设"))
            #expect(error.localizedDescription.contains("坏预设"))
            #expect(error.localizedDescription.contains("接口地址"))
        }
    }
}
