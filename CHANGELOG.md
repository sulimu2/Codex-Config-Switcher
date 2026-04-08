# Changelog

本项目遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [0.1.0] - 2026-04-09

### Added

- 初始化 `Codex Config Switcher` macOS 原生应用工程。
- 支持读取和编辑 `~/.codex/config.toml` 与 `~/.codex/auth.json`。
- 支持保存、编辑、应用多个配置预设。
- 支持从当前 live 配置导入预设。
- 支持写入前自动备份原始配置文件。
- 支持应用配置后提示是否自动重启目标软件，默认联动 `Codex`。
- 提供菜单栏入口、主窗口编辑界面、图标资源与 `.app` 打包脚本。
- 提供核心配置文件服务与预设持久化测试。
