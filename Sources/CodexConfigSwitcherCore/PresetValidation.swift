import Foundation

public enum PresetValidationIssue: Equatable, Sendable {
    case emptyName
    case invalidBaseURL
    case invalidAccountPortalURL
    case emptyModel
    case emptyReviewModel
    case emptyAuthMode
    case missingAPIKey
    case invalidContextWindow
    case invalidAutoCompactTokenLimit

    public var message: String {
        switch self {
        case .emptyName:
            "预设名称不能为空。"
        case .invalidBaseURL:
            "接口地址必须是合法的 http 或 https URL。"
        case .invalidAccountPortalURL:
            "站点门户地址必须是合法的 http 或 https URL。"
        case .emptyModel:
            "主模型不能为空。"
        case .emptyReviewModel:
            "评审模型不能为空。"
        case .emptyAuthMode:
            "认证模式不能为空。"
        case .missingAPIKey:
            "当前认证模式需要填写 API Key。"
        case .invalidContextWindow:
            "上下文窗口大小必须大于 0。"
        case .invalidAutoCompactTokenLimit:
            "自动压缩 token 限制必须大于 0。"
        }
    }
}

public struct PresetValidationResult: Equatable, Sendable {
    public let issues: [PresetValidationIssue]

    public init(issues: [PresetValidationIssue]) {
        self.issues = issues
    }

    public var isValid: Bool {
        issues.isEmpty
    }

    public var summary: String? {
        guard !issues.isEmpty else {
            return nil
        }

        return issues.map(\.message).joined(separator: "\n")
    }
}

public enum PresetValidator {
    public static func validate(_ preset: CodexPreset) -> PresetValidationResult {
        var issues: [PresetValidationIssue] = []

        if preset.name.trimmedForValidation.isEmpty {
            issues.append(.emptyName)
        }

        let trimmedBaseURL = preset.baseURL.trimmedForValidation
        if !isValidBaseURL(trimmedBaseURL) {
            issues.append(.invalidBaseURL)
        }

        let trimmedAccountPortalURL = preset.accountPortalURL.trimmedForValidation
        if !trimmedAccountPortalURL.isEmpty, !isValidBaseURL(trimmedAccountPortalURL) {
            issues.append(.invalidAccountPortalURL)
        }

        if preset.model.trimmedForValidation.isEmpty {
            issues.append(.emptyModel)
        }

        if preset.reviewModel.trimmedForValidation.isEmpty {
            issues.append(.emptyReviewModel)
        }

        let trimmedAuthMode = preset.authMode.trimmedForValidation
        if trimmedAuthMode.isEmpty {
            issues.append(.emptyAuthMode)
        }

        if trimmedAuthMode.caseInsensitiveCompare("apikey") == .orderedSame,
           preset.apiKey.trimmedForValidation.isEmpty {
            issues.append(.missingAPIKey)
        }

        if preset.modelContextWindow <= 0 {
            issues.append(.invalidContextWindow)
        }

        if preset.modelAutoCompactTokenLimit <= 0 {
            issues.append(.invalidAutoCompactTokenLimit)
        }

        return PresetValidationResult(issues: issues)
    }

    private static func isValidBaseURL(_ value: String) -> Bool {
        guard
            !value.isEmpty,
            let components = URLComponents(string: value),
            let scheme = components.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            components.host?.isEmpty == false
        else {
            return false
        }

        return true
    }
}

private extension String {
    var trimmedForValidation: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
