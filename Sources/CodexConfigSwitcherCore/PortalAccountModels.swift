import Foundation

public enum PortalAccountError: LocalizedError, Equatable, Sendable {
    case missingSession
    case missingAccessToken
    case invalidPortalURL
    case invalidAPIBaseURL
    case invalidResponse(String)
    case unauthorized(statusCode: Int)
    case refreshUnavailable
    case requestFailed(statusCode: Int, message: String?)

    public var errorDescription: String? {
        switch self {
        case .missingSession:
            return "当前没有可用的门户账号会话。"
        case .missingAccessToken:
            return "缺少可用的访问令牌，无法请求门户接口。"
        case .invalidPortalURL:
            return "门户地址不是合法的 http 或 https URL。"
        case .invalidAPIBaseURL:
            return "预设接口地址不是合法的 http 或 https URL。"
        case .invalidResponse(let message):
            return message
        case .unauthorized:
            return "门户鉴权失败，请检查访问令牌或刷新令牌是否仍然有效。"
        case .refreshUnavailable:
            return "当前会话没有可用的刷新令牌，无法自动刷新。"
        case .requestFailed(let statusCode, let message):
            if let message, message.isEmpty == false {
                return "门户请求失败（\(statusCode)）：\(message)"
            }
            return "门户请求失败，状态码：\(statusCode)。"
        }
    }
}

public struct PortalAccountSession: Codable, Equatable, Sendable {
    public var portalURL: URL
    public var accessToken: String
    public var refreshToken: String?
    public var expiresAt: Date?
    public var tokenType: String

    public init(
        portalURL: URL,
        accessToken: String,
        refreshToken: String? = nil,
        expiresAt: Date? = nil,
        tokenType: String = "Bearer"
    ) {
        self.portalURL = portalURL
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.tokenType = tokenType
    }

    public var canRefresh: Bool {
        normalizedRefreshToken != nil
    }

    public var tokenExpiresAt: Date? {
        expiresAt
    }

    public func needsRefresh(referenceDate: Date = Date(), leeway: TimeInterval = 60) -> Bool {
        guard let expiresAt else {
            return false
        }

        return expiresAt.timeIntervalSince(referenceDate) <= leeway
    }

    var normalizedAccessToken: String {
        accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedRefreshToken: String? {
        let token = refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return token.isEmpty ? nil : token
    }

    var authorizationValue: String {
        let normalizedTokenType = tokenType.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTokenType = normalizedTokenType.isEmpty ? "Bearer" : normalizedTokenType
        return "\(resolvedTokenType) \(normalizedAccessToken)"
    }

    init?(
        refreshPayload: [String: Any],
        portalURL: URL,
        fallbackRefreshToken: String?,
        fallbackTokenType: String,
        referenceDate: Date
    ) {
        guard
            let accessToken = PortalPayloadDecoder.string(
                in: refreshPayload,
                keys: ["accessToken", "access_token", "token", "idToken", "id_token"]
            ),
            accessToken.isEmpty == false
        else {
            return nil
        }

        self.portalURL = portalURL
        self.accessToken = accessToken
        self.refreshToken = PortalPayloadDecoder.string(
            in: refreshPayload,
            keys: ["refreshToken", "refresh_token"]
        ) ?? fallbackRefreshToken
        self.tokenType = PortalPayloadDecoder.string(
            in: refreshPayload,
            keys: ["tokenType", "token_type"]
        ) ?? fallbackTokenType

        if let expiresAt = PortalPayloadDecoder.date(
            in: refreshPayload,
            keys: ["expiresAt", "expires_at", "accessTokenExpiresAt", "access_token_expires_at"]
        ) {
            self.expiresAt = expiresAt
        } else if let expiresIn = PortalPayloadDecoder.double(
            in: refreshPayload,
            keys: ["expiresIn", "expires_in", "accessTokenExpiresIn", "access_token_expires_in"]
        ) {
            self.expiresAt = referenceDate.addingTimeInterval(expiresIn)
        } else {
            self.expiresAt = nil
        }
    }
}

public struct PortalAccountProfile: Codable, Equatable, Sendable {
    public var id: String?
    public var email: String?
    public var name: String
    public var balance: Double?
    public var concurrency: Int?
    public var createdAtRaw: String?
    public var role: String?
    public var avatarURL: String?

