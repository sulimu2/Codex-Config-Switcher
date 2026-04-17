@testable import CodexConfigSwitcherCore
import Foundation
import Testing

struct ManagedAppRuntimeServiceTests {
    @Test
    func availabilityReturnsMissingWhenTargetPathDoesNotExist() {
        let runner = RecordingManagedAppCommandRunner()
        let service = ManagedAppRuntimeService(
            platform: .windows,
            fileManager: .default,
            environment: ["SystemRoot": #"C:\Windows"#],
            runner: runner
        )

        let availability = service.availability(
            for: ManagedAppTarget(
                displayName: "Codex",
                bundleIdentifier: "",
                appPath: "/tmp/does-not-exist/Codex.exe"
            )
        )

        #expect(availability == .missing)
        #expect(runner.commands.isEmpty)
    }

    @Test
    func windowsAvailabilityReturnsRunningWhenProcessIsFound() throws {
        let executableURL = try makeTemporaryExecutable(named: "Codex.exe")
        let runner = RecordingManagedAppCommandRunner(
            queuedResults: [
                ManagedAppCommandResult(exitStatus: 0, standardOutput: "", standardError: ""),
            ]
        )
        let service = ManagedAppRuntimeService(
            platform: .windows,
            fileManager: .default,
            environment: ["SystemRoot": #"C:\Windows"#],
            runner: runner
        )

        let availability = service.availability(
            for: ManagedAppTarget(
                displayName: "Codex",
                bundleIdentifier: "",
                appPath: executableURL.path
            )
        )

        #expect(availability == .running)
        #expect(runner.commands.count == 1)
        #expect(runner.commands[0].executablePath.contains("powershell.exe"))
        #expect(runner.commands[0].arguments.joined(separator: " ").contains("Get-Process"))
    }

    @Test
    func windowsRestartStopsThenStartsTarget() throws {
        let executableURL = try makeTemporaryExecutable(named: "Codex.exe")
        let runner = RecordingManagedAppCommandRunner(
            queuedResults: [
                ManagedAppCommandResult(exitStatus: 0, standardOutput: "", standardError: ""),
                ManagedAppCommandResult(exitStatus: 0, standardOutput: "", standardError: ""),
                ManagedAppCommandResult(exitStatus: 0, standardOutput: "", standardError: ""),
            ]
        )
        let service = ManagedAppRuntimeService(
            platform: .windows,
            fileManager: .default,
            environment: ["SystemRoot": #"C:\Windows"#],
            runner: runner
        )
        let target = ManagedAppTarget(
            displayName: "Codex",
            bundleIdentifier: "",
            appPath: executableURL.path
        )

        try service.restart(target)

        #expect(runner.commands.count == 3)
        #expect(runner.commands[0].arguments.joined(separator: " ").contains("Get-Process"))
        #expect(runner.commands[1].arguments.joined(separator: " ").contains("Stop-Process"))
        #expect(runner.commands[2].arguments.joined(separator: " ").contains("Start-Process"))
    }
}

private final class RecordingManagedAppCommandRunner: ManagedAppCommandRunning {
    private var queuedResults: [ManagedAppCommandResult]
    private(set) var commands: [ManagedAppCommand] = []

    init(queuedResults: [ManagedAppCommandResult] = []) {
        self.queuedResults = queuedResults
    }

    func run(_ command: ManagedAppCommand) throws -> ManagedAppCommandResult {
        commands.append(command)
        if queuedResults.isEmpty {
            return ManagedAppCommandResult(exitStatus: 0, standardOutput: "", standardError: "")
        }

        return queuedResults.removeFirst()
    }
}

private func makeTemporaryExecutable(named name: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let executableURL = directory.appendingPathComponent(name)
    FileManager.default.createFile(atPath: executableURL.path, contents: Data("echo".utf8))
    return executableURL
}
