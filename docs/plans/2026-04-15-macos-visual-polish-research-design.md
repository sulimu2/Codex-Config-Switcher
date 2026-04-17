# Codex Config Switcher macOS 美化研究与方案

日期：2026-04-15

聚焦范围：仅 macOS SwiftUI 主程序与菜单栏入口，不包含 Windows WinUI 端。

[artifact:PRD]
status: READY
owner: product
scope:
- 为 macOS 端建立一套更像成熟原生工具的视觉与交互方向
- 在不重写核心逻辑的前提下提升“看起来更高级、用起来更安心、切换更快”
inputs:
- 当前实现：`Sources/CodexConfigSwitcher/Views/MainWindowView.swift`
- 当前实现：`Sources/CodexConfigSwitcher/Views/PresetEditorView.swift`
- 当前实现：`Sources/CodexConfigSwitcher/Views/MenuBarContentView.swift`
- 现有品牌资产：`Design/bridge-switch-app-icon.png`
- 外部参考：Apple HIG、Tailscale、Raycast
deliverables:
- 用户视角问题清单
- 产品经理视角优化目标
- 3 套视觉方向候选与推荐路线
- 仅针对 macOS 的分阶段落地计划
risks:
- 如果直接追求“花哨”，可能削弱原生感和工具可信度
handoff_to:
- design
- engineering
exit_criteria:
- 能指导下一轮 macOS UI 美化实现

## 1. 真实问题重述

这款工具的核心价值不是“编辑配置文件”，而是“让用户放心地切换 Codex 工作环境”。当前版本功能已经足够完整，但界面给人的感受更接近“能力很多的工程面板”，还没有进入“高频效率工具”的质感层。

从用户角度，痛点不是缺按钮，而是这三件事还不够顺：

1. 打开后不能在 2 秒内明确确认“当前到底生效的是哪个环境”。
2. 编辑区的信息密度偏高，视觉主次还不够稳，导致第一次看会紧张。
3. 菜单栏入口虽然能快切，但内容偏长，像缩小版管理台，不够利落。

从产品经理角度，这意味着产品已经跨过“能用”，但还没跨过“敢长期用”。美化的目标不该只是换颜色和圆角，而是把信任感、状态感和节奏感一起做出来。

## 2. 用户视角诊断

- 主窗口顶部同时出现总览卡、快速动作、上下文提示、工作区切换，入口很多，但第一眼主任务不够聚焦。
- 左侧预设列表有信息，但视觉层级偏平均，重要项和普通项没有拉开足够差距。
- 编辑区里 `基础配置 / 认证 / 连接说明 / 差异 / 高级配置 / 状态` 连续堆叠，像表单集合，不像工作台。
- 菜单栏里“备份、重启、设置、恢复、退出”都直接暴露，高频与低频动作混在一起。
- 状态反馈主要靠文字和浅色块，缺少更强的视觉锚点，比如主色区、显著状态点、成功后的短反馈。

## 3. 产品经理视角目标

- 把产品心智从“配置编辑器”升级成“配置切换工作台”。
- 让主窗口承担“理解状态 + 编辑配置 + 安全应用”。
- 让菜单栏承担“确认当前环境 + 快速切换 + 最小应急操作”。
- 把高级和低频内容往后压，让高频路径更像专业 macOS 工具，而不是后台管理页。

建议用下面 4 个指标判断美化是否成功：

- 首屏可读性：首次打开 2 秒内能理解当前环境、当前编辑对象、主要动作。
- 切换效率：常用预设切换路径保持在 2 次点击以内。
- 视觉信任感：风险、成功、未保存三类状态一眼可辨。
- 原生一致性：看起来像认真打磨过的 macOS 工具，而不是移植风格 UI。

[artifact:UserStory]
status: READY
owner: product
scope:
- 定义高频使用场景下的用户期待
inputs:
- 当前 macOS 界面结构
- 产品定位与 README 功能说明
deliverables:
- 高频切换用户故事
- 首次使用用户故事
- 风险恢复用户故事
risks:
- None
handoff_to:
- design
exit_criteria:
- 能支撑视觉与交互决策

### 用户故事

- 作为高频切换环境的用户，我希望打开菜单栏就知道当前环境，并且两步内切到常用预设，不需要读很多说明。
- 作为第一次接触工具的用户，我希望主窗口先告诉我“当前状态”和“推荐下一步”，而不是先让我面对大量字段。
- 作为担心改坏配置的用户，我希望危险状态、未保存修改、恢复路径都非常明确，这样我才敢长期依赖它。

