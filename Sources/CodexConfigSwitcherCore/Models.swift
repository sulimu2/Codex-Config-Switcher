import Foundation

public struct AppPaths: Codable, Equatable, Sendable {
    public var configPath: String
    public var authPath: String

    public init(configPath: String, authPath: String) {
        self.configPath = configPath
        self.authPath = authPath
    }

    public static var `default`: AppPaths {
        PlatformDefaults.defaultPaths()
    }
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

    public static var codex: ManagedAppTarget {
        PlatformDefaults.defaultTargetApp()
    }
}

public enum PresetEnvironmentTag: String, Codable, Equatable, Sendable, CaseIterable {
    case official
    case proxy
    case test
    case backup

    public var title: String {
        switch self {
        case .official:
            "官方"
        case .proxy:
            "代理"
        case .test:
            "测试"
        case .backup:
            "备用"
        }
    }

    public var isHighRisk: Bool {
        self == .proxy
    }

    public static func infer(from baseURL: String) -> PresetEnvironmentTag {
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBaseURL.isEmpty else {
            return .official
        }

        guard let host = URL(string: trimmedBaseURL)?.host?.lowercased() else {
            return .proxy
        }

        if host == "api.openai.com" {
            return .official
        }

        if host == "localhost"
            || host == "127.0.0.1"
            || host.contains("test")
            || host.contains("staging")
            || host.contains("sandbox") {
            return .test
        }

        return .proxy
    }
}

public struct CodexPreset: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var environmentTag: PresetEnvironmentTag
    public var accountPortalURL: String
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
        environmentTag: PresetEnvironmentTag = .official,
        accountPortalURL: String = "",
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
        self.environmentTag = environmentTag
        self.accountPortalURL = accountPortalURL
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

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case environmentTag
        case accountPortalURL
        case modelProvider
        case model
        case reviewModel
        case modelReasoningEffort
        case disableResponseStorage
        case networkAccess
        case windowsWSLSetupAcknowledged
        case modelContextWindow
        case modelAutoCompactTokenLimit
        case requestMaxRetries
        case streamMaxRetries
        case streamIdleTimeoutMs
        case providerName
        case baseURL
        case wireAPI
        case requiresOpenAIAuth
        case authMode
        case apiKey
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedBaseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? "https://api.openai.com/v1"

        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.environmentTag = try container.decodeIfPresent(PresetEnvironmentTag.self, forKey: .environmentTag)
            ?? PresetEnvironmentTag.infer(from: decodedBaseURL)
        self.accountPortalURL = try container.decodeIfPresent(String.self, forKey: .accountPortalURL) ?? ""
        self.modelProvider = try container.decodeIfPresent(String.self, forKey: .modelProvider) ?? "OpenAI"
        self.model = try container.decodeIfPresent(String.self, forKey: .model) ?? "gpt-5.4"
        self.reviewModel = try container.decodeIfPresent(String.self, forKey: .reviewModel) ?? "gpt-5.4"
        self.modelReasoningEffort = try container.decodeIfPresent(String.self, forKey: .modelReasoningEffort) ?? "xhigh"
        self.disableResponseStorage = try container.decodeIfPresent(Bool.self, forKey: .disableResponseStorage) ?? true
        self.networkAccess = try container.decodeIfPresent(String.self, forKey: .networkAccess) ?? "enabled"
        self.windowsWSLSetupAcknowledged = try container.decodeIfPresent(Bool.self, forKey: .windowsWSLSetupAcknowledged) ?? true
        self.modelContextWindow = try container.decodeIfPresent(Int.self, forKey: .modelContextWindow) ?? 1_000_000
        self.modelAutoCompactTokenLimit = try container.decodeIfPresent(Int.self, forKey: .modelAutoCompactTokenLimit) ?? 900_000
        self.requestMaxRetries = try container.decodeIfPresent(Int.self, forKey: .requestMaxRetries)
        self.streamMaxRetries = try container.decodeIfPresent(Int.self, forKey: .streamMaxRetries)
        self.streamIdleTimeoutMs = try container.decodeIfPresent(Int.self, forKey: .streamIdleTimeoutMs)
        self.providerName = try container.decodeIfPresent(String.self, forKey: .providerName) ?? "OpenAI"
        self.baseURL = decodedBaseURL
        self.wireAPI = try container.decodeIfPresent(String.self, forKey: .wireAPI) ?? "responses"
        self.requiresOpenAIAuth = try container.decodeIfPresent(Bool.self, forKey: .requiresOpenAIAuth) ?? true
        self.authMode = try container.decodeIfPresent(String.self, forKey: .authMode) ?? "apikey"
        self.apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
    }
}

