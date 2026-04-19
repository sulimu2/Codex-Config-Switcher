import Foundation

public struct PortalAccountService: Sendable {
    public typealias RequestHandler = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    public static let defaultRefreshPath = "/api/v1/auth/refresh"

    private let refreshPath: String
    private let now: @Sendable () -> Date
    private let sendRequest: RequestHandler

    public init(refreshPath: String = Self.defaultRefreshPath) {
        self.refreshPath = refreshPath
        self.now = Date.init
        self.sendRequest = Self.defaultRequestHandler
    }

    public init(
        refreshPath: String = Self.defaultRefreshPath,
        now: @escaping @Sendable () -> Date = Date.init,
        sendRequest: @escaping RequestHandler
    ) {
        self.refreshPath = refreshPath
        self.now = now
        self.sendRequest = sendRequest
    }

    public func fetchAccountSnapshot(
        portalURL: String,
        accessToken: String
    ) async throws -> PortalAccountSnapshot {
        let normalizedPortalURL = try PortalURLHelper.normalizedPortalURL(from: portalURL)
        return try await fetchAccountSnapshot(portalURL: normalizedPortalURL, accessToken: accessToken)
    }

    public func fetchAccountSnapshot(
        using sessionStore: PortalAccountSessionStore
    ) async throws -> PortalAccountSnapshot {
        let profile = try await fetchAccountProfile(using: sessionStore)
        let stats = try await fetchDashboardStats(using: sessionStore)
        let usageModels = try await fetchDashboardModels(using: sessionStore)
        return PortalAccountSnapshot(profile: profile, stats: stats, usageModels: usageModels)
    }

    public func refreshOverview(
        for preset: CodexPreset,
        record: PresetAccountSessionRecord,
        range: PortalAccountOverviewRange = PortalAccountOverviewRange()
    ) async throws -> PortalOverviewRefreshResult {
        guard let session = record.portalSession else {
            throw PortalAccountError.invalidPortalURL
        }

        let sessionStore = PortalAccountSessionStore(session: session, now: now)
        let snapshot = try await fetchAccountSnapshot(using: sessionStore)
        let availableModels = (try? await fetchAvailableModels(for: preset).map(\.id)) ?? record.cachedOverview?.availableModels ?? []
        let refreshedAt = now()
        let overview = PortalAccountOverview(
            snapshot: snapshot,
            availableModels: availableModels,
            range: range,
            refreshedAt: refreshedAt
        )

        guard let latestSession = await sessionStore.snapshot() else {
            throw PortalAccountError.missingSession
        }
        let updatedRecord = PresetAccountSessionRecord(
            id: record.id,
            presetID: record.presetID,
            session: latestSession,
            cachedUser: overview.user,
            cachedOverview: overview,
            updatedAt: refreshedAt
        )

        return PortalOverviewRefreshResult(overview: overview, session: updatedRecord)
    }

    public func fetchAccountProfile(
        portalURL: String,
        accessToken: String
    ) async throws -> PortalAccountProfile {
        let normalizedPortalURL = try PortalURLHelper.normalizedPortalURL(from: portalURL)
        return try await fetchAccountProfile(portalURL: normalizedPortalURL, accessToken: accessToken)
    }

    public func fetchAccountProfile(
        using sessionStore: PortalAccountSessionStore
    ) async throws -> PortalAccountProfile {
        try await performSessionBackedRequest(
            using: sessionStore,
            path: "/api/v1/auth/me"
        ) { rootObject in
            let payload = try dictionaryPayload(
                from: rootObject,
                preferredKeys: ["data", "user", "me"]
            )
            return PortalAccountProfile(payload: payload)
        }
    }

    public func fetchDashboardStats(
        portalURL: String,
        accessToken: String
    ) async throws -> PortalAccountUsageStats {
        let normalizedPortalURL = try PortalURLHelper.normalizedPortalURL(from: portalURL)
        return try await fetchDashboardStats(portalURL: normalizedPortalURL, accessToken: accessToken)
    }

    public func fetchDashboardStats(
        using sessionStore: PortalAccountSessionStore
    ) async throws -> PortalAccountUsageStats {
        try await performSessionBackedRequest(
            using: sessionStore,
            path: "/api/v1/usage/dashboard/stats"
        ) { rootObject in
            let payload = try dictionaryPayload(
                from: rootObject,
                preferredKeys: ["data", "stats", "summary", "totals"]
            )
            return PortalAccountUsageStats(payload: payload)
        }
    }

    public func fetchDashboardModels(
        portalURL: String,
        accessToken: String
    ) async throws -> [PortalAccountUsageModel] {
        let normalizedPortalURL = try PortalURLHelper.normalizedPortalURL(from: portalURL)
        return try await fetchDashboardModels(portalURL: normalizedPortalURL, accessToken: accessToken)
    }

