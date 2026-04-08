import Foundation

public struct AppPaths: Codable, Equatable, Sendable {
    public var configPath: String
    public var authPath: String

    private static let defaultCodexDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex", isDirectory: true)

    public init(configPath: String, authPath: String) {
        self.configPath = configPath
        self.authPath = authPath
    }

    public static let `default` = AppPaths(
        configPath: defaultCodexDirectory.appendingPathComponent("config.toml").path,
        authPath: defaultCodexDirectory.appendingPathComponent("auth.json").path
    )
}

public struct ManagedAppTarget: Codable, Equatable, Sendable {
    public var displayName: String
    public var bundleIdentifier: String
    public var appPath: String

    public init(displayName: String, bundleIdentifier: String, appPath: String) {
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.appPath = appPath
    }

    public static let codex = ManagedAppTarget(
        displayName: "Codex",
        bundleIdentifier: "com.openai.codex",
        appPath: "/Applications/Codex.app"
    )
}

public struct CodexPreset: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var modelProvider: String
    public var model: String
    public var reviewModel: String
    public var modelReasoningEffort: String
    public var disableResponseStorage: Bool
    public var networkAccess: String
    public var windowsWSLSetupAcknowledged: Bool
    public var modelContextWindow: Int
    public var modelAutoCompactTokenLimit: Int
    public var requestMaxRetries: Int?
    public var streamMaxRetries: Int?
    public var streamIdleTimeoutMs: Int?
    public var providerName: String
    public var baseURL: String
    public var wireAPI: String
    public var requiresOpenAIAuth: Bool
    public var authMode: String
    public var apiKey: String

    public init(
        id: UUID = UUID(),
        name: String,
        modelProvider: String = "OpenAI",
        model: String = "gpt-5.4",
        reviewModel: String = "gpt-5.4",
        modelReasoningEffort: String = "xhigh",
        disableResponseStorage: Bool = true,
        networkAccess: String = "enabled",
        windowsWSLSetupAcknowledged: Bool = true,
        modelContextWindow: Int = 1_000_000,
        modelAutoCompactTokenLimit: Int = 900_000,
        requestMaxRetries: Int? = nil,
        streamMaxRetries: Int? = nil,
        streamIdleTimeoutMs: Int? = nil,
        providerName: String = "OpenAI",
        baseURL: String = "https://api.openai.com/v1",
        wireAPI: String = "responses",
        requiresOpenAIAuth: Bool = true,
        authMode: String = "apikey",
        apiKey: String = ""
    ) {
        self.id = id
        self.name = name
        self.modelProvider = modelProvider
        self.model = model
        self.reviewModel = reviewModel
        self.modelReasoningEffort = modelReasoningEffort
        self.disableResponseStorage = disableResponseStorage
        self.networkAccess = networkAccess
        self.windowsWSLSetupAcknowledged = windowsWSLSetupAcknowledged
        self.modelContextWindow = modelContextWindow
        self.modelAutoCompactTokenLimit = modelAutoCompactTokenLimit
        self.requestMaxRetries = requestMaxRetries
        self.streamMaxRetries = streamMaxRetries
        self.streamIdleTimeoutMs = streamIdleTimeoutMs
        self.providerName = providerName
        self.baseURL = baseURL
        self.wireAPI = wireAPI
        self.requiresOpenAIAuth = requiresOpenAIAuth
        self.authMode = authMode
        self.apiKey = apiKey
    }

    public static func sample(name: String = "默认预设") -> CodexPreset {
        CodexPreset(name: name)
    }
}

public struct LiveConfigurationSnapshot: Equatable, Sendable {
    public var preset: CodexPreset
    public var loadedAt: Date

    public init(preset: CodexPreset, loadedAt: Date = .now) {
        self.preset = preset
        self.loadedAt = loadedAt
    }
}

public struct ApplyResult: Equatable, Sendable {
    public var appliedAt: Date
    public var configBackupPath: String?
    public var authBackupPath: String?

    public init(appliedAt: Date = .now, configBackupPath: String?, authBackupPath: String?) {
        self.appliedAt = appliedAt
        self.configBackupPath = configBackupPath
        self.authBackupPath = authBackupPath
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var paths: AppPaths
    public var selectedPresetID: UUID?
    public var restartPromptEnabled: Bool
    public var targetApp: ManagedAppTarget

    public init(
        paths: AppPaths = .default,
        selectedPresetID: UUID? = nil,
        restartPromptEnabled: Bool = true,
        targetApp: ManagedAppTarget = .codex
    ) {
        self.paths = paths
        self.selectedPresetID = selectedPresetID
        self.restartPromptEnabled = restartPromptEnabled
        self.targetApp = targetApp
    }

    enum CodingKeys: String, CodingKey {
        case paths
        case selectedPresetID
        case restartPromptEnabled
        case targetApp
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.paths = try container.decodeIfPresent(AppPaths.self, forKey: .paths) ?? .default
        self.selectedPresetID = try container.decodeIfPresent(UUID.self, forKey: .selectedPresetID)
        self.restartPromptEnabled = try container.decodeIfPresent(Bool.self, forKey: .restartPromptEnabled) ?? true
        self.targetApp = try container.decodeIfPresent(ManagedAppTarget.self, forKey: .targetApp) ?? .codex
    }
}

public enum ConfigSwitchError: LocalizedError {
    case fileMissing(String)
    case invalidFormat(String)
    case cannotCreateAppSupport(String)
    case ioFailure(String)

    public var errorDescription: String? {
        switch self {
        case .fileMissing(let message),
             .invalidFormat(let message),
             .cannotCreateAppSupport(let message),
             .ioFailure(let message):
            return message
        }
    }
}