    public init(
        id: String? = nil,
        email: String? = nil,
        name: String = "",
        balance: Double? = nil,
        concurrency: Int? = nil,
        createdAtRaw: String? = nil,
        role: String? = nil,
        avatarURL: String? = nil
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.balance = balance
        self.concurrency = concurrency
        self.createdAtRaw = createdAtRaw
        self.role = role
        self.avatarURL = avatarURL
    }

    public var username: String? {
        name.isEmpty ? nil : name
    }

    init(payload: [String: Any]) {
        let id = PortalPayloadDecoder.string(in: payload, keys: ["id", "userId", "user_id", "uid"])
        let email = PortalPayloadDecoder.string(in: payload, keys: ["email", "mail"])
        let name = PortalPayloadDecoder.string(
            in: payload,
            keys: ["displayName", "display_name", "name", "username", "userName", "nickname", "nickName"]
        )

        self.id = id
        self.email = email
        self.name = name ?? email ?? id ?? ""
        self.balance = PortalPayloadDecoder.double(in: payload, keys: ["balance", "quota", "availableQuota", "available_quota"])
        self.concurrency = PortalPayloadDecoder.int(in: payload, keys: ["concurrency", "concurrentRequests", "concurrent_requests"])
        self.createdAtRaw = PortalPayloadDecoder.string(in: payload, keys: ["createdAt", "created_at", "createdAtRaw", "created_at_raw"])
        self.role = PortalPayloadDecoder.string(in: payload, keys: ["role", "group", "accessLevel", "access_level"])
        self.avatarURL = PortalPayloadDecoder.string(in: payload, keys: ["avatar", "avatarUrl", "avatar_url"])
    }
}

public struct PortalAccountUsageStats: Codable, Equatable, Sendable {
    public var requestCount: Int?
    public var inputTokenCount: Int?
    public var outputTokenCount: Int?
    public var totalTokenCount: Int?
    public var todayRequestCount: Int?
    public var todayInputTokenCount: Int?
    public var todayOutputTokenCount: Int?
    public var todayTokenCount: Int?
    public var requestsPerMinute: Int?
    public var tokensPerMinute: Int?
    public var quota: Double?
    public var usedQuota: Double?
    public var remainingQuota: Double?

    public init(
        requestCount: Int? = nil,
        inputTokenCount: Int? = nil,
        outputTokenCount: Int? = nil,
        totalTokenCount: Int? = nil,
        todayRequestCount: Int? = nil,
        todayInputTokenCount: Int? = nil,
        todayOutputTokenCount: Int? = nil,
        todayTokenCount: Int? = nil,
        requestsPerMinute: Int? = nil,
        tokensPerMinute: Int? = nil,
        quota: Double? = nil,
        usedQuota: Double? = nil,
        remainingQuota: Double? = nil
    ) {
        self.requestCount = requestCount
        self.inputTokenCount = inputTokenCount
        self.outputTokenCount = outputTokenCount
        self.totalTokenCount = totalTokenCount
        self.todayRequestCount = todayRequestCount
        self.todayInputTokenCount = todayInputTokenCount
        self.todayOutputTokenCount = todayOutputTokenCount
        self.todayTokenCount = todayTokenCount
        self.requestsPerMinute = requestsPerMinute
        self.tokensPerMinute = tokensPerMinute
        self.quota = quota
        self.usedQuota = usedQuota
        self.remainingQuota = remainingQuota
    }

    public var totalRequests: Int? {
        requestCount
    }

    public var totalInputTokens: Int? {
        inputTokenCount
    }

    public var totalOutputTokens: Int? {
        outputTokenCount
    }

    public var totalTokens: Int? {
        totalTokenCount
    }

    public var todayRequests: Int? {
        todayRequestCount
    }

    public var todayInputTokens: Int? {
        todayInputTokenCount
    }

    public var todayOutputTokens: Int? {
        todayOutputTokenCount
    }

    public var todayTokens: Int? {
        todayTokenCount ?? {
            guard let todayInputTokenCount, let todayOutputTokenCount else {
                return nil
            }
            return todayInputTokenCount + todayOutputTokenCount
        }()
    }

    public var rpm: Int? {
        requestsPerMinute
    }

    public var tpm: Int? {
        tokensPerMinute
    }