    public func fetchDashboardModels(
        using sessionStore: PortalAccountSessionStore
    ) async throws -> [PortalAccountUsageModel] {
        try await performSessionBackedRequest(
            using: sessionStore,
            path: "/api/v1/usage/dashboard/models"
        ) { rootObject in
            let payload = try arrayPayload(
                from: rootObject,
                preferredKeys: ["data", "models", "list", "items"]
            )
            return payload.compactMap(PortalAccountUsageModel.init(payload:))
        }
    }

    public func fetchAvailableModels(for preset: CodexPreset) async throws -> [PortalAvailableModel] {
        let modelsEndpoint = try PortalURLHelper.modelsEndpoint(from: preset)
        let apiKey = preset.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard apiKey.isEmpty == false else {
            throw PortalAccountError.missingAccessToken
        }

        let rootObject = try await performJSONRequest(
            endpoint: modelsEndpoint,
            bearerToken: apiKey
        )
        let payload = try arrayPayload(
            from: rootObject,
            preferredKeys: ["data", "models", "list", "items"]
        )
        return payload.compactMap(PortalAvailableModel.init(payload:))
    }

    public func refreshSession(_ session: PortalAccountSession) async throws -> PortalAccountSession {
        guard let refreshToken = session.normalizedRefreshToken else {
            throw PortalAccountError.refreshUnavailable
        }

        var request = try makePortalRequest(
            portalURL: session.portalURL,
            path: refreshPath,
            bearerToken: refreshToken
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: [
                "refreshToken": refreshToken,
                "refresh_token": refreshToken,
            ],
            options: []
        )

        let data = try await perform(request)
        let rootObject = try jsonObject(from: data)
        let payload = try dictionaryPayload(
            from: rootObject,
            preferredKeys: ["data", "session", "token", "tokens"]
        )

        guard let refreshedSession = PortalAccountSession(
            refreshPayload: payload,
            portalURL: session.portalURL,
            fallbackRefreshToken: session.refreshToken,
            fallbackTokenType: session.tokenType,
            referenceDate: now()
        ) else {
            throw PortalAccountError.invalidResponse("刷新接口没有返回可用的 access token。")
        }

        return refreshedSession
    }

    private func fetchAccountSnapshot(
        portalURL: URL,
        accessToken: String
    ) async throws -> PortalAccountSnapshot {
        let profile = try await fetchAccountProfile(portalURL: portalURL, accessToken: accessToken)
        let stats = try await fetchDashboardStats(portalURL: portalURL, accessToken: accessToken)
        let usageModels = try await fetchDashboardModels(portalURL: portalURL, accessToken: accessToken)
        return PortalAccountSnapshot(profile: profile, stats: stats, usageModels: usageModels)
    }

    private func fetchAccountProfile(
        portalURL: URL,
        accessToken: String
    ) async throws -> PortalAccountProfile {
        let rootObject = try await performPortalJSONRequest(
            portalURL: portalURL,
            path: "/api/v1/auth/me",
            accessToken: accessToken
        )
        let payload = try dictionaryPayload(from: rootObject, preferredKeys: ["data", "user", "me"])
        return PortalAccountProfile(payload: payload)
    }

    private func fetchDashboardStats(
        portalURL: URL,
        accessToken: String
    ) async throws -> PortalAccountUsageStats {
        let rootObject = try await performPortalJSONRequest(
            portalURL: portalURL,
            path: "/api/v1/usage/dashboard/stats",
            accessToken: accessToken
        )
        let payload = try dictionaryPayload(
            from: rootObject,
            preferredKeys: ["data", "stats", "summary", "totals"]
        )
        return PortalAccountUsageStats(payload: payload)
    }

    private func fetchDashboardModels(
        portalURL: URL,
        accessToken: String
    ) async throws -> [PortalAccountUsageModel] {
        let rootObject = try await performPortalJSONRequest(
            portalURL: portalURL,
            path: "/api/v1/usage/dashboard/models",
            accessToken: accessToken
        )
        let payload = try arrayPayload(
            from: rootObject,
            preferredKeys: ["data", "models", "list", "items"]
        )
        return payload.compactMap(PortalAccountUsageModel.init(payload:))
    }

    private func performSessionBackedRequest<T>(
        using sessionStore: PortalAccountSessionStore,
        path: String,
        transform: (Any) throws -> T
    ) async throws -> T {
        let session = try await sessionStore.authorizedSession(refreshingWith: refreshSession)

        do {
            let rootObject = try await performPortalJSONRequest(
                portalURL: session.portalURL,
                path: path,
                accessToken: session.normalizedAccessToken
            )
            return try transform(rootObject)
        } catch let error as PortalAccountError {
            guard case .unauthorized = error else {
                throw error
            }

            let refreshedSession = try await sessionStore.retrySession(
                afterUnauthorizedAccessToken: session.normalizedAccessToken,
                refreshingWith: refreshSession
            )
            let rootObject = try await performPortalJSONRequest(
                portalURL: refreshedSession.portalURL,
                path: path,
                accessToken: refreshedSession.normalizedAccessToken
            )
            return try transform(rootObject)
        }
    }

