using System.Text.Json.Serialization;

namespace CodexConfigSwitcher.WinUI.Models;

public sealed class CodexPresetRecord
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("environmentTag")]
    public string EnvironmentTag { get; set; } = "official";

    [JsonPropertyName("providerName")]
    public string ProviderName { get; set; } = "OpenAI";

    [JsonPropertyName("baseURL")]
    public string BaseUrl { get; set; } = string.Empty;

    [JsonPropertyName("model")]
    public string Model { get; set; } = "gpt-5.4";

    [JsonPropertyName("reviewModel")]
    public string ReviewModel { get; set; } = "gpt-5.4";

    [JsonPropertyName("authMode")]
    public string AuthMode { get; set; } = "apikey";

    public string EnvironmentTitle => EnvironmentTag switch
    {
        "official" => "官方",
        "proxy" => "代理",
        "test" => "测试",
        "backup" => "备用",
        _ => EnvironmentTag
    };

    public string SummaryLine => $"{EnvironmentTitle} / {Model}";
}
