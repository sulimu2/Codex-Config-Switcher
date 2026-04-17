import Foundation

public struct TemplateStore {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default, fileURL: URL? = nil) throws {
        self.fileManager = fileManager
        self.fileURL = try fileURL ?? ApplicationSupportPaths.templatesFileURL(fileManager: fileManager)
    }

    public func loadTemplates() throws -> [CodexTemplate] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([CodexTemplate].self, from: data)
    }

    public func saveTemplates(_ templates: [CodexTemplate]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(templates)
        try data.write(to: fileURL, options: .atomic)
    }
}