public struct ManagedPresetFingerprint: Equatable, Sendable {
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
        modelProvider: String,
        model: String,
        reviewModel: String,
        modelReasoningEffort: String,
        disableResponseStorage: Bool,
        networkAccess: String,
        windowsWSLSetupAcknowledged: Bool,
        modelContextWindow: Int,
        modelAutoCompactTokenLimit: Int,
        requestMaxRetries: Int?,
        streamMaxRetries: Int?,
        streamIdleTimeoutMs: Int?,
        providerName: String,
        baseURL: String,
        wireAPI: String,
        requiresOpenAIAuth: Bool,
        authMode: String,
        apiKey: String
    ) {
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
}

public extension CodexPreset {
    var managedFingerprint: ManagedPresetFingerprint {
        ManagedPresetFingerprint(
            modelProvider: modelProvider,
            model: model,
            reviewModel: reviewModel,
            modelReasoningEffort: modelReasoningEffort,
            disableResponseStorage: disableResponseStorage,
            networkAccess: networkAccess,
            windowsWSLSetupAcknowledged: windowsWSLSetupAcknowledged,
            modelContextWindow: modelContextWindow,
            modelAutoCompactTokenLimit: modelAutoCompactTokenLimit,
            requestMaxRetries: requestMaxRetries,
            streamMaxRetries: streamMaxRetries,
            streamIdleTimeoutMs: streamIdleTimeoutMs,
            providerName: providerName,
            baseURL: baseURL,
            wireAPI: wireAPI,
            requiresOpenAIAuth: requiresOpenAIAuth,
            authMode: authMode,
            apiKey: apiKey
        )
    }
}

