@testable import CodexConfigSwitcherCore
import Foundation
import Testing

struct PlatformDefaultsTests {
    @Test
    func windowsDefaultPathsUseUserProfile() {
        let environment = [
            "USERPROFILE": #"C:\Users\bridge"#,
        ]

        let paths = PlatformDefaults.defaultPaths(for: .windows, environment: environment)

        #expect(paths.configPath == #"C:\Users\bridge\.codex\config.toml"#)
        #expect(paths.authPath == #"C:\Users\bridge\.codex\auth.json"#)
    }

    @Test
    func windowsApplicationSupportUsesRoamingAppData() {
        let environment = [
            "USERPROFILE": #"C:\Users\bridge"#,
            "APPDATA": #"C:\Users\bridge\AppData\Roaming"#,
        ]

        let path = PlatformDefaults.defaultApplicationSupportPath(for: .windows, environment: environment)

        #expect(path == #"C:\Users\bridge\AppData\Roaming\CodexConfigSwitcher"#)
    }

    @Test
    func windowsCodexTargetUsesLocalProgramsFolder() {
        let environment = [
            "USERPROFILE": #"C:\Users\bridge"#,
            "LOCALAPPDATA": #"C:\Users\bridge\AppData\Local"#,
        ]

        let target = PlatformDefaults.defaultTargetApp(for: .windows, environment: environment)

        #expect(target.displayName == "Codex")
        #expect(target.bundleIdentifier.isEmpty)
        #expect(target.appPath == #"C:\Users\bridge\AppData\Local\Programs\Codex\Codex.exe"#)
    }
}