[artifact:DesignSpec]
status: READY
owner: design
scope:
- 只定义 macOS 端的视觉语言、层级和界面方向
inputs:
- `Design/bridge-switch-app-icon.png`
- `Sources/CodexConfigSwitcher/Views/MainWindowView.swift`
- `Sources/CodexConfigSwitcher/Views/PresetEditorView.swift`
- `Sources/CodexConfigSwitcher/Views/MenuBarContentView.swift`
- `Sources/CodexConfigSwitcher/Views/Components/TemplateWorkbenchPanel.swift`
- 外部参考资料
deliverables:
- 3 套方向候选
- 推荐方向与视觉原则
- 关键区域的美化策略
risks:
- 如果一次改太多区域，容易让界面风格不统一
handoff_to:
- engineering
exit_criteria:
- 设计方向可直接转换成实现任务

## 4. 视觉方向候选

### 方案 A：Slate Glass Workbench

推荐指数：最高

核心特征：

- 继承现有图标里的深蓝灰、冰蓝、薄荷绿、琥珀橙。
- 主窗口使用轻玻璃感和低对比层叠卡片，但保持文字清晰，不走花哨拟态。
- 用一块更强的“当前环境总览 Hero 区”做视觉锚点。
- 让状态徽章、环境标签、风险提示形成统一 token 体系。

适合原因：

- 与现有图标资产最一致，品牌延续成本最低。
- 可以直接复用当前 `TemplateWorkbenchPanel` 已经形成的卡片、边框、阴影和胶囊标签语言。
- 很适合“可信赖的专业工具”定位。
- 能明显提升质感，又不会破坏 macOS 原生感。

### 方案 B：Raycast 式高对比效率面板

推荐指数：中

核心特征：

- 更克制的中性背景，更强的搜索框和动作栏存在感。
- 列表、动作、快捷路径会更锋利、更强调速度感。
- 图标与按钮风格更统一，强调扫描效率。

适合原因：

- 很适合高频效率工具。
- 对菜单栏快切和搜索很有帮助。

不足：

- 如果直接照搬，会让产品更像命令工具，而不是“配置切换工作台”。

### 方案 C：Tailscale 式状态驱动工具窗

推荐指数：中高

核心特征：

- 菜单栏保持极简，只服务快切和应急。
- 复杂状态、错误、发现式功能全部回到独立窗口。
- 强调“右侧详情 + 左侧列表”的设备/节点工作台感。

适合原因：

- 非常适合你这个“菜单栏 + 主窗口”双入口结构。
- 能把快切与管理分工做得更彻底。

不足：

- 如果直接偏向状态监控风，会弱化编辑器的亲和度。

## 5. 推荐方向

推荐以 **方案 A 为主、吸收方案 B 的效率表达、采用方案 C 的入口分工**。

也就是：

- 视觉上走 `Slate Glass Workbench`
- 搜索与动作密度借鉴 Raycast
- 菜单栏/主窗口职责拆分借鉴 Tailscale

这样最符合当前项目状态，也最贴近已有图标资产。

## 6. 推荐视觉系统

### 色彩

建议从现有图标提炼一套稳定色板：

- `Ink`：深背景主色，用于 Hero 区或重点状态底
- `Slate`：主表面中性色，用于次级背景和边框
- `Ice`：高亮信息和 hover 反馈
- `Mint`：安全、同步、已生效
- `Amber`：风险、未保存、注意事项

原则：

- 颜色只服务状态和层级，不要让每块卡片都抢戏。
- 高风险橙、成功绿、普通蓝保持稳定语义，不要在不同区域换含义。

### 形状与材质

- 卡片圆角统一到 16/18/20 三档，不再散落多个圆角习惯。
- 主卡片加 1px 低对比描边和非常轻的阴影，避免厚重边框。
- 总览区和菜单栏当前状态卡可以使用更明显的渐变或微弱光晕，其余区域保持克制。
- 背景建议引入非常轻的分层材质感，而不是纯 `secondary.opacity(...)` 平铺到底。

### 字体与图标

- 保持 SF Pro 体系，不建议换字体，重点做字号和权重秩序。
- 标题尽量减少层级数量，建议固定为：页面标题 / 区块标题 / 辅助说明 / 微说明。
- SF Symbols 统一用 outline 风格，避免有的粗有的细。
- 模型名、时间、URL 摘要可局部使用等宽数字或更紧凑的次级样式，增强工具感。

## 7. 针对当前界面的美化方案

### 7.1 主窗口

现状触点：

- `MainWindowView` 顶部总览与快速动作：`Sources/CodexConfigSwitcher/Views/MainWindowView.swift`
- 总览卡：`Sources/CodexConfigSwitcher/Views/Components/CurrentStatusSummaryCard.swift`

建议：