public struct CodexTemplate: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var environmentTag: PresetEnvironmentTag
    public var accountPortalURL: String
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

    public init(
        id: UUID = UUID(),
        name: String,
        environmentTag: PresetEnvironmentTag = .official,
        accountPortalURL: String = "",
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
        authMode: String = "apikey"
    ) {
        self.id = id
        self.name = name
        self.environmentTag = environmentTag
        self.accountPortalURL = accountPortalURL
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
    }

    public init(id: UUID = UUID(), preset: CodexPreset, name: String? = nil) {
        self.init(
            id: id,
            name: name ?? preset.name,
            environmentTag: preset.environmentTag,
            accountPortalURL: preset.accountPortalURL,
            modelProvider: preset.modelProvider,
            model: preset.model,
            reviewModel: preset.reviewModel,
            modelReasoningEffort: preset.modelReasoningEffort,
            disableResponseStorage: preset.disableResponseStorage,
            networkAccess: preset.networkAccess,
            windowsWSLSetupAcknowledged: preset.windowsWSLSetupAcknowledged,
            modelContextWindow: preset.modelContextWindow,
            modelAutoCompactTokenLimit: preset.modelAutoCompactTokenLimit,
            requestMaxRetries: preset.requestMaxRetries,
            streamMaxRetries: preset.streamMaxRetries,
            streamIdleTimeoutMs: preset.streamIdleTimeoutMs,
            providerName: preset.providerName,
            baseURL: preset.baseURL,
            wireAPI: preset.wireAPI,
            requiresOpenAIAuth: preset.requiresOpenAIAuth,
            authMode: preset.authMode
        )
    }

    public func makePreset(id: UUID = UUID(), name: String? = nil) -> CodexPreset {
        CodexPreset(
            id: id,
            name: name ?? self.name,
            environmentTag: environmentTag,
            accountPortalURL: accountPortalURL,
            modelProvider: modelProvider,
            model: model,
            reviewModel: reviewModel,
            modelReasoningEffort: modelReasoningEffort,
            disableResponseStorage: disableResponseStorage,
            networkAccess: networkAccess,
            windowsWSLSetupAcknowledged: windowsWSLSetupAcknowledged,
            modelContextWindow: modelContextWindow,
            modelAutoCompactTokenLimit: modelAutoCompactTokenLimit,
            requestMaxRetries: requestMaxRetries,
            streamMaxRetries: streamMaxRetries,
            streamIdleTimeoutMs: streamIdleTimeoutMs,
            providerName: providerName,
            baseURL: baseURL,
            wireAPI: wireAPI,
            requiresOpenAIAuth: requiresOpenAIAuth,
            authMode: authMode,
            apiKey: ""
        )
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

public struct BackupSnapshotSummary: Equatable, Sendable {
    public var directoryPath: String
    public var createdAt: Date
    public var configBackupPath: String?
    public var authBackupPath: String?

    public init(directoryPath: String, createdAt: Date, configBackupPath: String?, authBackupPath: String?) {
        self.directoryPath = directoryPath
        self.createdAt = createdAt
        self.configBackupPath = configBackupPath
        self.authBackupPath = authBackupPath
    }
}

public struct RestoreResult: Equatable, Sendable {
    public var restoredAt: Date
    public var sourceBackupDirectoryPath: String
    public var rollbackConfigBackupPath: String?
    public var rollbackAuthBackupPath: String?

    public init(
        restoredAt: Date = .now,
        sourceBackupDirectoryPath: String,
        rollbackConfigBackupPath: String?,
        rollbackAuthBackupPath: String?
    ) {
        self.restoredAt = restoredAt
        self.sourceBackupDirectoryPath = sourceBackupDirectoryPath
        self.rollbackConfigBackupPath = rollbackConfigBackupPath
        self.rollbackAuthBackupPath = rollbackAuthBackupPath
    }
}

public enum PresetEditorMode: String, Codable, Equatable, Sendable, CaseIterable {
    case basic
    case advanced
}

public enum PresetOperationKind: String, Codable, Equatable, Sendable {
    case applyPreset
    case restoreBackup

    public var title: String {
        switch self {
        case .applyPreset:
            "应用预设"
        case .restoreBackup:
            "恢复备份"
        }
    }
}

public enum PresetOperationOutcome: String, Codable, Equatable, Sendable {
    case success
    case failure

    public var title: String {
        switch self {
        case .success:
            "成功"
        case .failure:
            "失败"
        }
    }
}

public struct PresetOperationHistoryEntry: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var operatedAt: Date
    public var kind: PresetOperationKind
    public var outcome: PresetOperationOutcome
    public var presetID: UUID?
    public var presetName: String
    public var environmentTag: PresetEnvironmentTag?
    public var detail: String

    public init(
        id: UUID = UUID(),
        operatedAt: Date = .now,
        kind: PresetOperationKind,
        outcome: PresetOperationOutcome,
        presetID: UUID?,
        presetName: String,
        environmentTag: PresetEnvironmentTag?,
        detail: String
    ) {
        self.id = id
        self.operatedAt = operatedAt
        self.kind = kind
        self.outcome = outcome
        self.presetID = presetID
        self.presetName = presetName
        self.environmentTag = environmentTag
        self.detail = detail
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var paths: AppPaths
    public var selectedPresetID: UUID?
    public var restartPromptEnabled: Bool
    public var targetApp: ManagedAppTarget
    public var lastAppliedPresetID: UUID?
    public var lastAppliedAt: Date?
    public var favoritePresetIDs: [UUID]
    public var recentPresetIDs: [UUID]
    public var presetEditorMode: PresetEditorMode
    public var operationHistory: [PresetOperationHistoryEntry]
    public var hasCompletedOnboarding: Bool
    public var onboardingVersion: Int

    public init(
        paths: AppPaths = .default,
        selectedPresetID: UUID? = nil,
        restartPromptEnabled: Bool = true,
        targetApp: ManagedAppTarget = .codex,
        lastAppliedPresetID: UUID? = nil,
        lastAppliedAt: Date? = nil,
        favoritePresetIDs: [UUID] = [],
        recentPresetIDs: [UUID] = [],
        presetEditorMode: PresetEditorMode = .basic,
        operationHistory: [PresetOperationHistoryEntry] = [],
        hasCompletedOnboarding: Bool = true,
        onboardingVersion: Int = 0
    ) {
        self.paths = paths
        self.selectedPresetID = selectedPresetID
        self.restartPromptEnabled = restartPromptEnabled
        self.targetApp = targetApp
        self.lastAppliedPresetID = lastAppliedPresetID
        self.lastAppliedAt = lastAppliedAt
        self.favoritePresetIDs = favoritePresetIDs
        self.recentPresetIDs = recentPresetIDs
        self.presetEditorMode = presetEditorMode
        self.operationHistory = operationHistory
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.onboardingVersion = onboardingVersion
    }

    enum CodingKeys: String, CodingKey {
        case paths
        case selectedPresetID
        case restartPromptEnabled
        case targetApp
        case lastAppliedPresetID
        case lastAppliedAt
        case favoritePresetIDs
        case recentPresetIDs
        case presetEditorMode
        case operationHistory
        case hasCompletedOnboarding
        case onboardingVersion
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.paths = try container.decodeIfPresent(AppPaths.self, forKey: .paths) ?? .default
        self.selectedPresetID = try container.decodeIfPresent(UUID.self, forKey: .selectedPresetID)
        self.restartPromptEnabled = try container.decodeIfPresent(Bool.self, forKey: .restartPromptEnabled) ?? true
        self.targetApp = try container.decodeIfPresent(ManagedAppTarget.self, forKey: .targetApp) ?? .codex
        self.lastAppliedPresetID = try container.decodeIfPresent(UUID.self, forKey: .lastAppliedPresetID)
        self.lastAppliedAt = try container.decodeIfPresent(Date.self, forKey: .lastAppliedAt)
        self.favoritePresetIDs = try container.decodeIfPresent([UUID].self, forKey: .favoritePresetIDs) ?? []
        self.recentPresetIDs = try container.decodeIfPresent([UUID].self, forKey: .recentPresetIDs) ?? []
        self.presetEditorMode = try container.decodeIfPresent(PresetEditorMode.self, forKey: .presetEditorMode) ?? .basic
        self.operationHistory = try container.decodeIfPresent([PresetOperationHistoryEntry].self, forKey: .operationHistory) ?? []
        self.hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? true
        self.onboardingVersion = try container.decodeIfPresent(Int.self, forKey: .onboardingVersion) ?? 0
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
