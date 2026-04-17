namespace CodexConfigSwitcher.WinUI.Services;

public sealed record WindowsStoragePaths(
    string RootDirectory,
    string PresetsFile,
    string SettingsFile,
    string TemplatesFile,
    string DefaultTargetPath)
{
    public static WindowsStoragePaths CreateDefault()
    {
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var rootDirectory = Path.Combine(appData, "CodexConfigSwitcher");

        return new WindowsStoragePaths(
            RootDirectory: rootDirectory,
            PresetsFile: Path.Combine(rootDirectory, "presets.json"),
            SettingsFile: Path.Combine(rootDirectory, "settings.json"),
            TemplatesFile: Path.Combine(rootDirectory, "templates.json"),
            DefaultTargetPath: Path.Combine(localAppData, "Programs", "Codex", "Codex.exe")
        );
    }
}
