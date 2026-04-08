import AppKit
import CodexConfigSwitcherCore
import Foundation

enum TargetAppAvailability {
    case running(URL)
    case installed(URL)
    case missing
}

@MainActor
struct TargetAppService {
    private let workspace: NSWorkspace
    private let fileManager: FileManager

    init(workspace: NSWorkspace = .shared, fileManager: FileManager = .default) {
        self.workspace = workspace
        self.fileManager = fileManager
    }

    func availability(for target: ManagedAppTarget) -> TargetAppAvailability {
        guard let appURL = resolvedURL(for: target) else {
            return .missing
        }

        if !runningApplications(for: target, resolvedURL: appURL).isEmpty {
            return .running(appURL)
        }

        return .installed(appURL)
    }

    func restart(_ target: ManagedAppTarget) async throws {
        guard let appURL = resolvedURL(for: target) else {
            throw ConfigSwitchError.fileMissing("未找到 \(target.displayName) 应用，无法自动重启。")
        }

        let applications = runningApplications(for: target, resolvedURL: appURL)
        for application in applications {
            _ = application.terminate()
        }

        if !applications.isEmpty {
            let deadline = Date().addingTimeInterval(4)
            while Date() < deadline && applications.contains(where: { !$0.isTerminated }) {
                try await Task.sleep(nanoseconds: 200_000_000)
            }

            for application in applications where !application.isTerminated {
                _ = application.forceTerminate()
            }

            try await Task.sleep(nanoseconds: 400_000_000)
        }

        try await openApplication(at: appURL)
    }

    private func resolvedURL(for target: ManagedAppTarget) -> URL? {
        if !target.bundleIdentifier.isEmpty,
           let bundledURL = workspace.urlForApplication(withBundleIdentifier: target.bundleIdentifier) {
            return bundledURL
        }

        let expandedPath = (target.appPath as NSString).expandingTildeInPath
        if !expandedPath.isEmpty, fileManager.fileExists(atPath: expandedPath) {
            return URL(fileURLWithPath: expandedPath)
        }

        return nil
    }

    private func runningApplications(for target: ManagedAppTarget, resolvedURL: URL) -> [NSRunningApplication] {
        if !target.bundleIdentifier.isEmpty {
            let applications = NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleIdentifier)
            if !applications.isEmpty {
                return applications
            }
        }

        return workspace.runningApplications.filter { application in
            application.bundleURL?.standardizedFileURL.path == resolvedURL.standardizedFileURL.path
        }
    }

    private func openApplication(at url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true

            workspace.openApplication(at: url, configuration: configuration) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
