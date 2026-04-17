using System.Text.Json.Serialization;
using CodexConfigSwitcher.WinUI.Services;

namespace CodexConfigSwitcher.WinUI.Models;

public sealed class AppSettingsRecord
{
    [JsonPropertyName("selectedPresetID")]
    public Guid? SelectedPresetId { get; set; }

    [JsonPropertyName("lastAppliedAt")]
    public DateTimeOffset? LastAppliedAt { get; set; }

    [JsonPropertyName("targetApp")]
    public ManagedAppTargetRecord TargetApp { get; set; } = ManagedAppTargetRecord.CreateDefault();
}

public sealed class ManagedAppTargetRecord
{
    [JsonPropertyName("displayName")]
    public string DisplayName { get; set; } = "Codex";

    [JsonPropertyName("bundleIdentifier")]
    public string BundleIdentifier { get; set; } = string.Empty;

    [JsonPropertyName("appPath")]
    public string AppPath { get; set; } = WindowsStoragePaths.CreateDefault().DefaultTargetPath;

    public static ManagedAppTargetRecord CreateDefault()
    {
        return new ManagedAppTargetRecord
        {
            DisplayName = "Codex",
            BundleIdentifier = string.Empty,
            AppPath = WindowsStoragePaths.CreateDefault().DefaultTargetPath,
        };
    }
}