    init(payload: [String: Any]) {
        let requestCount = PortalPayloadDecoder.int(
            in: payload,
            keys: ["totalRequests", "total_requests", "requestCount", "request_count", "requests", "count"]
        )
        let inputTokenCount = PortalPayloadDecoder.int(
            in: payload,
            keys: ["totalInputTokens", "total_input_tokens", "inputTokenCount", "input_token_count", "promptTokens", "prompt_tokens", "inputTokens", "input_tokens"]
        )
        let outputTokenCount = PortalPayloadDecoder.int(
            in: payload,
            keys: ["totalOutputTokens", "total_output_tokens", "outputTokenCount", "output_token_count", "completionTokens", "completion_tokens", "outputTokens", "output_tokens"]
        )
        let totalTokenCount = PortalPayloadDecoder.int(
            in: payload,
            keys: ["totalTokenCount", "total_token_count", "totalTokens", "total_tokens", "tokens"]
        )
        let todayRequestCount = PortalPayloadDecoder.int(
            in: payload,
            keys: ["todayRequests", "today_requests", "currentRequests", "current_requests"]
        )
        let todayInputTokenCount = PortalPayloadDecoder.int(
            in: payload,
            keys: ["todayInputTokens", "today_input_tokens", "currentInputTokens", "current_input_tokens"]
        )
        let todayOutputTokenCount = PortalPayloadDecoder.int(
            in: payload,
            keys: ["todayOutputTokens", "today_output_tokens", "currentOutputTokens", "current_output_tokens"]
        )
        let todayTokenCount = PortalPayloadDecoder.int(
            in: payload,
            keys: ["todayTokens", "today_tokens", "currentTokens", "current_tokens"]
        )
        let requestsPerMinute = PortalPayloadDecoder.int(
            in: payload,
            keys: ["rpm", "requestsPerMinute", "requests_per_minute"]
        )
        let tokensPerMinute = PortalPayloadDecoder.int(
            in: payload,
            keys: ["tpm", "tokensPerMinute", "tokens_per_minute"]
        )
        let quota = PortalPayloadDecoder.double(in: payload, keys: ["quota", "totalQuota", "total_quota"])
        let usedQuota = PortalPayloadDecoder.double(
            in: payload,
            keys: ["usedQuota", "used_quota", "consumedQuota", "consumed_quota"]
        )
        let remainingQuota: Double?
        if let explicitRemaining = PortalPayloadDecoder.double(
            in: payload,
            keys: ["remainingQuota", "remaining_quota", "availableQuota", "available_quota"]
        ) {
            remainingQuota = explicitRemaining
        } else if let quota, let usedQuota {
            remainingQuota = quota - usedQuota
        } else {
            remainingQuota = nil
        }

        self.requestCount = requestCount
        self.inputTokenCount = inputTokenCount
        self.outputTokenCount = outputTokenCount
        self.totalTokenCount = totalTokenCount
        self.todayRequestCount = todayRequestCount
        self.todayInputTokenCount = todayInputTokenCount
        self.todayOutputTokenCount = todayOutputTokenCount
        self.todayTokenCount = todayTokenCount
        self.requestsPerMinute = requestsPerMinute
        self.tokensPerMinute = tokensPerMinute
        self.quota = quota
        self.usedQuota = usedQuota
        self.remainingQuota = remainingQuota
    }
}

public struct PortalAccountUsageModel: Codable, Equatable, Sendable, Identifiable {
    public var modelID: String
    public var requestCount: Int?
    public var inputTokenCount: Int?
    public var outputTokenCount: Int?
    public var totalTokenCount: Int?
    public var quota: Double?

    public var id: String {
        modelID
    }

    public var model: String {
        modelID
    }

    public var totalTokens: Int {
        if let totalTokenCount {
            return totalTokenCount
        }
        if let inputTokenCount, let outputTokenCount {
            return inputTokenCount + outputTokenCount
        }
        return 0
    }

    public init(
        modelID: String,
        requestCount: Int? = nil,
        inputTokenCount: Int? = nil,
        outputTokenCount: Int? = nil,
        totalTokenCount: Int? = nil,
        quota: Double? = nil
    ) {
        self.modelID = modelID
        self.requestCount = requestCount
        self.inputTokenCount = inputTokenCount
        self.outputTokenCount = outputTokenCount
        self.totalTokenCount = totalTokenCount
        self.quota = quota
    }

