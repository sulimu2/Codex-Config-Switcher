import Foundation

public enum ApplicationSupportPaths {
    public static let folderName = "CodexConfigSwitcher"

    public static func rootDirectory(fileManager: FileManager = .default) throws -> URL {
        guard let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw ConfigSwitchError.cannotCreateAppSupport("无法定位 Application Support 目录。")
        }

        let rootDirectory = baseDirectory.appendingPathComponent(folderName, isDirectory: true)
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        return rootDirectory
    }

    public static func presetsFileURL(fileManager: FileManager = .default) throws -> URL {
        try rootDirectory(fileManager: fileManager).appendingPathComponent("presets.json")
    }

    public static func settingsFileURL(fileManager: FileManager = .default) throws -> URL {
        try rootDirectory(fileManager: fileManager).appendingPathComponent("settings.json")
    }

    public static func backupsDirectory(fileManager: FileManager = .default) throws -> URL {
        let directory = try rootDirectory(fileManager: fileManager).appendingPathComponent("Backups", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
