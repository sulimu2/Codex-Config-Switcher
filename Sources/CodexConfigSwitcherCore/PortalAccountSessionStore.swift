import Foundation

public actor PortalAccountSessionStore {
    public typealias Refresher = @Sendable (PortalAccountSession) async throws -> PortalAccountSession

    private var session: PortalAccountSession?
    private var refreshTask: Task<PortalAccountSession, Error>?
    private let now: @Sendable () -> Date

    public init(
        session: PortalAccountSession? = nil,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.session = session
        self.now = now
    }

    public func snapshot() -> PortalAccountSession? {
        session
    }

    public func save(_ session: PortalAccountSession?) {
        self.session = session
    }

    public func clear() {
        refreshTask?.cancel()
        refreshTask = nil
        session = nil
    }

    public func authorizedSession(refreshingWith refresher: @escaping Refresher) async throws -> PortalAccountSession {
        guard let session else {
            throw PortalAccountError.missingSession
        }

        guard session.normalizedAccessToken.isEmpty == false else {
            throw PortalAccountError.missingAccessToken
        }

        if session.needsRefresh(referenceDate: now()) {
            return try await refreshSession(from: session, refresher: refresher)
        }

        return session
    }

    public func retrySession(
        afterUnauthorizedAccessToken accessToken: String,
        refreshingWith refresher: @escaping Refresher
    ) async throws -> PortalAccountSession {
        guard let currentSession = session else {
            throw PortalAccountError.missingSession
        }

        let normalizedAccessToken = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedAccessToken.isEmpty {
            throw PortalAccountError.missingAccessToken
        }

        if currentSession.normalizedAccessToken != normalizedAccessToken,
           currentSession.needsRefresh(referenceDate: now()) == false {
            return currentSession
        }

        return try await refreshSession(from: currentSession, refresher: refresher)
    }

    private func refreshSession(
        from session: PortalAccountSession,
        refresher: @escaping Refresher
    ) async throws -> PortalAccountSession {
        guard session.canRefresh else {
            throw PortalAccountError.refreshUnavailable
        }

        if let refreshTask {
            return try await refreshTask.value
        }

        let task = Task {
            try await refresher(session)
        }
        refreshTask = task

        do {
            let refreshedSession = try await task.value
            self.session = refreshedSession
            refreshTask = nil
            return refreshedSession
        } catch {
            refreshTask = nil
            throw error
        }
    }
}

public struct PresetAccountSessionRepository {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default, fileURL: URL? = nil) throws {
        self.fileManager = fileManager
        self.fileURL = try fileURL ?? ApplicationSupportPaths.presetAccountSessionsFileURL(fileManager: fileManager)
    }

    public func loadRecords() throws -> [PresetAccountSessionRecord] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([PresetAccountSessionRecord].self, from: data)
    }

    public func saveRecords(_ records: [PresetAccountSessionRecord]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(records)
        try data.write(to: fileURL, options: .atomic)
    }
}
