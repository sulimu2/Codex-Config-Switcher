using System.Text.Json.Serialization;

namespace CodexConfigSwitcher.WinUI.Models;

public sealed class CliStatusPayload
{
    [JsonPropertyName("platform")]
    public string Platform { get; set; } = "Windows";

    [JsonPropertyName("configPath")]
    public string ConfigPath { get; set; } = string.Empty;

    [JsonPropertyName("authPath")]
    public string AuthPath { get; set; } = string.Empty;

    [JsonPropertyName("presetCount")]
    public int PresetCount { get; set; }

    [JsonPropertyName("templateCount")]
    public int TemplateCount { get; set; }

    [JsonPropertyName("livePreset")]
    public CodexPresetRecord LivePreset { get; set; } = new();

    [JsonPropertyName("matchedPresetName")]
    public string MatchedPresetName { get; set; } = string.Empty;

    [JsonPropertyName("lastAppliedAt")]
    public DateTimeOffset? LastAppliedAt { get; set; }

    [JsonPropertyName("targetApp")]
    public ManagedAppTargetRecord TargetApp { get; set; } = ManagedAppTargetRecord.CreateDefault();

    [JsonPropertyName("targetAvailability")]
    public string TargetAvailability { get; set; } = "missing";

    [JsonPropertyName("targetAvailabilityTitle")]
    public string TargetAvailabilityTitle { get; set; } = "未找到";
}

public sealed class CliTargetStatusPayload
{
    [JsonPropertyName("targetApp")]
    public ManagedAppTargetRecord TargetApp { get; set; } = ManagedAppTargetRecord.CreateDefault();

    [JsonPropertyName("availability")]
    public string Availability { get; set; } = "missing";

    [JsonPropertyName("availabilityTitle")]
    public string AvailabilityTitle { get; set; } = "未找到";
}