    init?(payload: [String: Any]) {
        guard
            let modelID = PortalPayloadDecoder.string(
                in: payload,
                keys: ["model", "modelId", "model_id", "name", "id"]
            ),
            modelID.isEmpty == false
        else {
            return nil
        }

        self.modelID = modelID
        self.requestCount = PortalPayloadDecoder.int(
            in: payload,
            keys: ["requestCount", "request_count", "requests", "count"]
        )
        self.inputTokenCount = PortalPayloadDecoder.int(
            in: payload,
            keys: ["inputTokenCount", "input_token_count", "promptTokens", "prompt_tokens", "inputTokens", "input_tokens"]
        )
        self.outputTokenCount = PortalPayloadDecoder.int(
            in: payload,
            keys: ["outputTokenCount", "output_token_count", "completionTokens", "completion_tokens", "outputTokens", "output_tokens"]
        )
        self.totalTokenCount = PortalPayloadDecoder.int(
            in: payload,
            keys: ["totalTokenCount", "total_token_count", "totalTokens", "total_tokens", "tokens"]
        )
        self.quota = PortalPayloadDecoder.double(in: payload, keys: ["quota", "usedQuota", "used_quota"])
    }
}

public struct PortalAvailableModel: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var ownedBy: String?
    public var createdAt: Date?

    public init(id: String, ownedBy: String? = nil, createdAt: Date? = nil) {
        self.id = id
        self.ownedBy = ownedBy
        self.createdAt = createdAt
    }

    init?(payload: [String: Any]) {
        guard
            let id = PortalPayloadDecoder.string(in: payload, keys: ["id", "name", "model", "modelId", "model_id"]),
            id.isEmpty == false
        else {
            return nil
        }

        self.id = id
        self.ownedBy = PortalPayloadDecoder.string(in: payload, keys: ["ownedBy", "owned_by", "owner"])
        self.createdAt = PortalPayloadDecoder.date(in: payload, keys: ["createdAt", "created_at", "created"])
    }
}

public struct PortalAccountSnapshot: Codable, Equatable, Sendable {
    public var profile: PortalAccountProfile
    public var stats: PortalAccountUsageStats
    public var usageModels: [PortalAccountUsageModel]

    public init(
        profile: PortalAccountProfile,
        stats: PortalAccountUsageStats,
        usageModels: [PortalAccountUsageModel]
    ) {
        self.profile = profile
        self.stats = stats
        self.usageModels = usageModels
    }
}

public struct PortalAuthenticatedUser: Equatable, Sendable, Codable {
    public var id: String?
    public var email: String?
    public var username: String?
    public var balance: Double?
    public var concurrency: Int?
    public var createdAtRaw: String?
    public var role: String?
    public var organizationName: String?

    public init(
        id: String? = nil,
        email: String? = nil,
        username: String? = nil,
        balance: Double? = nil,
        concurrency: Int? = nil,
        createdAtRaw: String? = nil,
        role: String? = nil,
        organizationName: String? = nil
    ) {
        self.id = id
        self.email = email
        self.username = username
        self.balance = balance
        self.concurrency = concurrency
        self.createdAtRaw = createdAtRaw
        self.role = role
        self.organizationName = organizationName
    }

    public init(profile: PortalAccountProfile) {
        self.id = profile.id
        self.email = profile.email
        self.username = profile.username
        self.balance = profile.balance
        self.concurrency = profile.concurrency
        self.createdAtRaw = profile.createdAtRaw
        self.role = profile.role
        self.organizationName = nil
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: PortalDynamicCodingKey.self)
        self.id = container.decodeString(for: ["id", "user_id", "uid"])
        self.email = container.decodeString(for: ["email", "mail"])
        self.username = container.decodeString(for: ["username", "name", "display_name", "displayName", "nickname"])
        self.balance = container.decodeDouble(for: ["balance", "quota", "available_quota", "availableQuota"])
        self.concurrency = container.decodeInt(for: ["concurrency", "concurrent_requests", "concurrentRequests"])
        self.createdAtRaw = container.decodeString(for: ["createdAtRaw", "created_at_raw", "createdAt", "created_at"])
        self.role = container.decodeString(for: ["role", "group", "access_level", "accessLevel"])
        self.organizationName = container.decodeString(
            for: ["organizationName", "organization_name", "organization", "workspace_name", "team_name"]
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(username, forKey: .username)
        try container.encodeIfPresent(balance, forKey: .balance)
        try container.encodeIfPresent(concurrency, forKey: .concurrency)
        try container.encodeIfPresent(createdAtRaw, forKey: .createdAtRaw)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeIfPresent(organizationName, forKey: .organizationName)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case balance
        case concurrency
        case createdAtRaw
        case role
        case organizationName
    }
}

