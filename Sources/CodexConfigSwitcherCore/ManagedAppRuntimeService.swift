import Foundation

public enum ManagedAppAvailability: String, Equatable, Sendable {
    case running
    case installed
    case missing

    public var title: String {
        switch self {
        case .running:
            "运行中"
        case .installed:
            "已安装，未运行"
        case .missing:
            "未找到"
        }
    }
}

public struct ManagedAppRuntimeService {
    private let platform: HostPlatform
    private let fileManager: FileManager
    private let environment: [String: String]
    private let runner: any ManagedAppCommandRunning

    public init(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.init(
            platform: .current,
            fileManager: fileManager,
            environment: environment,
            runner: SystemManagedAppCommandRunner()
        )
    }

    init(
        platform: HostPlatform,
        fileManager: FileManager,
        environment: [String: String],
        runner: any ManagedAppCommandRunning
    ) {
        self.platform = platform
        self.fileManager = fileManager
        self.environment = environment
        self.runner = runner
    }

    public func availability(for target: ManagedAppTarget) -> ManagedAppAvailability {
        guard let resolvedPath = resolvedPath(for: target) else {
            return .missing
        }

        do {
            return try isRunning(target, resolvedPath: resolvedPath) ? .running : .installed
        } catch {
            return .installed
        }
    }

    public func restart(_ target: ManagedAppTarget) throws {
        guard let resolvedPath = resolvedPath(for: target) else {
            throw ConfigSwitchError.fileMissing("未找到 \(target.displayName) 应用，无法自动重启。")
        }

        if try isRunning(target, resolvedPath: resolvedPath) {
            let terminateResult = try runner.run(terminateCommand(for: target, resolvedPath: resolvedPath))
            guard terminateResult.exitStatus == 0 else {
                throw ConfigSwitchError.ioFailure(
                    "无法结束 \(target.displayName) 进程：\(commandFailureDetail(from: terminateResult))"
                )
            }
        }

        let launchResult = try runner.run(launchCommand(for: target, resolvedPath: resolvedPath))
        guard launchResult.exitStatus == 0 else {
            throw ConfigSwitchError.ioFailure(
                "无法启动 \(target.displayName) 应用：\(commandFailureDetail(from: launchResult))"
            )
        }
    }

    private func isRunning(_ target: ManagedAppTarget, resolvedPath: String) throws -> Bool {
        let result = try runner.run(runningCheckCommand(for: target, resolvedPath: resolvedPath))
        return result.exitStatus == 0
    }

    private func resolvedPath(for target: ManagedAppTarget) -> String? {
        let expandedPath = expandPath(target.appPath)
        guard !expandedPath.isEmpty else {
            return nil
        }

        guard fileManager.fileExists(atPath: expandedPath) else {
            return nil
        }

        return expandedPath
    }

    private func runningCheckCommand(for target: ManagedAppTarget, resolvedPath: String) -> ManagedAppCommand {
        switch platform {
        case .windows:
            let processName = powerShellEscapedLiteral(processName(for: target, resolvedPath: resolvedPath))
            let script = """
            $process = Get-Process -Name '\(processName)' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($null -ne $process) { exit 0 } else { exit 1 }
            """
            return windowsPowerShellCommand(script: script)
        case .macOS, .linux, .unknown:
            return ManagedAppCommand(
                executablePath: "/usr/bin/pgrep",
                arguments: ["-f", processMatchToken(for: target, resolvedPath: resolvedPath)]
            )
        }
    }

    private func terminateCommand(for target: ManagedAppTarget, resolvedPath: String) -> ManagedAppCommand {
        switch platform {
        case .windows:
            let processName = powerShellEscapedLiteral(processName(for: target, resolvedPath: resolvedPath))
            let script = """
            $processes = Get-Process -Name '\(processName)' -ErrorAction SilentlyContinue
            if ($null -eq $processes) { exit 0 }
            $processes | Stop-Process -Force
            exit 0
            """
            return windowsPowerShellCommand(script: script)
        case .macOS, .linux, .unknown:
            return ManagedAppCommand(
                executablePath: "/usr/bin/pkill",
                arguments: ["-f", processMatchToken(for: target, resolvedPath: resolvedPath)]
            )
        }
    }

    private func launchCommand(for target: ManagedAppTarget, resolvedPath: String) -> ManagedAppCommand {
        switch platform {
        case .windows:
            let filePath = powerShellEscapedLiteral(resolvedPath)
            return windowsPowerShellCommand(
                script: "Start-Process -FilePath '\(filePath)'"
            )
        case .macOS:
            if resolvedPath.lowercased().hasSuffix(".app") {
                return ManagedAppCommand(
                    executablePath: "/usr/bin/open",
                    arguments: [resolvedPath]
                )
            }

            return ManagedAppCommand(
                executablePath: resolvedPath,
                arguments: []
            )
        case .linux, .unknown:
            return ManagedAppCommand(
                executablePath: resolvedPath,
                arguments: []
            )
        }
    }

    private func windowsPowerShellCommand(script: String) -> ManagedAppCommand {
        ManagedAppCommand(
            executablePath: powerShellExecutablePath(),
            arguments: ["-NoProfile", "-NonInteractive", "-Command", script]
        )
    }

