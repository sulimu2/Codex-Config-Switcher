import Foundation

public enum PresetFieldDiffKind: String, Equatable, Sendable {
    case added
    case modified
    case unchanged
}

public struct PresetFieldDiff: Equatable, Sendable, Identifiable {
    public let key: String
    public let title: String
    public let oldValue: String
    public let newValue: String
    public let kind: PresetFieldDiffKind

    public var id: String { key }

    public init(key: String, title: String, oldValue: String, newValue: String, kind: PresetFieldDiffKind) {
        self.key = key
        self.title = title
        self.oldValue = oldValue
        self.newValue = newValue
        self.kind = kind
    }
}

public enum PresetDiffer {
    public static func diff(from source: CodexPreset?, to target: CodexPreset) -> [PresetFieldDiff] {
        makeFieldDescriptors().map { descriptor in
            let oldValue = source.map { descriptor.value($0) } ?? "未设置"
            let newValue = descriptor.value(target)
            let kind: PresetFieldDiffKind

            if source == nil {
                kind = newValue == "未设置" ? .unchanged : .added
            } else if oldValue == newValue {
                kind = .unchanged
            } else if oldValue == "未设置" {
                kind = .added
            } else {
                kind = .modified
            }

            return PresetFieldDiff(
                key: descriptor.key,
                title: descriptor.title,
                oldValue: oldValue,
                newValue: newValue,
                kind: kind
            )
        }
    }

    private struct FieldDescriptor: Sendable {
        let key: String
        let title: String
        let value: @Sendable (CodexPreset) -> String
    }

    private static func makeFieldDescriptors() -> [FieldDescriptor] {
        [
            FieldDescriptor(key: "base_url", title: "接口地址") { normalized($0.baseURL) },
            FieldDescriptor(key: "model", title: "主模型") { normalized($0.model) },
            FieldDescriptor(key: "review_model", title: "评审模型") { normalized($0.reviewModel) },
            FieldDescriptor(key: "auth_mode", title: "认证模式") { normalized($0.authMode) },
            FieldDescriptor(key: "OPENAI_API_KEY", title: "API Key") { secretState($0.apiKey) },
            FieldDescriptor(key: "model_provider", title: "模型 Provider") { normalized($0.modelProvider) },
            FieldDescriptor(key: "provider.name", title: "Provider 名称") { normalized($0.providerName) },
            FieldDescriptor(key: "model_reasoning_effort", title: "推理强度") { normalized($0.modelReasoningEffort) },
            FieldDescriptor(key: "network_access", title: "网络访问") { normalized($0.networkAccess) },
            FieldDescriptor(key: "wire_api", title: "Wire API") { normalized($0.wireAPI) },
            FieldDescriptor(key: "requires_openai_auth", title: "OpenAI 认证") { boolLabel($0.requiresOpenAIAuth) },
            FieldDescriptor(key: "disable_response_storage", title: "关闭响应存储") { boolLabel($0.disableResponseStorage) },
            FieldDescriptor(key: "windows_wsl_setup_acknowledged", title: "Windows WSL 设置") { boolLabel($0.windowsWSLSetupAcknowledged) },
            FieldDescriptor(key: "model_context_window", title: "上下文窗口") { String($0.modelContextWindow) },
            FieldDescriptor(key: "model_auto_compact_token_limit", title: "自动压缩限制") { String($0.modelAutoCompactTokenLimit) },
        ]
    }

    private static func normalized(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未设置" : trimmed
    }

    private static func secretState(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未填写" : "已填写"
    }

    private static func boolLabel(_ value: Bool) -> String {
        value ? "是" : "否"
    }
}