public struct PortalAccountOverviewRange: Codable, Equatable, Sendable {
    public var startDate: String
    public var endDate: String

    public init(startDate: String = "", endDate: String = "") {
        self.startDate = startDate
        self.endDate = endDate
    }
}

public struct PortalAccountOverview: Codable, Equatable, Sendable {
    public var user: PortalAuthenticatedUser
    public var usageStats: PortalAccountUsageStats
    public var modelUsage: [PortalAccountUsageModel]
    public var availableModels: [String]
    public var range: PortalAccountOverviewRange
    public var refreshedAt: Date

    public init(
        user: PortalAuthenticatedUser,
        usageStats: PortalAccountUsageStats,
        modelUsage: [PortalAccountUsageModel],
        availableModels: [String] = [],
        range: PortalAccountOverviewRange = PortalAccountOverviewRange(),
        refreshedAt: Date = Date()
    ) {
        self.user = user
        self.usageStats = usageStats
        self.modelUsage = modelUsage
        self.availableModels = availableModels
        self.range = range
        self.refreshedAt = refreshedAt
    }

    public init(
        snapshot: PortalAccountSnapshot,
        user: PortalAuthenticatedUser? = nil,
        availableModels: [String] = [],
        range: PortalAccountOverviewRange = PortalAccountOverviewRange(),
        refreshedAt: Date = Date()
    ) {
        self.user = user ?? PortalAuthenticatedUser(profile: snapshot.profile)
        self.usageStats = snapshot.stats
        self.modelUsage = snapshot.usageModels
        self.availableModels = availableModels
        self.range = range
        self.refreshedAt = refreshedAt
    }
}

public struct PresetAccountSessionRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var presetID: UUID?
    public var portalURL: String
    public var accessToken: String
    public var refreshToken: String?
    public var tokenExpiresAt: Date?
    public var cachedUser: PortalAuthenticatedUser?
    public var cachedOverview: PortalAccountOverview?
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        presetID: UUID? = nil,
        portalURL: String,
        accessToken: String,
        refreshToken: String? = nil,
        tokenExpiresAt: Date? = nil,
        cachedUser: PortalAuthenticatedUser? = nil,
        cachedOverview: PortalAccountOverview? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.presetID = presetID
        self.portalURL = portalURL
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenExpiresAt = tokenExpiresAt
        self.cachedUser = cachedUser
        self.cachedOverview = cachedOverview
        self.updatedAt = updatedAt
    }

    public init(
        id: UUID = UUID(),
        presetID: UUID? = nil,
        session: PortalAccountSession,
        cachedUser: PortalAuthenticatedUser? = nil,
        cachedOverview: PortalAccountOverview? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.presetID = presetID
        self.portalURL = session.portalURL.absoluteString
        self.accessToken = session.accessToken
        self.refreshToken = session.refreshToken
        self.tokenExpiresAt = session.tokenExpiresAt
        self.cachedUser = cachedUser
        self.cachedOverview = cachedOverview
        self.updatedAt = updatedAt
    }

    public var portalSession: PortalAccountSession? {
        guard let portalURL = try? PortalURLHelper.normalizedPortalURL(from: portalURL) else {
            return nil
        }

        return PortalAccountSession(
            portalURL: portalURL,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: tokenExpiresAt
        )
    }
}

public struct PortalOverviewRefreshResult: Codable, Equatable, Sendable {
    public var overview: PortalAccountOverview
    public var session: PresetAccountSessionRecord

    public init(overview: PortalAccountOverview, session: PresetAccountSessionRecord) {
        self.overview = overview
        self.session = session
    }
}

public struct PortalLoginCapture: Codable, Equatable, Sendable {
    public var portalURL: String
    public var accessToken: String
    public var refreshToken: String?
    public var tokenExpiresAt: Date?
    public var user: PortalAuthenticatedUser?