    private func performPortalJSONRequest(
        portalURL: URL,
        path: String,
        accessToken: String
    ) async throws -> Any {
        guard accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw PortalAccountError.missingAccessToken
        }

        let endpoint = try PortalURLHelper.endpointURL(portalURL: portalURL, path: path)
        return try await performJSONRequest(endpoint: endpoint, bearerToken: accessToken)
    }

    private func performJSONRequest(
        endpoint: URL,
        bearerToken: String
    ) async throws -> Any {
        let request = try makeRequest(endpoint: endpoint, bearerToken: bearerToken)
        let data = try await perform(request)
        return try jsonObject(from: data)
    }

    private func makePortalRequest(
        portalURL: URL,
        path: String,
        bearerToken: String
    ) throws -> URLRequest {
        let endpoint = try PortalURLHelper.endpointURL(portalURL: portalURL, path: path)
        return try makeRequest(endpoint: endpoint, bearerToken: bearerToken)
    }

    private func makeRequest(endpoint: URL, bearerToken: String) throws -> URLRequest {
        let trimmedToken = bearerToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedToken.isEmpty == false else {
            throw PortalAccountError.missingAccessToken
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await sendRequest(request)

        if (200 ... 299).contains(response.statusCode) {
            return data
        }

        if response.statusCode == 401 || response.statusCode == 403 {
            throw PortalAccountError.unauthorized(statusCode: response.statusCode)
        }

        throw PortalAccountError.requestFailed(
            statusCode: response.statusCode,
            message: responseMessage(from: data)
        )
    }

    private func responseMessage(from data: Data) -> String? {
        guard
            data.isEmpty == false,
            let object = try? JSONSerialization.jsonObject(with: data)
        else {
            return nil
        }

        if let dictionary = object as? [String: Any] {
            if let message = PortalPayloadDecoder.string(in: dictionary, keys: ["message", "detail"]) {
                return message
            }
            if let errorDictionary = dictionary["error"] as? [String: Any] {
                return PortalPayloadDecoder.string(in: errorDictionary, keys: ["message", "detail", "type"])
            }
            if let errorString = dictionary["error"] as? String {
                let trimmed = errorString.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        }

        return nil
    }

    private func jsonObject(from data: Data) throws -> Any {
        do {
            return try JSONSerialization.jsonObject(with: data)
        } catch {
            throw PortalAccountError.invalidResponse("门户接口返回了无法解析的 JSON。")
        }
    }

    private static func defaultRequestHandler(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PortalAccountError.invalidResponse("门户接口没有返回 HTTP 响应。")
        }
        return (data, httpResponse)
    }
}

private func dictionaryPayload(
    from rootObject: Any,
    preferredKeys: [String]
) throws -> [String: Any] {
    if let payload = dictionaryPayloadIfPresent(from: rootObject, preferredKeys: preferredKeys) {
        return payload
    }

    throw PortalAccountError.invalidResponse("门户接口返回的 JSON 结构不是预期对象。")
}

private func arrayPayload(
    from rootObject: Any,
    preferredKeys: [String]
) throws -> [[String: Any]] {
    if let payload = arrayPayloadIfPresent(from: rootObject, preferredKeys: preferredKeys) {
        return payload
    }

    throw PortalAccountError.invalidResponse("门户接口返回的 JSON 结构不是预期数组。")
}

private func dictionaryPayloadIfPresent(
    from rootObject: Any,
    preferredKeys: [String]
) -> [String: Any]? {
    if let dictionary = rootObject as? [String: Any] {
        for key in preferredKeys {
            if let nestedDictionary = dictionary[key] as? [String: Any] {
                return nestedDictionary
            }
        }

        if let dataDictionary = dictionary["data"] as? [String: Any] {
            return dataDictionary
        }

        return dictionary
    }

    return nil
}

private func arrayPayloadIfPresent(
    from rootObject: Any,
    preferredKeys: [String]
) -> [[String: Any]]? {
    if let array = rootObject as? [[String: Any]] {
        return array
    }

    guard let dictionary = rootObject as? [String: Any] else {
        return nil
    }

    for key in preferredKeys {
        if let array = dictionary[key] as? [[String: Any]] {
            return array
        }
        if let nested = dictionary[key],
           let array = arrayPayloadIfPresent(from: nested, preferredKeys: preferredKeys) {
            return array
        }
    }

    if let array = dictionary["data"] as? [[String: Any]] {
        return array
    }

    if let nested = dictionary["data"] {
        return arrayPayloadIfPresent(from: nested, preferredKeys: preferredKeys)
    }

    return nil
}
