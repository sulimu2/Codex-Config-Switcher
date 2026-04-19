import Foundation

public struct PresetStore {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default, fileURL: URL? = nil) throws {
        self.fileManager = fileManager
        self.fileURL = try fileURL ?? ApplicationSupportPaths.presetsFileURL(fileManager: fileManager)
    }

    public func loadPresets() throws -> [CodexPreset] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([CodexPreset].self, from: data)
    }

    public func savePresets(_ presets: [CodexPreset]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(presets)
        try data.write(to: fileURL, options: .atomic)
    }
}

public struct SettingsStore {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default, fileURL: URL? = nil) throws {
        self.fileManager = fileManager
        self.fileURL = try fileURL ?? ApplicationSupportPaths.settingsFileURL(fileManager: fileManager)
    }

    public func loadSettings(defaultPaths: AppPaths = .default) throws -> AppSettings {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return AppSettings(
                paths: defaultPaths,
                hasCompletedOnboarding: false,
                onboardingVersion: 1
            )
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(AppSettings.self, from: data)
    }

    public func saveSettings(_ settings: AppSettings) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: fileURL, options: .atomic)
    }
}