    public init(
        portalURL: String,
        accessToken: String,
        refreshToken: String? = nil,
        tokenExpiresAt: Date? = nil,
        user: PortalAuthenticatedUser? = nil
    ) {
        self.portalURL = portalURL
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenExpiresAt = tokenExpiresAt
        self.user = user
    }

    public func makeSession() throws -> PortalAccountSession {
        PortalAccountSession(
            portalURL: try PortalURLHelper.normalizedPortalURL(from: portalURL),
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: tokenExpiresAt
        )
    }

    public func makeSessionRecord(
        id: UUID = UUID(),
        presetID: UUID? = nil,
        cachedOverview: PortalAccountOverview? = nil,
        updatedAt: Date = Date()
    ) throws -> PresetAccountSessionRecord {
        PresetAccountSessionRecord(
            id: id,
            presetID: presetID,
            session: try makeSession(),
            cachedUser: user,
            cachedOverview: cachedOverview,
            updatedAt: updatedAt
        )
    }
}

public enum PortalURLHelper {
    public static func normalizedPortalURL(from rawValue: String) throws -> URL {
        let components = try normalizedComponents(from: rawValue, error: .invalidPortalURL)
        return try requireURL(from: components, error: .invalidPortalURL)
    }

    public static func inferredPortalURL(from preset: CodexPreset) throws -> URL {
        try inferredPortalURL(fromAPIBaseURL: preset.baseURL)
    }

    public static func inferredPortalURL(fromAPIBaseURL baseURL: String) throws -> URL {
        var components = try normalizedComponents(from: baseURL, error: .invalidAPIBaseURL)
        if let host = components.host,
           host.lowercased().hasPrefix("api."),
           host.count > 4 {
            components.host = String(host.dropFirst(4))
        }
        return try requireURL(from: components, error: .invalidAPIBaseURL)
    }

    public static func endpointURL(portalURL: URL, path: String) throws -> URL {
        guard var components = URLComponents(url: portalURL, resolvingAgainstBaseURL: false) else {
            throw PortalAccountError.invalidPortalURL
        }

        let normalizedSuffix = sanitizePath(path)
        let normalizedBase = sanitizePath(components.path)
        if normalizedBase.isEmpty {
            components.path = normalizedSuffix
        } else {
            components.path = normalizedBase + normalizedSuffix
        }
        components.query = nil
        components.fragment = nil
        return try requireURL(from: components, error: .invalidPortalURL)
    }

    public static func modelsEndpoint(from preset: CodexPreset) throws -> URL {
        try modelsEndpoint(fromAPIBaseURL: preset.baseURL)
    }

    public static func modelsEndpoint(fromAPIBaseURL baseURL: String) throws -> URL {
        guard var components = URLComponents(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw PortalAccountError.invalidAPIBaseURL
        }

        let scheme = components.scheme?.lowercased()
        guard
            scheme == "http" || scheme == "https",
            components.host?.isEmpty == false
        else {
            throw PortalAccountError.invalidAPIBaseURL
        }

        let normalizedPath = sanitizePath(components.path)
        if normalizedPath.hasSuffix("/models") {
            components.path = normalizedPath
        } else if normalizedPath.isEmpty {
            components.path = "/models"
        } else {
            components.path = normalizedPath + "/models"
        }

        components.query = nil
        components.fragment = nil
        return try requireURL(from: components, error: .invalidAPIBaseURL)
    }

    private static func normalizedComponents(from rawValue: String, error: PortalAccountError) throws -> URLComponents {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed) else {
            throw error
        }

        let scheme = components.scheme?.lowercased()
        guard
            scheme == "http" || scheme == "https",
            components.host?.isEmpty == false
        else {
            throw error
        }

