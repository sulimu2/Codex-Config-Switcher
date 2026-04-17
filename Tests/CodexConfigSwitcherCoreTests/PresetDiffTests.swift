import CodexConfigSwitcherCore
import Testing

struct PresetDiffTests {
    @Test
    func diffMarksChangedFieldsAgainstLivePreset() {
        let source = CodexPreset(
            name: "当前配置",
            model: "gpt-5.4",
            reviewModel: "gpt-5.4",
            baseURL: "https://api.openai.com/v1",
            authMode: "apikey",
            apiKey: "old-key"
        )
        let target = CodexPreset(
            name: "代理环境",
            model: "gpt-5.5",
            reviewModel: "gpt-5.4",
            baseURL: "https://proxy.example.com/v1",
            authMode: "apikey",
            apiKey: "new-key"
        )

        let diffs = PresetDiffer.diff(from: source, to: target)

        #expect(diffs.first(where: { $0.key == "base_url" })?.kind == .modified)
        #expect(diffs.first(where: { $0.key == "model" })?.kind == .modified)
        #expect(diffs.first(where: { $0.key == "review_model" })?.kind == .unchanged)
    }

    @Test
    func diffTreatsMissingSourceAsAddedValues() {
        let target = CodexPreset(
            name: "首次导入",
            model: "gpt-5.4",
            reviewModel: "gpt-5.4",
            baseURL: "https://api.openai.com/v1",
            authMode: "apikey",
            apiKey: "secret"
        )

        let diffs = PresetDiffer.diff(from: nil, to: target)

        #expect(diffs.first(where: { $0.key == "base_url" })?.kind == .added)
        #expect(diffs.first(where: { $0.key == "model" })?.kind == .added)
    }

    @Test
    func diffRedactsAPIKeyValues() {
        let source = CodexPreset(name: "旧", apiKey: "")
        let target = CodexPreset(name: "新", apiKey: "super-secret")

        let diff = PresetDiffer.diff(from: source, to: target)
            .first(where: { $0.key == "OPENAI_API_KEY" })

        #expect(diff?.oldValue == "未填写")
        #expect(diff?.newValue == "已填写")
        #expect(diff?.kind == .modified)
    }
}
