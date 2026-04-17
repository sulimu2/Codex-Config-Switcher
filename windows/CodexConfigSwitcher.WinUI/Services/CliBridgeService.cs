using System.ComponentModel;
using System.Diagnostics;
using System.Text.Json;
using CodexConfigSwitcher.WinUI.Models;

namespace CodexConfigSwitcher.WinUI.Services;

public sealed class CliBridgeService
{
    private readonly JsonSerializerOptions jsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    private readonly string executableName;

    public CliBridgeService()
    {
        executableName = ResolveExecutableName();
    }

    public string ResolutionHint => executableName;

    public async Task<CliStatusPayload> GetStatusAsync()
    {
        var result = await RunAsync("status", "--json");
        return Deserialize<CliStatusPayload>(result.StandardOutput);
    }

    public async Task<CliTargetStatusPayload> GetTargetStatusAsync()
    {
        var result = await RunAsync("target", "status", "--json");
        return Deserialize<CliTargetStatusPayload>(result.StandardOutput);
    }

    public Task ApplyPresetAsync(string presetName, bool restartTargetApp)
    {
        var arguments = new List<string> { "apply", "--preset", presetName };
        if (restartTargetApp)
        {
            arguments.Add("--restart");
        }

        return RunDiscardingOutputAsync(arguments.ToArray());
    }

    public Task SetTargetPathAsync(string path)
    {
        return RunDiscardingOutputAsync("target", "set-path", "--path", path);
    }

    public Task ResetTargetAppAsync()
    {
        return RunDiscardingOutputAsync("target", "reset");
    }

    public Task RestartTargetAppAsync()
    {
        return RunDiscardingOutputAsync("target", "restart");
    }

    private async Task RunDiscardingOutputAsync(params string[] arguments)
    {
        await RunAsync(arguments);
    }

    private async Task<CliInvocationResult> RunAsync(params string[] arguments)
    {
        try
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = executableName,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true,
            };

            foreach (var argument in arguments)
            {
                startInfo.ArgumentList.Add(argument);
            }

            using var process = new Process { StartInfo = startInfo };
            process.Start();

            var standardOutputTask = process.StandardOutput.ReadToEndAsync();
            var standardErrorTask = process.StandardError.ReadToEndAsync();

            await process.WaitForExitAsync();

            var standardOutput = await standardOutputTask;
            var standardError = await standardErrorTask;

            if (process.ExitCode != 0)
            {
                throw new InvalidOperationException(
                    string.IsNullOrWhiteSpace(standardError) ? standardOutput.Trim() : standardError.Trim()
                );
            }

            return new CliInvocationResult(standardOutput.Trim(), standardError.Trim());
        }
        catch (Win32Exception ex)
        {
            throw new InvalidOperationException(
                $"未找到 CodexConfigSwitcherCLI。请将 `CodexConfigSwitcherCLI.exe` 放到应用同级目录，或设置环境变量 CODEX_CONFIG_SWITCHER_CLI_PATH。当前尝试：{executableName}",
                ex
            );
        }
    }

    private T Deserialize<T>(string payload)
    {
        var result = JsonSerializer.Deserialize<T>(payload, jsonOptions);
        if (result is null)
        {
            throw new InvalidOperationException("CLI 返回了空 JSON。");
        }

        return result;
    }

    private string ResolveExecutableName()
    {
        var explicitPath = Environment.GetEnvironmentVariable("CODEX_CONFIG_SWITCHER_CLI_PATH");
        if (!string.IsNullOrWhiteSpace(explicitPath))
        {
            return explicitPath;
        }

        var appDirectory = AppContext.BaseDirectory;
        var sideBySideExecutable = Path.Combine(appDirectory, "CodexConfigSwitcherCLI.exe");
        if (File.Exists(sideBySideExecutable))
        {
            return sideBySideExecutable;
        }

        return "CodexConfigSwitcherCLI.exe";
    }

    private sealed record CliInvocationResult(string StandardOutput, string StandardError);
}