        components.path = trimPortalPath(components.path)
        components.query = nil
        components.fragment = nil
        return components
    }

    private static func trimPortalPath(_ path: String) -> String {
        let normalizedPath = sanitizePath(path)
        guard normalizedPath.isEmpty == false else {
            return ""
        }

        for suffix in portalPathSuffixes where normalizedPath.hasSuffix(suffix) {
            let trimmedPath = String(normalizedPath.dropLast(suffix.count))
            return sanitizePath(trimmedPath)
        }

        return normalizedPath
    }

    private static func sanitizePath(_ path: String) -> String {
        guard path.isEmpty == false, path != "/" else {
            return ""
        }

        var normalized = path.hasPrefix("/") ? path : "/" + path
        while normalized.count > 1 && normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        return normalized == "/" ? "" : normalized
    }

    private static func requireURL(from components: URLComponents, error: PortalAccountError) throws -> URL {
        guard let url = components.url else {
            throw error
        }
        return url
    }

    private static let portalPathSuffixes = [
        "/api/v1/usage/dashboard/models",
        "/api/v1/usage/dashboard/stats",
        "/api/v1/auth/refresh",
        "/api/v1/auth/me",
        "/v1/models",
        "/api/v1",
        "/models",
        "/v1",
    ]
}

enum PortalPayloadDecoder {
    static func string(in dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            guard let value = dictionary[key] else {
                continue
            }

            if let stringValue = value as? String {
                let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty == false {
                    return trimmed
                }
            } else if let numberValue = value as? NSNumber {
                return numberValue.stringValue
            }
        }

        return nil
    }

    static func int(in dictionary: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            guard let value = dictionary[key] else {
                continue
            }

            if let intValue = value as? Int {
                return intValue
            }
            if let numberValue = value as? NSNumber {
                return numberValue.intValue
            }
            if let stringValue = value as? String,
               let intValue = Int(stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return intValue
            }
        }

        return nil
    }

    static func double(in dictionary: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            guard let value = dictionary[key] else {
                continue
            }

            if let doubleValue = value as? Double {
                return doubleValue
            }
            if let intValue = value as? Int {
                return Double(intValue)
            }
            if let numberValue = value as? NSNumber {
                return numberValue.doubleValue
            }
            if let stringValue = value as? String,
               let doubleValue = Double(stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return doubleValue
            }
        }

        return nil
    }

    static func date(in dictionary: [String: Any], keys: [String]) -> Date? {
        for key in keys {
            guard let value = dictionary[key] else {
                continue
            }

            if let dateValue = value as? Date {
                return dateValue
            }
            if let numberValue = value as? NSNumber {
                return date(fromUnixTime: numberValue.doubleValue)
            }
            if let intValue = value as? Int {
                return date(fromUnixTime: Double(intValue))
            }
            if let doubleValue = value as? Double {
                return date(fromUnixTime: doubleValue)
            }
            if let stringValue = value as? String {
                let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if let unixValue = Double(trimmed) {
                    return date(fromUnixTime: unixValue)
                }

                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let parsed = formatter.date(from: trimmed) {
                    return parsed
                }

                let fallbackFormatter = ISO8601DateFormatter()
                fallbackFormatter.formatOptions = [.withInternetDateTime]
                if let parsed = fallbackFormatter.date(from: trimmed) {
                    return parsed
                }
            }
        }

        return nil
    }

    private static func date(fromUnixTime value: Double) -> Date {
        if value > 1_000_000_000_000 {
            return Date(timeIntervalSince1970: value / 1000)
        }
        return Date(timeIntervalSince1970: value)
    }
}

private struct PortalDynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

private extension KeyedDecodingContainer where Key == PortalDynamicCodingKey {
    func decodeString(for keys: [String]) -> String? {
        for key in keys {
            let codingKey = PortalDynamicCodingKey(key)
            if let value = try? decode(String.self, forKey: codingKey) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty == false {
                    return trimmed
                }
            }
            if let value = try? decode(Int.self, forKey: codingKey) {
                return String(value)
            }
            if let value = try? decode(Double.self, forKey: codingKey) {
                return String(value)
            }
        }

        return nil
    }

    func decodeInt(for keys: [String]) -> Int? {
        for key in keys {
            let codingKey = PortalDynamicCodingKey(key)
            if let value = try? decode(Int.self, forKey: codingKey) {
                return value
            }
            if let value = try? decode(String.self, forKey: codingKey),
               let parsed = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return parsed
            }
        }

        return nil
    }

    func decodeDouble(for keys: [String]) -> Double? {
        for key in keys {
            let codingKey = PortalDynamicCodingKey(key)
            if let value = try? decode(Double.self, forKey: codingKey) {
                return value
            }
            if let value = try? decode(Int.self, forKey: codingKey) {
                return Double(value)
            }
            if let value = try? decode(String.self, forKey: codingKey),
               let parsed = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return parsed
            }
        }

        return nil
    }
}
