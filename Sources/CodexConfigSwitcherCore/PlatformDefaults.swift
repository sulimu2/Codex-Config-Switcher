import Foundation

enum HostPlatform {
    case macOS
    case windows
    case linux
    case unknown

    static var current: HostPlatform {
#if os(macOS)
        .macOS
#elseif os(Windows)
        .windows
#elseif os(Linux)
        .linux
#else
        .unknown
#endif
    }

    var pathSeparator: Character {
        switch self {
        case .windows:
            "\\"
        case .macOS, .linux, .unknown:
            "/"
        }
    }
}

enum PlatformDefaults {
    static func defaultPaths(
        for platform: HostPlatform = .current,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> AppPaths {
        let codexDirectory = defaultCodexDirectoryPath(
            for: platform,
            environment: environment,
            fileManager: fileManager
        )
        let separator = platform.pathSeparator

        return AppPaths(
            configPath: joinPath(codexDirectory, "config.toml", separator: separator),
            authPath: joinPath(codexDirectory, "auth.json", separator: separator)
        )
    }

    static func defaultApplicationSupportPath(
        for platform: HostPlatform = .current,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> String {
        switch platform {
        case .windows:
            let homePath = resolvedHomePath(for: .windows, environment: environment, fileManager: fileManager)
            let roamingAppData = firstNonEmpty(
                environment["APPDATA"],
                joinPath(joinPath(homePath, "AppData", separator: "\\"), "Roaming", separator: "\\")
            )

            return joinPath(roamingAppData, ApplicationSupportPaths.folderName, separator: "\\")
        case .linux:
            let homePath = resolvedHomePath(for: .linux, environment: environment, fileManager: fileManager)
            let dataHome = firstNonEmpty(
                environment["XDG_DATA_HOME"],
                joinPath(joinPath(homePath, ".local", separator: "/"), "share", separator: "/")
            )

            return joinPath(dataHome, ApplicationSupportPaths.folderName, separator: "/")
        case .macOS, .unknown:
            let homePath = resolvedHomePath(for: .macOS, environment: environment, fileManager: fileManager)
            let applicationSupport = joinPath(
                joinPath(homePath, "Library", separator: "/"),
                "Application Support",
                separator: "/"
            )

            return joinPath(applicationSupport, ApplicationSupportPaths.folderName, separator: "/")
        }
    }

    static func defaultTargetApp(
        for platform: HostPlatform = .current,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> ManagedAppTarget {
        switch platform {
        case .windows:
            let homePath = resolvedHomePath(for: .windows, environment: environment, fileManager: fileManager)
            let localAppData = firstNonEmpty(
                environment["LOCALAPPDATA"],
                joinPath(joinPath(homePath, "AppData", separator: "\\"), "Local", separator: "\\")
            )
            let programsDirectory = joinPath(localAppData, "Programs", separator: "\\")
            let codexDirectory = joinPath(programsDirectory, "Codex", separator: "\\")

            return ManagedAppTarget(
                displayName: "Codex",
                bundleIdentifier: "",
                appPath: joinPath(codexDirectory, "Codex.exe", separator: "\\")
            )
        case .linux:
            return ManagedAppTarget(
                displayName: "Codex",
                bundleIdentifier: "",
                appPath: "codex"
            )
        case .macOS, .unknown:
            return ManagedAppTarget(
                displayName: "Codex",
                bundleIdentifier: "com.openai.codex",
                appPath: "/Applications/Codex.app"
            )
        }
    }

    private static func defaultCodexDirectoryPath(
        for platform: HostPlatform,
        environment: [String: String],
        fileManager: FileManager
    ) -> String {
        let separator = platform.pathSeparator
        let homePath = resolvedHomePath(for: platform, environment: environment, fileManager: fileManager)
        return joinPath(homePath, ".codex", separator: separator)
    }

    private static func resolvedHomePath(
        for platform: HostPlatform,
        environment: [String: String],
        fileManager: FileManager
    ) -> String {
        switch platform {
        case .windows:
            if let userProfile = nonEmpty(environment["USERPROFILE"]) {
                return userProfile
            }

            if let homeDrive = nonEmpty(environment["HOMEDRIVE"]),
               let homePath = nonEmpty(environment["HOMEPATH"]) {
                return "\(homeDrive)\(homePath)"
            }

            return fileManager.homeDirectoryForCurrentUser.path
        case .macOS, .linux, .unknown:
            return nonEmpty(environment["HOME"]) ?? fileManager.homeDirectoryForCurrentUser.path
        }
    }

    private static func joinPath(_ base: String, _ component: String, separator: Character) -> String {
        guard !base.isEmpty else {
            return component
        }

        let normalizedBase = trimmingTrailingSeparators(in: base, separator: separator)
        let normalizedComponent = component.trimmingCharacters(in: CharacterSet(charactersIn: String(separator)))

        guard !normalizedBase.isEmpty else {
            return normalizedComponent
        }

        guard !normalizedComponent.isEmpty else {
            return normalizedBase
        }

        if normalizedBase == String(separator) {
            return "\(normalizedBase)\(normalizedComponent)"
        }

        return "\(normalizedBase)\(separator)\(normalizedComponent)"
    }

    private static func firstNonEmpty(_ values: String?...) -> String {
        values.compactMap(nonEmpty).first ?? ""
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }

    private static func trimmingTrailingSeparators(in value: String, separator: Character) -> String {
        var result = value
        while result.count > 1 && result.last == separator {
            result.removeLast()
        }
        return result
    }
}
