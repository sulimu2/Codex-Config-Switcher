import AppKit
import CodexConfigSwitcherCore
import Foundation
import UniformTypeIdentifiers

@MainActor
struct SystemPickerService {
    func pickFile(allowedExtensions: [String], startingAt path: String?) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = allowedExtensions.compactMap { UTType(filenameExtension: $0) }

        if let path, !path.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                .deletingLastPathComponent()
        }

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url?.path
    }

    func pickApplication(startingAt path: String?) -> ManagedAppTarget? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]

        if let path, !path.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                .deletingLastPathComponent()
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        let bundle = Bundle(url: url)
        return ManagedAppTarget(
            displayName: url.deletingPathExtension().lastPathComponent,
            bundleIdentifier: bundle?.bundleIdentifier ?? "",
            appPath: url.path
        )
    }

    func pickSaveFile(defaultFileName: String, allowedExtension: String, startingAt path: String? = nil) -> String? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: allowedExtension)].compactMap { $0 }
        panel.nameFieldStringValue = defaultFileName

        if let path, !path.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                .deletingLastPathComponent()
        }

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url?.path
    }
}