- 把顶部做成一个更完整的 Hero 区，而不是“左一张卡 + 右一块动作面板”的拼接感。
- 将“快速动作”改成更像工具栏的横向主动作区，只保留 `重新读取 / 载入 live / 恢复备份 / 收藏`，并弱化描述文字。
- 当前总览卡里 4 个摘要块建议增加更强主次：`当前生效` 和 `草稿状态` 最大，`最近应用` 和 `目标应用` 次级。
- 上下文提示 `LiveContextBanner` 可以继续保留，但视觉上应更像内联警示条，而不是再来一大张橙色卡片。

### 7.2 侧边栏

现状触点：

- 预设列表与底部操作：`Sources/CodexConfigSwitcher/Views/MainWindowView.swift`
- 预设行：`Sources/CodexConfigSwitcher/Views/Components/PresetSidebarRow.swift`

建议：

- 顶部搜索保留，但筛选和排序建议从两个菜单压缩成更像 macOS 工具条的紧凑控件。
- 把底部一整坨按钮拆掉：`新建` 放主工具栏，`复制/删除/导出/导入` 进入选中项更多菜单。
- 预设行增加 hover 和选中高亮带，当前生效项增加更明确的左侧强调条或背景层。
- 收藏、当前生效、未保存、最近应用不要同时抢眼，建议规定优先级，只突出最重要的一个主状态。

### 7.3 编辑区

现状触点：

- `Sources/CodexConfigSwitcher/Views/PresetEditorView.swift`

建议：

- 把操作头部重新组织成“标题 + 主动作 + 次动作”，不要把三个保存动作平铺得一样重。
- 推荐主按钮固定为 `应用`，次按钮为 `保存`，低频按钮如 `保存为模板` 放入更多菜单。
- `连接检查说明` 这类解释性文本不要占一个独立 GroupBox，可折叠到测试结果卡内。
- `基础配置` 与 `认证` 区域可使用双列栅格，但高级区继续折叠，且默认减少说明文字长度。
- `高级模式` 下的很多字段仍然是“工程名直出”，建议视觉上做“中文主标签 + 灰色键名副标签”。

### 7.4 菜单栏窗口

现状触点：

- `Sources/CodexConfigSwitcher/Views/MenuBarContentView.swift`

建议：

- 顶部当前状态卡保留，但把它做得更像“当前环境指示器”，而不是简化版详情卡。
- 菜单栏的高频区只留：当前环境、收藏、最近使用、搜索、打开主窗口。
- `重启目标应用 / 打开备份目录 / 恢复最近备份 / 退出` 收进次级区域，默认不打断快切视线。
- 最近备份列表默认折叠，否则弹层高度会迅速失控。
- 应用成功后加一条非常短的窗口内反馈，例如“已切换到 官方环境”，而不是只依赖状态文案变化。

[artifact:InteractionSpec]
status: READY
owner: design
scope:
- 仅定义 macOS 端需要补的节奏、反馈和动效
inputs:
- 当前 SwiftUI 视图层
- 菜单栏与主窗口双入口结构
deliverables:
- 动效原则
- 反馈原则
- 状态表达规则
risks:
- 过度动效会损害工具效率感
handoff_to:
- engineering
exit_criteria:
- 交互改动可映射到 SwiftUI 组件实现

## 8. 交互与动效规则

- 只做 3 类动效：列表 hover/selection、卡片状态切换、应用成功的短反馈。
- 不建议大量弹跳或缩放，优先使用透明度、轻微位移和颜色过渡。
- 成功、失败、风险三类反馈固定视觉语义，不在不同场景反复变化。
- 预设切换时，侧边栏和总览卡应同步变化，增强“同一工作上下文正在切换”的连贯感。

[artifact:SystemArch]
status: READY
owner: architect
scope:
- 仅评估 macOS 美化所需的代码切入点，不改动核心配置逻辑
inputs:
- 当前 SwiftUI 视图文件
- 现有组件拆分情况
deliverables:
- 建议的实现边界
- 推荐先改的文件区域
risks:
- 如果把视觉 token 到处写死，后续统一会困难
handoff_to:
- engineering-manager
exit_criteria:
- 能开始做 UI-only refactor

## 9. 实现边界建议

这一轮美化建议保持 **UI-only refactor**，不碰核心读写流程。

建议优先改动区域：

- `Sources/CodexConfigSwitcher/Views/MainWindowView.swift`
- `Sources/CodexConfigSwitcher/Views/PresetEditorView.swift`
- `Sources/CodexConfigSwitcher/Views/MenuBarContentView.swift`
- `Sources/CodexConfigSwitcher/Views/Components/CurrentStatusSummaryCard.swift`
- `Sources/CodexConfigSwitcher/Views/Components/PresetSidebarRow.swift`
- `Sources/CodexConfigSwitcher/Views/Components/PresetStatusBadge.swift`
- `Sources/CodexConfigSwitcher/Views/Components/PresetEnvironmentBadge.swift`
- 可新增一个统一样式文件，例如 `Sources/CodexConfigSwitcher/Views/Components/AppTheme.swift`