    private func powerShellExecutablePath() -> String {
        let systemRoot = nonEmpty(environment["SystemRoot"]) ?? #"C:\Windows"#
        return joinPath(systemRoot, #"System32\WindowsPowerShell\v1.0\powershell.exe"#, separator: "\\")
    }

    private func processName(for target: ManagedAppTarget, resolvedPath: String) -> String {
        let fileName = lastPathComponent(of: resolvedPath)
        if fileName.lowercased().hasSuffix(".exe") {
            return String(fileName.dropLast(4))
        }

        if fileName.lowercased().hasSuffix(".app") {
            return String(fileName.dropLast(4))
        }

        let displayName = target.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return displayName.isEmpty ? fileName : displayName
    }

    private func processMatchToken(for target: ManagedAppTarget, resolvedPath: String) -> String {
        let displayName = target.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !displayName.isEmpty {
            return displayName
        }

        return processName(for: target, resolvedPath: resolvedPath)
    }

    private func expandPath(_ path: String) -> String {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            return ""
        }

        let unquotedPath = stripEnclosingQuotes(from: trimmedPath)
        switch platform {
        case .windows:
            return expandWindowsEnvironmentVariables(in: unquotedPath)
        case .macOS, .linux, .unknown:
            if unquotedPath == "~" {
                return homeDirectoryPath()
            }

            if unquotedPath.hasPrefix("~/") {
                return homeDirectoryPath() + String(unquotedPath.dropFirst())
            }

            return (unquotedPath as NSString).expandingTildeInPath
        }
    }

    private func expandWindowsEnvironmentVariables(in path: String) -> String {
        var expanded = ""
        var currentIndex = path.startIndex

        while currentIndex < path.endIndex {
            if path[currentIndex] == "%" {
                let nameStart = path.index(after: currentIndex)
                guard let nameEnd = path[nameStart...].firstIndex(of: "%") else {
                    expanded.append(path[currentIndex])
                    currentIndex = path.index(after: currentIndex)
                    continue
                }

                let variableName = String(path[nameStart..<nameEnd])
                if let value = nonEmpty(environment[variableName]) {
                    expanded.append(value)
                } else {
                    expanded.append(contentsOf: path[currentIndex...nameEnd])
                }

                currentIndex = path.index(after: nameEnd)
            } else {
                expanded.append(path[currentIndex])
                currentIndex = path.index(after: currentIndex)
            }
        }

        return expanded
    }

    private func homeDirectoryPath() -> String {
        switch platform {
        case .windows:
            if let userProfile = nonEmpty(environment["USERPROFILE"]) {
                return userProfile
            }

            if let homeDrive = nonEmpty(environment["HOMEDRIVE"]),
               let homePath = nonEmpty(environment["HOMEPATH"]) {
                return homeDrive + homePath
            }

            return fileManager.homeDirectoryForCurrentUser.path
        case .macOS, .linux, .unknown:
            return nonEmpty(environment["HOME"]) ?? fileManager.homeDirectoryForCurrentUser.path
        }
    }

    private func commandFailureDetail(from result: ManagedAppCommandResult) -> String {
        let stderr = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        let stdout = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stderr.isEmpty {
            return stderr
        }

        if !stdout.isEmpty {
            return stdout
        }

        return "退出码 \(result.exitStatus)"
    }

    private func stripEnclosingQuotes(from value: String) -> String {
        guard value.count >= 2,
              value.first == "\"",
              value.last == "\"" else {
            return value
        }

        return String(value.dropFirst().dropLast())
    }

    private func powerShellEscapedLiteral(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }

    private func lastPathComponent(of path: String) -> String {
        let separators = CharacterSet(charactersIn: "/\\")
        let components = path.components(separatedBy: separators).filter { !$0.isEmpty }
        return components.last ?? path
    }

    private func joinPath(_ base: String, _ component: String, separator: Character) -> String {
        let normalizedBase = base.hasSuffix(String(separator)) ? String(base.dropLast()) : base
        let normalizedComponent = component.hasPrefix(String(separator)) ? String(component.dropFirst()) : component
        return normalizedBase + String(separator) + normalizedComponent
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }
}

struct ManagedAppCommandResult {
    let exitStatus: Int32
    let standardOutput: String
    let standardError: String
}

struct ManagedAppCommand: Equatable {
    let executablePath: String
    let arguments: [String]
}

protocol ManagedAppCommandRunning {
    func run(_ command: ManagedAppCommand) throws -> ManagedAppCommandResult
}

private struct SystemManagedAppCommandRunner: ManagedAppCommandRunning {
    func run(_ command: ManagedAppCommand) throws -> ManagedAppCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.executablePath)
        process.arguments = command.arguments

        let standardOutput = Pipe()
        let standardError = Pipe()
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()
        process.waitUntilExit()

        let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let errorData = standardError.fileHandleForReading.readDataToEndOfFile()

        return ManagedAppCommandResult(
            exitStatus: process.terminationStatus,
            standardOutput: String(decoding: outputData, as: UTF8.self),
            standardError: String(decoding: errorData, as: UTF8.self)
        )
    }
}
