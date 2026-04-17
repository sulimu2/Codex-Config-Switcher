# Windows WinUI 3 Bootstrap

当前目录包含 Windows 原生 GUI 的首期 WinUI 3 工程骨架。

## 当前范围

- 读取 `%APPDATA%\CodexConfigSwitcher\presets.json` 和 `settings.json`
- 展示预设列表、当前 live 摘要、目标应用状态
- 通过 `CodexConfigSwitcherCLI` 执行应用预设、应用并重启、目标路径更新、恢复默认目标、重启目标应用

## 依赖

- Visual Studio 2022
- `.NET 8 SDK`
- Windows App SDK / WinUI 3 开发工作负载
- `CodexConfigSwitcherCLI.exe`

## CLI 发现规则

WinUI 工程会按下面顺序查找 CLI：

1. 环境变量 `CODEX_CONFIG_SWITCHER_CLI_PATH`
2. GUI 可执行文件同级目录下的 `CodexConfigSwitcherCLI.exe`
3. 当前系统 `PATH` 中的 `CodexConfigSwitcherCLI.exe`

## 说明

- 这轮是在没有 `dotnet` 的开发机上完成的，因此工程文件和 XAML 已搭好，但尚未在本机编译验证。
- `Assets/` 当前复用了仓库里的现有 PNG 作为打包占位资源，后续需要在 Windows 真机上补正式尺寸和清晰度。