推荐抽出：

- 统一间距、圆角、描边、表面背景 token
- 统一 badge 样式
- 主按钮/次按钮样式
- 菜单栏卡片和主窗口卡片的共享视觉规则

[artifact:TaskBreakdown]
status: READY
owner: engineering-manager
scope:
- 拆分 macOS UI 美化工作顺序
inputs:
- 视觉方案
- 当前代码结构
deliverables:
- 分阶段执行顺序
- 每阶段目标
risks:
- 如果先改局部样式、不先统一 token，会返工
handoff_to:
- engineering
exit_criteria:
- 有可执行的美化迭代路线

## 10. 分阶段落地建议

### P0：统一视觉 token

- 抽颜色、圆角、卡片背景、描边、间距常量
- 统一 badge 和卡片表面风格

### P1：主窗口顶部重构

- 重做总览 Hero 区
- 压缩快速动作区
- 弱化上下文提示的体积

### P2：侧边栏与列表质感提升

- 预设行 hover、selection、live 状态强化
- 底部按钮重组为更简洁的工具操作

### P3：编辑区层级优化

- 操作头部重排
- 基础/认证/测试/高级信息重新分层
- 更换一批更像产品语言的文案层级

### P4：菜单栏极简化

- 收缩低频操作
- 强化当前环境指示
- 增加快切后的短反馈

### P5：动效与细节收口

- hover/selection 过渡
- 状态切换动画
- 图标、间距、标题秩序统一检查

[artifact:Approval]
result: APPROVED
owner: engineering-manager
scope:
- macOS 端 UI 美化研究与后续实现边界
required_inputs:
- [artifact:PRD]
- [artifact:UserStory]
- [artifact:DesignSpec]
- [artifact:InteractionSpec]
- [artifact:SystemArch]
- [artifact:TaskBreakdown]
checklist:
- [x] Scope is clear
- [x] Dependencies are identified
- [x] Implementation boundaries are defined
- [x] Risks are understood
blocking_issues:
- None
approved_scope:
- 仅 macOS SwiftUI 层的视觉与交互重构
- 不改核心配置读写逻辑
- 优先改主窗口、侧边栏、菜单栏和共享视觉组件
handoff_to:
- engineering

[artifact:ImplementationPlan]
status: READY
owner: engineering
scope:
- macOS 端第一轮 UI 美化实现
inputs:
- 本文档全部 artifacts
handoff_to:
- implementer
goal:
- 让主窗口更像可信赖的原生工作台，让菜单栏更像真正的快切器
changed_areas:
- `Sources/CodexConfigSwitcher/Views/MainWindowView.swift`
- `Sources/CodexConfigSwitcher/Views/PresetEditorView.swift`
- `Sources/CodexConfigSwitcher/Views/MenuBarContentView.swift`
- `Sources/CodexConfigSwitcher/Views/Components/*.swift`
- 可能新增统一样式文件
steps:
- 先建立共享视觉 token 和基础卡片样式
- 重做主窗口总览区与快速动作区
- 提升侧边栏行项目、筛选区和底部操作的层级
- 重排编辑区头部与各 section 的主次关系
- 收缩菜单栏低频内容，突出当前环境和快切路径
- 最后补 hover、状态过渡和成功反馈
risks:
- SwiftUI 在 macOS 上的材质与列表选中样式需要真实运行调试
- 如果一次重排过多按钮层级，需要同步校准快捷操作入口
validation:
- 手动验证主窗口与菜单栏两条高频路径
- 检查亮色/暗色模式下的对比度
- 检查当前生效/未保存/风险状态是否一眼可辨

## 11. 外部参考链接

- Apple Human Interface Guidelines: Designing for macOS
  https://developer.apple.com/design/human-interface-guidelines/designing-for-macos
- Apple Human Interface Guidelines: Search fields
  https://developer.apple.com/design/human-interface-guidelines/search-fields
- Apple Human Interface Guidelines: Toolbars
  https://developer.apple.com/design/human-interface-guidelines/toolbars
- Apple Human Interface Guidelines: The menu bar
  https://developer.apple.com/design/human-interface-guidelines/the-menu-bar
- Tailscale: Tailscale’s windowed macOS UI is now in beta
  https://tailscale.com/blog/windowed-macos-ui-beta
- Raycast: A fresh look and feel
  https://www.raycast.com/blog/a-fresh-look-and-feel
