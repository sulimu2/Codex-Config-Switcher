using System.Text.Json;
using CodexConfigSwitcher.WinUI.Models;

namespace CodexConfigSwitcher.WinUI.Services;

public sealed class LocalStateRepository
{
    private readonly JsonSerializerOptions jsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    public WindowsStoragePaths Paths { get; } = WindowsStoragePaths.CreateDefault();

    public async Task<IReadOnlyList<CodexPresetRecord>> LoadPresetsAsync()
    {
        if (!File.Exists(Paths.PresetsFile))
        {
            return Array.Empty<CodexPresetRecord>();
        }

        await using var stream = File.OpenRead(Paths.PresetsFile);
        var presets = await JsonSerializer.DeserializeAsync<List<CodexPresetRecord>>(stream, jsonOptions);
        return presets ?? Array.Empty<CodexPresetRecord>();
    }

    public async Task<AppSettingsRecord> LoadSettingsAsync()
    {
        if (!File.Exists(Paths.SettingsFile))
        {
            return new AppSettingsRecord
            {
                TargetApp = ManagedAppTargetRecord.CreateDefault(),
            };
        }

        await using var stream = File.OpenRead(Paths.SettingsFile);
        var settings = await JsonSerializer.DeserializeAsync<AppSettingsRecord>(stream, jsonOptions);
        return settings ?? new AppSettingsRecord
        {
            TargetApp = ManagedAppTargetRecord.CreateDefault(),
        };
    }
}
