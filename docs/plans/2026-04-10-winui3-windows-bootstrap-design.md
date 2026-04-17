# Codex Config Switcher WinUI 3 Bootstrap Design

日期：2026-04-10

## 1. 目标

在不重写现有 Swift core 的前提下，为 Windows 版本搭建一个可继续迭代的 WinUI 3 首屏骨架。首期只解决三个问题：

1. 能看到本地预设列表和当前 live 状态。
2. 能应用选中预设，并可选立即重启目标应用。
3. 能管理目标应用路径，并查看当前状态。

## 2. 约束

- 当前开发机没有 `dotnet`，因此本轮只能提供 WinUI 3 工程骨架和代码，无法在本机编译验证。
- 现有核心逻辑仍在 Swift 侧，尤其是 `config.toml` / `auth.json` 的受管写入逻辑，因此 Windows GUI 不能直接取代 CLI。
- 为避免在 C# 端重复实现复杂配置写入规则，本轮采用“WinUI 3 读本地 JSON + 调 Swift CLI 执行运行时动作”的桥接方案。

## 3. 方案

### 3.1 工程形态

新增 `windows/CodexConfigSwitcher.WinUI/` 单独承载 WinUI 3 工程。项目保持独立，不进入 Swift Package 管理范围。

### 3.2 数据分层

- `LocalStateRepository`
  - 直接读取 `%APPDATA%\CodexConfigSwitcher\presets.json`
  - 直接读取 `%APPDATA%\CodexConfigSwitcher\settings.json`
  - 只负责轻量本地状态，不负责 live 配置读写
- `CliBridgeService`
  - 通过 `CodexConfigSwitcherCLI` 调用 `status --json`
  - 调用 `apply --preset ... [--restart]`
  - 调用 `target set-path / reset / restart`
  - 处理 CLI 缺失、命令失败和 JSON 反序列化错误

### 3.3 UI 范围

首屏采用“双栏工作台”：

- 左侧：预设列表
- 右侧上部：当前 live / 目标应用 / CLI 状态摘要
- 右侧中部：当前选中预设的关键字段摘要
- 右侧下部：操作区，包括刷新、应用、应用并重启、目标路径设置、恢复默认目标、重启目标应用

## 4. 后续扩展

当 CLI 桥方案稳定后，再继续进入：

1. 预设编辑与保存
2. 模板浏览与派生
3. 连接测试
4. 文件选择器 / 应用选择器
5. 打包与分发
