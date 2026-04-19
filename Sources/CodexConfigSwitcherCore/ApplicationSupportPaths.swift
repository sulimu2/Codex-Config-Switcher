import Foundation

public enum ApplicationSupportPaths {
    public static let folderName = "CodexConfigSwitcher"

    public static func rootDirectory(fileManager: FileManager = .default) throws -> URL {
        let rootDirectory = URL(
            fileURLWithPath: PlatformDefaults.defaultApplicationSupportPath(fileManager: fileManager),
            isDirectory: true
        )
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        return rootDirectory
    }

    public static func presetsFileURL(fileManager: FileManager = .default) throws -> URL {
        try rootDirectory(fileManager: fileManager).appendingPathComponent("presets.json")
    }

    public static func settingsFileURL(fileManager: FileManager = .default) throws -> URL {
        try rootDirectory(fileManager: fileManager).appendingPathComponent("settings.json")
    }

    public static func templatesFileURL(fileManager: FileManager = .default) throws -> URL {
        try rootDirectory(fileManager: fileManager).appendingPathComponent("templates.json")
    }

    public static func presetAccountSessionsFileURL(fileManager: FileManager = .default) throws -> URL {
        try rootDirectory(fileManager: fileManager).appendingPathComponent("preset-account-sessions.json")
    }

    public static func backupsDirectory(fileManager: FileManager = .default) throws -> URL {
        let directory = try rootDirectory(fileManager: fileManager).appendingPathComponent("Backups", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
