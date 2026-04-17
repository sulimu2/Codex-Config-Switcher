import CodexConfigSwitcherCore
import Foundation
import Testing

struct PresetValidationTests {
    @Test
    func validationRejectsInvalidBaseURL() {
        let preset = CodexPreset(name: "本地代理", baseURL: "not a url")

        let result = PresetValidator.validate(preset)

        #expect(result.issues.contains(.invalidBaseURL))
        #expect(result.isValid == false)
    }

    @Test
    func validationRejectsMissingRequiredFields() {
        let preset = CodexPreset(
            name: "   ",
            model: " ",
            reviewModel: "\n",
            authMode: " "
        )

        let result = PresetValidator.validate(preset)

        #expect(result.issues.contains(.emptyName))
        #expect(result.issues.contains(.emptyModel))
        #expect(result.issues.contains(.emptyReviewModel))
        #expect(result.issues.contains(.emptyAuthMode))
    }

    @Test
    func validationRequiresAPIKeyForAPIKeyMode() {
        let preset = CodexPreset(
            name: "官方",
            authMode: "apikey",
            apiKey: " "
        )

        let result = PresetValidator.validate(preset)

        #expect(result.issues.contains(.missingAPIKey))
    }

    @Test
    func validationRejectsNonPositiveNumericFields() {
        let preset = CodexPreset(
            name: "异常数值",
            modelContextWindow: 0,
            modelAutoCompactTokenLimit: -1
        )

        let result = PresetValidator.validate(preset)

        #expect(result.issues.contains(.invalidContextWindow))
        #expect(result.issues.contains(.invalidAutoCompactTokenLimit))
    }

    @Test
    func managedFingerprintIgnoresPresetNameAndIdentifier() {
        let firstPreset = CodexPreset(
            id: UUID(),
            name: "预设 A",
            model: "gpt-5.4",
            reviewModel: "gpt-5.4",
            baseURL: "https://api.openai.com/v1",
            apiKey: "secret"
        )
        let secondPreset = CodexPreset(
            id: UUID(),
            name: "预设 B",
            model: "gpt-5.4",
            reviewModel: "gpt-5.4",
            baseURL: "https://api.openai.com/v1",
            apiKey: "secret"
        )
        let thirdPreset = CodexPreset(
            id: secondPreset.id,
            name: secondPreset.name,
            model: "gpt-5.5",
            reviewModel: secondPreset.reviewModel,
            baseURL: secondPreset.baseURL,
            apiKey: secondPreset.apiKey
        )

        #expect(firstPreset.managedFingerprint == secondPreset.managedFingerprint)
        #expect(firstPreset.managedFingerprint != thirdPreset.managedFingerprint)
    }
}
