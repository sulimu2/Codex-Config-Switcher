# Codex Config Switcher

一个以 macOS 原生桌面端为主、并已开始提供 Windows CLI 起步版的配置切换工具，用来快速切换和编辑本机 Codex 的这两个文件：

- `~/.codex/config.toml`
- `~/.codex/auth.json`

## 这版已经支持

- 菜单栏常驻入口
- 主窗口状态摘要 + 预设侧边栏 + 分层编辑
- 多预设保存与快速应用
- 读取当前 live 配置并导入为预设
- 清楚区分当前 live 配置、当前选中预设和未保存草稿
- 支持环境标签（官方 / 代理 / 测试 / 备用）和颜色标识
- 常用字段优先展示，高级字段折叠收纳
- 支持基础模式 / 高级模式切换，并保持当前草稿不丢失
- 应用前差异预览，提前看到本次将改动的字段
- 全局设置独立面板，支持选择配置文件和目标 App
- macOS 设置页支持一键恢复默认 `config.toml` / `auth.json` 路径，以及默认目标 App
- 写入前基础校验，删除预设前二次确认
- 高风险环境在应用前会触发二次确认
- 写入前自动备份原始文件
- 支持一键恢复最近备份，恢复前会先自动备份当前配置
- 支持查看最近备份历史，并恢复指定备份
- 应用配置后提示是否自动重启目标软件，默认联动 `Codex`
- 菜单栏高亮当前生效预设，并显示最近应用状态
- 支持复制当前预设、导入 JSON 预设文件、导出当前预设
- 导入支持两种模式：追加导入（同名自动重命名）/ 导入并覆盖同名
- 支持一键导出全部预设，便于整套预设备份和迁移
- 支持一键导出收藏预设，便于同步常用环境集合
- 支持收藏常用预设，并在菜单栏优先展示收藏与最近使用
- 主窗口侧边栏支持搜索预设、按收藏/最近使用/全部预设分组浏览
- 主窗口支持按环境标签筛选预设，并按最近使用优先或名称排序
- 支持测试连接，轻量检查接口地址、鉴权和主模型可用性
- 支持为每个预设绑定站点门户地址，并在应用内完成站点登录
- 登录站点账户后，可查看该预设对应账户的余额、累计 token、请求量、模型使用分布和可用模型列表
- 站点登录态与账号概览已改为独立存储，不会进入模板文件，也不会混入预设导出文件
- 支持 macOS 首次打开引导：逐步确认目标文件、当前 live 配置、目标 App 和可选站点账户登录
- 首次分发打开如果遇到系统拦截，应用内和文档里都会提供“未 notarize / unknown developer”和“已损坏”两类情况的区别说明
- 支持查看最近操作历史，记录预设应用与备份恢复的成功/失败结果
- 支持应用内快捷键：`⌘⇧O` 打开主窗口，`⌘↩` 应用当前草稿/预设，`⌘R` 重新读取当前配置
- 支持本地模板库：可从当前草稿保存为模板，并从模板快速创建新预设
- 模板默认不保存 `API Key` 等敏感认证字段，更适合沉淀可复用配置骨架
- 支持模板工作台：可搜索模板、预览关键信息，并执行载入草稿、覆盖模板、重命名、删除等管理操作
- 侧边栏“从模板新建”已升级为弹出式快速创建入口，能先看模板摘要再生成新预设
- 已新增跨平台 CLI，支持查看 live 状态、列出预设、应用预设、抓取当前 live 为预设、保存模板、从模板创建预设
- CLI 已支持目标应用管理：查看目标应用状态、设置自定义 `Codex.exe` / `.app` 路径、恢复默认目标、重启目标应用
- 已搭建 Windows WinUI 3 工程骨架，支持预设列表、live 状态摘要、目标应用控制和通过 CLI 桥接执行应用操作
- 导入失败时会提示更细的格式和字段错误原因
- 只更新受管字段，尽量保留 `config.toml` 里的其他配置和 `auth.json` 里的其他键

