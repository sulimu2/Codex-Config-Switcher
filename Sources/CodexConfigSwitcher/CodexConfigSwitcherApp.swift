import AppKit
import SwiftUI

@main
struct CodexConfigSwitcherApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup(id: "main") {
            Group {
                if model.shouldShowOnboarding {
                    OnboardingRootView()
                } else {
                    MainWindowView()
                }
            }
            .environmentObject(model)
            .frame(minWidth: 980, minHeight: 680)
        }
        .commands {
            QuickActionCommands(model: model)
        }

        MenuBarExtra("Codex Config Switcher", systemImage: "switch.2") {
            Group {
                if model.shouldShowOnboarding {
                    OnboardingMenuBarContentView()
                } else {
                    MenuBarContentView()
                }
            }
            .environmentObject(model)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct QuickActionCommands: Commands {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("快捷操作") {
            Button("打开主窗口") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Divider()

            Button(model.hasUnsavedChanges ? "立即应用当前草稿" : "立即应用当前预设") {
                model.applyDraft()
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(!model.validationResult.isValid)

            Button("重新读取当前配置") {
                model.reloadLiveConfiguration()
            }
            .keyboardShortcut("r", modifiers: [.command])
        }
    }
}
