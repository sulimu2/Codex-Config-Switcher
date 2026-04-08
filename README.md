# Codex Config Switcher

一个原生 macOS 小工具，用来快速切换和编辑本机 Codex 的这两个文件：

- `~/.codex/config.toml`
- `~/.codex/auth.json`

## 这版已经支持

- 菜单栏常驻入口
- 主窗口完整编辑
- 多预设保存与快速应用
- 读取当前 live 配置并导入为预设
- 写入前自动备份原始文件
- 应用配置后提示是否自动重启目标软件，默认联动 `Codex`
- 只更新受管字段，尽量保留 `config.toml` 里的其他配置和 `auth.json` 里的其他键

## 本地运行

```bash
cd <repo-path>
swift run CodexConfigSwitcher
```

## 构建 `.app`

```bash
cd <repo-path>
./scripts/build-icon-assets.sh
./scripts/build-app.sh
```

构建完成后，生成物在：

`./dist/Codex Config Switcher.app`

## 预设保存位置

- `~/Library/Application Support/CodexConfigSwitcher/presets.json`
- `~/Library/Application Support/CodexConfigSwitcher/settings.json`
- `~/Library/Application Support/CodexConfigSwitcher/Backups/`

## 图标资产

- 主图标 SVG：`./Design/bridge-switch-app-icon.svg`
- 菜单栏单色 SVG：`./Design/bridge-switch-menubar.svg`
- 主图标透明 PNG：`./Design/bridge-switch-app-icon.png`
- macOS 图标文件：`./Support/AppIcon.icns`
