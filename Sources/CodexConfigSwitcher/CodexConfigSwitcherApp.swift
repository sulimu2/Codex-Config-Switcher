import SwiftUI

@main
struct CodexConfigSwitcherApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup(id: "main") {
            MainWindowView()
                .environmentObject(model)
                .frame(minWidth: 980, minHeight: 680)
        }

        MenuBarExtra("Codex Config Switcher", systemImage: "switch.2") {
            MenuBarContentView()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window)
    }
}