## 本地运行

### macOS 桌面版

```bash
cd <repo-path>
swift run CodexConfigSwitcher
```

### CLI（macOS / Windows 首期）

```bash
cd <repo-path>
swift run CodexConfigSwitcherCLI help
```

常用命令：

```bash
swift run CodexConfigSwitcherCLI status
swift run CodexConfigSwitcherCLI list-presets
swift run CodexConfigSwitcherCLI apply --preset 官方环境 --restart
swift run CodexConfigSwitcherCLI capture-live --name 当前机器
swift run CodexConfigSwitcherCLI save-template --preset 官方环境 --name 官方模板
swift run CodexConfigSwitcherCLI create-from-template --template 官方模板 --name 新机器模板
swift run CodexConfigSwitcherCLI target status
swift run CodexConfigSwitcherCLI target set-path --path "C:\\Users\\bridge\\AppData\\Local\\Programs\\Codex\\Codex.exe"
swift run CodexConfigSwitcherCLI target restart
swift run CodexConfigSwitcherCLI status --json
```

## 构建 `.app`

```bash
cd <repo-path>
./scripts/build-icon-assets.sh
./scripts/build-app.sh
```

构建完成后，生成物在：

`./dist/Codex Config Switcher.app`

## 构建 `.dmg`

```bash
cd <repo-path>
./scripts/build-dmg.sh
```

构建完成后，生成物在：

`./dist/Codex-Config-Switcher-<version>.dmg`

说明：

- `dmg` 内会包含 `Codex Config Switcher.app` 和指向 `/Applications` 的快捷方式，便于拖拽安装。
- 当前产物为本地构建安装包，未做 Apple notarization；首次打开时如果系统提示安全限制，需要在系统设置中手动放行。

## Windows 当前进度

截至 `2026-04-10`：

- 已完成平台感知默认路径与默认目标应用抽象。
- 已提供 `CodexConfigSwitcherCLI`，可在 Windows 上先复用预设、模板和配置写入主流程。
- 已提供目标应用 CLI 管理命令，可配置自定义 `Codex.exe` 路径并执行状态探测/重启。
- 已新增 `windows/CodexConfigSwitcher.Windows.sln` 和 `windows/CodexConfigSwitcher.WinUI/`，开始搭建 WinUI 3 原生 GUI。
- WinUI 3 首屏当前已接入“本地 JSON 仓储 + CLI JSON 桥”架构，首批覆盖预设列表、当前 live 摘要、目标应用状态、应用预设、应用并重启、目标路径设置。
- 当前开发机没有 `dotnet`，因此 WinUI 3 工程尚未在本机编译；需要在 Windows + Visual Studio 环境中继续验证。
- 当前 WinUI 3 GUI 仍依赖外部 `CodexConfigSwitcherCLI.exe`，可通过环境变量 `CODEX_CONFIG_SWITCHER_CLI_PATH` 或同级目录发现。

### Windows GUI 入口

- 解决方案：`./windows/CodexConfigSwitcher.Windows.sln`
- 项目：`./windows/CodexConfigSwitcher.WinUI/`
- 说明文档：`./windows/README.md`

## 预设保存位置

- `~/Library/Application Support/CodexConfigSwitcher/presets.json`
- `~/Library/Application Support/CodexConfigSwitcher/templates.json`
- `~/Library/Application Support/CodexConfigSwitcher/preset-account-sessions.json`
- `~/Library/Application Support/CodexConfigSwitcher/settings.json`
- `~/Library/Application Support/CodexConfigSwitcher/Backups/`
- Windows 默认目录会切换为 `%APPDATA%\\CodexConfigSwitcher\\`

## 图标资产

- 主图标 SVG：`./Design/bridge-switch-app-icon.svg`
- 菜单栏单色 SVG：`./Design/bridge-switch-menubar.svg`
- 主图标透明 PNG：`./Design/bridge-switch-app-icon.png`
- macOS 图标文件：`./Support/AppIcon.icns`
