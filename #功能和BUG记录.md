# 功能和BUG记录

## 2026-04-09 01:27:00 CST

- 类型：仓库整理
- 内容：新增 `.gitignore`，忽略 `.DS_Store`、`.build/`、`.swiftpm/`、`dist/`，并清理仓库中已生成的 `.DS_Store` 文件。
- 思路：先区分真正应该进入版本库的源码、测试、设计资源和支持文件，再把确定属于系统噪音或构建产物的目录统一排除，避免后续提交被无关文件干扰。
- 处理步骤：
  1. 检查 `git status`、目录结构、`README.md` 和构建脚本，确认 `dist/` 是构建输出目录，`.build/`、`.swiftpm/` 是本地 Swift 构建与工具缓存。
  2. 新建 `.gitignore`，加入系统文件和构建目录的忽略规则。
  3. 删除仓库内现有的 `.DS_Store`，让工作区只保留有意义的项目文件。
- 原因：仓库当前还没有忽略规则，导致 macOS 系统文件和 Swift 构建产物全部出现在未跟踪列表中，增加了整理和提交的噪音。

## 2026-04-09 02:10:27 CST

- 类型：新功能
- 内容：完成 P0 产品体验改版，新增预设校验、live/selected/draft 状态区分、主窗口状态摘要、全局设置面板、系统文件/应用选择器、菜单栏当前生效高亮以及删除确认流程。
- 思路：先从 Core 层补齐可测试的预设校验和受管字段指纹能力，再把这些派生状态接到 `AppModel`，最后重构主窗口、编辑区、菜单栏和全局设置入口，让高频路径更短、状态更清楚、危险操作更可控。
- 处理步骤：
  1. 在 `CodexConfigSwitcherCore` 中新增 `PresetValidation.swift`，实现预设校验结果、校验问题文案和 `managedFingerprint`，并补充对应测试，确保底层状态匹配和基础校验有测试覆盖。
  2. 扩展 `AppSettings` 与 `AppModel`，增加最近应用预设元数据、live 预设匹配、未保存草稿识别、目标应用状态文案，以及删除确认和系统选择器所需的状态与方法。
  3. 将主窗口重构为“预设列表 + 当前状态摘要 + 简化编辑区”的结构，新增侧边栏状态徽标、状态摘要卡片和基础/高级分层编辑，减少低频配置对主流程的干扰。
  4. 把路径和目标应用配置迁移到独立的 `SettingsSheetView`，并接入 `NSOpenPanel` 文件/应用选择器，降低手填路径出错概率。
  5. 更新菜单栏视图，突出当前生效预设、最近应用状态和当前 live 配置摘要，同时在应用无效草稿时通过校验提示阻止直接写入。
  6. 运行 `swift test` 全量测试，并执行 `swift run CodexConfigSwitcher` 做启动级 smoke check，确认本轮改版至少通过编译、测试和启动验证。
- 原因：旧版界面把全局设置、预设内容和状态信息混在同一长页中，用户难以分清“当前生效配置”“当前选中预设”和“当前编辑草稿”，菜单栏也无法直观看出当前环境，导致理解成本高、误操作风险大、切换信心不足。

## 2026-04-09 02:21:54 CST

- 类型：新功能
- 内容：继续完善 P0 体验细节，新增菜单栏直达全局设置、设置面板关闭自动保存，以及菜单栏显示最近切换到的预设名称。
- 思路：在第一轮改版完成后，继续补齐“入口联通”和“反馈明确”这两个高频体验点，避免用户从菜单栏进入后还要自己找设置入口，也避免应用成功后只能看到时间而看不出刚切换到了哪个预设。
- 处理步骤：
  1. 在 `AppModel` 中新增 `isShowingSettingsSheet` 和最近应用预设名称状态，让主窗口和菜单栏共享设置面板展示状态，并让 `compactStatusLine` 能输出更明确的“已切换到：某个预设”反馈。
  2. 调整 `MainWindowView` 和 `MenuBarContentView`，让菜单栏点击“打开全局设置”时能够直接拉起主窗口中的设置面板，而不是只打开主窗口停留在默认页面。
  3. 调整 `SettingsSheetView`，在点击“完成”以及面板关闭时自动调用 `persistSettings()`，减少用户修改设置后忘记显式保存造成的状态丢失。
  4. 重新运行 `swift test` 全量测试，并再次执行 `swift run CodexConfigSwitcher` 做启动级 smoke check，确认这轮联通性优化没有引入回归。
- 原因：第一轮改版后虽然已经有了独立设置面板和更清晰的状态结构，但菜单栏到设置的链路还不够直达，设置面板关闭时也依赖用户显式保存，同时菜单栏切换成功提示偏弱，不利于高频使用时快速确认结果。

## 2026-04-09 02:26:10 CST

- 类型：新功能
- 内容：新增应用前差异预览，在主编辑区直接展示当前 live 配置与草稿之间的字段变化，并对 API Key 做脱敏显示。
- 思路：把差异计算逻辑下沉到 Core 层，统一输出可测试的字段差异结果，再让 UI 直接消费这些结果，避免比较逻辑分散在视图层；同时对密钥类字段只展示“已填写/未填写”，避免在预览区泄露敏感值。
- 处理步骤：
  1. 新增 `PresetDiff.swift`，定义字段差异模型、差异类型以及 `PresetDiffer.diff(from:to:)`，统一比较 `base_url`、模型、认证、Provider、运行参数等受管字段。
  2. 新增 `PresetDiffTests.swift`，覆盖“字段被修改”“首次导入视为新增”“API Key 预览脱敏”三类核心行为，保证差异预览的比较结果可靠。
  3. 在 `AppModel` 中增加 `diffPreview` 和 `changedDiffPreview` 派生属性，供主编辑区直接读取当前 live 配置与草稿的差异结果。
  4. 新增 `PresetDiffRow` 组件，并在 `PresetEditorView` 中加入“应用前差异预览”区域，展示“当前 -> 应用后”的变化摘要；如果无变化则明确提示“当前草稿与 live 配置一致”。
  5. 运行 `swift test --filter PresetDiffTests`、`swift test` 和 `swift run CodexConfigSwitcher`，确认本轮新增的差异能力通过测试、编译和启动验证。
- 原因：虽然前一轮已经补了基础校验和状态区分，但用户在真正点击“立即应用”前，仍然无法快速看到“这次到底会改哪些字段”，尤其在多预设切换和高风险配置场景下，缺少变更预览会降低操作信心。

## 2026-04-09 02:37:19 CST

- 类型：新功能 + BUG修复
- 内容：新增“一键恢复最近备份”能力，支持在主窗口、状态区和菜单栏中恢复最近一次备份；同时修复“同一秒内连续创建备份时目录名冲突，导致恢复覆盖原备份目录”的问题。
- 思路：恢复功能采用“先备份当前配置，再恢复最近备份”的保守策略，确保用户误恢复后仍能回滚；在实现过程中把备份目录扫描、最近备份识别和恢复结果统一收敛到 Core 层，再通过 `AppModel` 暴露给主窗口和菜单栏。对备份目录命名冲突问题，则通过目录名去重策略解决，避免恢复流程覆盖掉原始备份。
- 处理步骤：
  1. 在 `CodexFileService` 中新增 `latestBackupSummary()` 和 `restoreLatestBackup(paths:)`，支持识别最近一次备份、在恢复前自动备份当前配置，并将备份文件复制回当前 `config.toml` 与 `auth.json`。
  2. 在 `Models.swift` 中新增 `BackupSnapshotSummary` 和 `RestoreResult`，让备份预览和恢复结果都有明确的数据结构可供 UI 和测试使用。
  3. 在 `CodexFileServiceTests.swift` 中新增恢复相关测试，覆盖“最近备份识别”和“恢复最近备份后文件内容正确且会生成回滚备份”两类核心场景。
  4. 测试过程中发现一个隐藏问题：备份目录名仅使用 `yyyyMMdd-HHmmss`，当恢复与上一次备份落在同一秒内时，会复用同一个目录并覆盖原备份文件。
  5. 针对这个问题，修改 `createBackupDirectory()`，当目录已存在时自动追加 `-1`、`-2` 等后缀，同时把备份时间解析逻辑改为兼容带后缀的目录名，确保最新备份扫描仍然正确。
  6. 在 `AppModel` 中新增最近备份摘要、恢复确认状态和恢复动作方法，并把恢复入口接到 `MainWindowView`、`PresetEditorView` 和 `MenuBarContentView`，同时在恢复成功后刷新 live 配置、最近备份状态，并按现有逻辑提示是否重启目标应用。
  7. 运行 `swift test --filter restoreLatestBackupRestoresMostRecentBackupAndCreatesRollbackBackup`、`swift test --filter latestBackupSummaryReturnsNewestBackup`、`swift test` 和 `swift run CodexConfigSwitcher`，确认恢复功能、冲突修复和整体程序状态都通过验证。
- 原因：之前产品虽然已经会自动创建备份，但用户仍然需要手动打开备份目录自己寻找和恢复文件，无法形成“写错后快速回退”的闭环；同时恢复功能在实现中暴露出的目录命名冲突问题如果不修，会在高频连续操作时破坏备份可靠性，这是一个必须优先堵住的风险点。

## 2026-04-09 03:00:59 CST

- 类型：新功能
- 内容：新增预设复制、导入、导出能力，支持复制当前预设、从 JSON 文件导入预设，以及将当前选中预设导出为 JSON 文件。
- 思路：把导入导出的格式和兼容逻辑放在 Core 层做成独立服务，再通过主窗口侧边栏提供低成本入口。这样既能先满足单文件导入导出需求，也为后续扩展批量迁移、共享模板或兼容更多导出格式留出空间。
- 处理步骤：
  1. 在 `CodexConfigSwitcherCore` 中新增 `PresetTransferService.swift` 和 `PresetTransferPayload`，统一处理预设导出与导入，导入时兼容单个预设对象、预设数组以及带 `version/presets` 的导出 payload。
  2. 新增 `PresetTransferServiceTests.swift`，覆盖导出后回读、导入数组格式、导入单个对象格式，保证导入导出基础能力可测试。
  3. 扩展 `SystemPickerService`，增加保存文件选择器，供导出 JSON 文件时选择目标路径。
  4. 在 `AppModel` 中新增 `duplicateSelectedPreset()`、`importPresetsFromFile()`、`exportSelectedPreset()`，并补充导入重名预设时的自动改名逻辑，避免已有预设和同一批导入预设之间出现名称冲突。
  5. 在 `MainWindowView` 的预设侧边栏工具区新增“复制 / 导入 / 导出”入口，让预设管理能力集中在同一操作区，减少用户在不同区域来回寻找操作按钮。
  6. 新建并更新 `API说明.md`，把本轮以及最近新增的公共 API 统一补齐名称、参数、返回值、示例代码和测试代码说明。
  7. 运行 `swift test --filter PresetTransferServiceTests`、`swift test` 和 `swift run CodexConfigSwitcher`，确认导入导出能力、已有功能以及应用启动都通过验证。
- 原因：当前产品已经具备较强的本机预设编辑和切换能力，但预设仍局限在单机本地使用，缺少“复制一个变体”“迁移到另一台机器”“从别人给的配置文件快速导入”的能力，这会阻碍后续高频使用和团队共享场景的扩展。

## 2026-04-09 03:05:13 CST

- 类型：新功能 + BUG修复
- 内容：新增收藏与最近使用能力，支持收藏常用预设、记录最近使用预设，并在菜单栏优先展示；同时修复“最近备份排序在同秒目录下依赖秒级时间，可能导致恢复后最新备份识别不稳定”的问题。
- 思路：为了避免再次改动 `CodexPreset` 的持久化结构，这次把收藏和最近使用元数据挂在 `AppSettings` 上，由设置文件单独维护；菜单栏则基于这些元数据优先渲染常用预设。对备份排序问题，则统一改为优先读取文件系统创建时间，避免同秒目录排序不稳定。
- 处理步骤：
  1. 在 `AppSettings` 中新增 `favoritePresetIDs` 和 `recentPresetIDs`，并保持对旧版 `settings.json` 的向后兼容解码。
  2. 在 `AppModel` 中新增收藏切换、最近使用记录、收藏列表和最近使用列表等派生能力，并在应用预设和恢复备份成功后自动更新最近使用顺序。
  3. 更新 `PresetSidebarRow`、`MainWindowView` 和 `MenuBarContentView`，让主窗口支持收藏当前预设，菜单栏优先显示收藏和最近使用分组，同时在列表中显示收藏星标。
  4. 测试过程中发现恢复逻辑在“同一秒内创建多个备份目录”时，若只依赖目录名解析出的秒级时间，最近备份排序可能不稳定。
  5. 修改 `CodexFileService.backupSummary(for:)`，把最近备份时间改为优先使用文件系统真实创建时间，只有缺失时才回退到目录名解析时间，从而修复最近备份识别的不稳定问题。
  6. 运行 `swift test` 和 `swift run CodexConfigSwitcher`，确认收藏、最近使用、恢复排序修复以及整体启动流程都通过验证。
- 原因：当预设数量继续增加时，菜单栏如果仍然只显示完整列表，用户每次都要重新搜索常用项，高频切换效率会明显下降；同时最近备份排序问题虽然只在高频同秒操作时暴露，但会直接影响恢复功能的可信度，必须及时修正。

## 2026-04-09 03:22:44 CST

- 类型：新功能
- 内容：新增“测试连接”能力，支持对当前接口地址发起轻量探测，检查鉴权是否通过，并验证主模型是否出现在返回模型列表中。
- 思路：为了把风险和成本控制在较低范围内，这次没有直接调用真实生成接口，而是统一探测 `/models` 端点。这样既能验证 `base_url`、认证头和基础连通性，也能借助模型列表做一次轻量模型可用性检查；同时通过可注入的请求处理器，把这块能力做成可以单元测试的公共 API。
- 处理步骤：
  1. 在 `CodexConfigSwitcherCore` 中新增 `ConnectionTestService.swift`，定义 `ConnectionTestResult`、`ConnectionTestOutcome` 和 `testConnection(for:)`，统一处理地址生成、请求构建、状态码分类和模型列表解析。
  2. 测试连接默认会把 `base_url` 规范化为 `/models` 请求地址，并在 `auth_mode = apikey` 时自动附加 `Authorization: Bearer <API_KEY>` 头。
  3. 对返回结果做分层分类：`2xx` 且命中模型视为成功，`2xx` 但未命中模型视为警告，`401/403` 归类为鉴权失败，`404/405` 归类为接口路径异常，其余状态归类为连接失败。
  4. 新增 `ConnectionTestServiceTests.swift`，覆盖成功、模型未命中警告、鉴权失败和非法 URL 四类核心分支，确保测试连接逻辑在不依赖真实网络的情况下可验证。
  5. 在 `AppModel` 中新增测试连接运行状态和结果状态，并在 `PresetEditorView` 的操作区加入“测试连接”按钮及结果展示区域，让用户在正式应用前先验证配置可用性。
  6. 更新 `API说明.md`，补充 `ConnectionTestService.testConnection(for:)` 的名称、参数、返回值、示例代码和测试代码说明。
  7. 运行 `swift test --filter ConnectionTestServiceTests`、`swift test` 和 `swift run CodexConfigSwitcher`，确认连接测试能力、已有能力以及应用启动都通过验证。
- 原因：随着预设管理能力越来越完整，用户在应用预设前最担心的已经不只是“字段填没填对”，而是“这个接口到底能不能连通、鉴权是不是有效、主模型是不是可用”。如果每次都要先应用再去目标工具里试错，反馈链路会很慢，使用成本也会变高，因此需要一个更轻量的前置验证入口。

## 2026-04-09 03:43:14 CST

- 类型：新功能
- 内容：新增备份历史列表和指定备份恢复能力，支持查看最近多次备份并恢复任意一份，而不再局限于“恢复最近一次”。
- 思路：先把 Core 层的备份能力从“只知道最近一个”扩展为“可列出多个备份、可恢复指定备份”，再把这些数据接到状态区和菜单栏。这样既保留原来的一键恢复最近备份，也给用户一个更明确的回退选择，不需要自己去 Finder 里翻目录。
- 处理步骤：
  1. 在 `CodexFileService` 中新增 `listBackupSummaries(limit:)` 和 `restoreBackup(_:paths:)`，让备份查询和恢复目标从“固定最近一份”扩展为“任意备份摘要”。
  2. 保留 `latestBackupSummary()` 和 `restoreLatestBackup(paths:)`，但内部改为复用新的列表和指定恢复 API，避免重复逻辑。
  3. 在 `CodexFileServiceTests.swift` 中新增 `listBackupSummariesReturnsNewestFirst()` 和 `restoreBackupRestoresChosenSnapshot()`，验证备份列表排序和指定备份恢复的正确性。
  4. 在 `AppModel` 中新增 `recentBackups` 状态和 `requestRestoreBackup(_:)`，让界面可以展示最近 5 次备份并对任意一项发起恢复确认。
  5. 新增 `BackupHistoryRow` 组件，并把最近备份历史接到 `PresetEditorView` 和 `MenuBarContentView`，主窗口展示完整最近 5 条，菜单栏展示最近 3 条，兼顾信息量和操作效率。
  6. 更新 `README.md` 和 `API说明.md`，补充备份历史与指定恢复的功能描述以及新增 API 的名称、参数、返回值、示例代码和测试代码。
  7. 运行 `swift test` 和 `swift run CodexConfigSwitcher`，确认备份历史列表、指定恢复以及整体启动流程通过验证。
- 原因：虽然之前已经支持“恢复最近备份”，但用户一旦想回退到更早的一次稳定配置，仍然需要自己去备份目录里人工判断和恢复，这个过程既容易出错也不够高效，因此需要把备份历史显式展示出来并提供直接恢复入口。

## 2026-04-09 03:52:59 CST

- 类型：新功能
- 内容：新增主窗口侧边栏搜索和分组浏览能力，支持按关键字搜索预设，并按“收藏 / 最近使用 / 全部预设”分组展示结果。
- 思路：当前产品的菜单栏已经支持收藏和最近使用，但主窗口侧边栏仍然是单一长列表。为了解决预设数量增长后的定位效率问题，这次在不改变数据模型结构的前提下，直接在主窗口侧边栏做本地搜索和去重分组，让用户能更快找到常用项和搜索结果。
- 处理步骤：
  1. 在 `MainWindowView` 中新增本地 `searchText` 状态，并基于预设名称、接口地址、主模型、评审模型做关键字匹配。
  2. 把侧边栏列表重构为 `filteredSections`，按收藏、最近使用、全部预设生成分组，并通过去重逻辑避免同一个预设在多个分组里重复出现。
  3. 使用 `.searchable(...)` 给侧边栏列表增加搜索入口，并在无匹配结果时显示兼容 macOS 13 的空状态提示。
  4. 在这个过程中遇到两个实现层问题：
     1. `MainWindowView` 的侧边栏表达式过大，触发 SwiftUI 编译器 type-check 超时，于是将侧边栏拆分为 `sidebarContent`、`presetList` 和 `presetRow` 多个更小的视图片段。
     2. 原本打算使用 `ContentUnavailableView` 展示空结果，但项目最低支持版本是 macOS 13，而该组件需要 macOS 14，因此改成自定义的兼容空状态布局。
  5. 运行 `swift test` 和 `swift run CodexConfigSwitcher`，确认搜索与分组能力、已有功能以及应用启动都通过验证。
- 原因：随着收藏、最近使用、导入导出等能力逐步加入，预设数量会持续增长，如果主窗口仍然保持单一长列表，用户在管理和搜索目标预设时会越来越低效，因此需要把“搜索”和“分组浏览”补到主窗口这个高频管理入口上。

## 2026-04-09 04:02:58 CST

- 类型：新功能
- 内容：增强导入失败提示和格式校验，能够明确区分“不是合法 JSON”“导入列表为空”“结构解析失败”“某个预设字段不合法”等导入错误场景。
- 思路：导入错误不能只停留在“格式无效”，否则用户拿到别人给的 JSON 文件时很难定位问题。因此这次先在 Core 层把导入链路拆成“JSON 合法性判断 -> 顶层结构判断 -> 预设字段校验”三层，再把错误文案传到 App 层统一前缀成“导入失败：...”，让提示更直接可读。
- 处理步骤：
  1. 重构 `PresetTransferService.importPresets(from:)`，先用 `JSONSerialization` 判断顶层结构，再分别处理 payload、数组、单对象三种导入格式，而不是直接连续 `try? decode`。
  2. 为不同失败场景补充更细的中文错误文案，包括非法 JSON、空预设数组、payload 中 `presets` 无法解析、数组或单对象字段类型不正确等。
  3. 在成功解析出预设后，逐条调用 `PresetValidator.validate(_:)`，一旦发现不合法字段，就抛出包含“第几个预设”“预设名称”“具体字段问题”的错误提示。
  4. 在 `PresetTransferServiceTests.swift` 中新增非法 JSON、空数组、字段不合法预设三类测试，确保错误分类和错误文案稳定可验证。
  5. 在 `AppModel.importPresetsFromFile()` 中把导入失败提示统一包装成 `导入失败：...`，让界面上的错误提示更贴近用户操作语境。
  6. 更新 `README.md` 和 `API说明.md`，补充导入错误校验行为和示例说明。
  7. 运行 `swift test --filter PresetTransferServiceTests`、`swift test` 和 `swift run CodexConfigSwitcher`，确认导入增强、已有能力以及启动流程都通过验证。
- 原因：随着导入导出功能加入，用户越来越可能直接使用外部 JSON 文件创建预设。如果错误提示仍然过于笼统，用户往往不知道问题到底是文件损坏、格式不兼容，还是某个字段缺失或写错，因此需要把导入错误做得更细、更可定位。

## 2026-04-09 04:11:02 CST

- 类型：新功能
- 内容：新增“导出全部预设”能力，支持一键将当前所有预设导出为同一个 JSON 文件，方便整套配置备份和跨机器迁移。
- 思路：当前底层导出服务本身已经支持导出预设数组，所以这次不再新增新格式或新 API，而是直接在现有导出链路上增加“导出全部预设”的应用层入口，尽量用最小改动补上最常见的整库迁移需求。
- 处理步骤：
  1. 在 `AppModel` 中新增 `canExportAllPresets` 和 `exportAllPresets()`，复用现有 `PresetTransferService.exportPresets(_:)` 导出全部预设数组。
  2. 为整库导出生成默认文件名 `codex-presets-YYYYMMDD-HHmmss.json`，便于用户在 Finder 中区分不同时间导出的整套预设文件。
  3. 在 `MainWindowView` 的侧边栏操作区新增“导出全部”按钮，并在没有预设时禁用该操作，避免无效导出。
  4. 运行 `swift test` 和 `swift run CodexConfigSwitcher`，确认导出全部预设能力、现有导出逻辑以及整体启动流程都通过验证。
- 原因：虽然之前已经支持导出单个预设，但用户在做整机迁移、版本备份或给他人打包一整套环境时，往往需要一次性导出所有预设。如果仍然只能一个一个导出，操作成本会明显偏高，因此需要补上整套导出的快捷入口。

## 2026-04-09 13:14:53 CST

- 类型：新功能
- 内容：新增“导出收藏预设”能力，支持一键把当前所有收藏预设导出为同一个 JSON 文件，方便同步常用环境集合。
- 思路：既然当前产品已经有“收藏预设”这一层语义，那么导出能力也应该覆盖这个常见子集场景。实现上继续复用现有的预设数组导出格式，只在 App 层增加“导出收藏预设”的粒度选择，避免引入新的文件格式和兼容成本。
- 处理步骤：
  1. 在 `AppModel` 中新增 `canExportFavoritePresets` 和 `exportFavoritePresets()`，直接复用 `favoritePresets` 和现有 `PresetTransferService.exportPresets(_:)` 导出收藏列表。
  2. 为收藏导出生成默认文件名 `codex-favorite-presets-YYYYMMDD-HHmmss.json`，方便用户区分单个预设、全部预设和收藏预设三种导出文件。
  3. 在 `MainWindowView` 的侧边栏操作区新增“导出收藏”按钮，并在没有收藏预设时禁用该操作，避免无效点击。
  4. 运行 `swift test` 和 `swift run CodexConfigSwitcher`，确认导出收藏预设能力、已有导出能力以及整体启动流程都通过验证。
- 原因：全部预设导出适合整库迁移，但很多时候用户只想同步最常用的一组环境。如果只能导出全部预设，目标文件里会混入很多临时或低频配置，因此需要一个介于“导出单个”和“导出全部”之间的导出粒度。

## 2026-04-09 01:50:00 CST

- 类型：BUG 修复
- 内容：清理仓库中的个人环境信息和容易触发误报的示例敏感字段，避免公开仓库继续暴露本机用户名路径和私有默认服务地址。
- 思路：只清理仓库内的默认值、占位文案和测试样例，不触碰本机真实的 `~/.codex/config.toml`、`~/.codex/auth.json` 文件，也不删除用户本地已存在的配置。
- 处理步骤：
  1. 扫描已提交文件，定位 `README.md`、`Models.swift`、`PresetEditorView.swift` 和测试中出现的个人 Home 目录路径、仓库绝对路径、私有默认服务地址，以及容易被误报为真实密钥的测试占位值。
  2. 将 `AppPaths.default` 改为基于当前用户 Home 目录动态拼接 `~/.codex/config.toml` 和 `~/.codex/auth.json`，避免把个人用户名写死在仓库里。
  3. 将默认 `base_url` 和 UI 占位改为公开通用的 `https://api.openai.com/v1`，移除仓库中的私有默认服务地址。
  4. 将 README 中的本机绝对路径改为通用写法，把测试里的 `sk-` 风格占位值替换为普通示例字符串，并补充测试覆盖动态默认路径。
- 原因：上一次首发提交虽然没有真实密钥，但带上了个人用户名路径、本地仓库绝对路径、私有默认服务地址，以及容易被误判为真实密钥的测试占位值，不利于公开仓库维护和分享。

## 2026-04-09 16:24:14 CST

- 类型：新功能
- 内容：导入功能新增“模式选择”，支持两种导入方式：`追加导入（同名自动重命名）` 与 `导入并覆盖同名`。
- 思路：把导入决策前置到用户入口层，避免沿用单一导入策略。对“保守合并”和“快速同步”两类场景分别提供明确动作，减少导入后手工整理成本。
- 处理步骤：
  1. 在 `AppModel` 中新增导入模式枚举，并拆分导入入口为 `importPresetsByAppending()` 与 `importPresetsByReplacingSameName()`。
  2. 调整导入主流程 `importPresetsFromFile(mode:)`，统一读取 JSON 后按模式分发到不同的合并策略。
  3. 追加模式下，对导入预设统一分配新 ID，并在名称冲突时自动改名（`名称 2 / 名称 3 ...`），保证不会覆盖现有预设。
  4. 覆盖模式下，按预设名称匹配已有项；命中时保留原 ID 进行原位替换，未命中时新增预设，实现“同名更新、不同名新增”。
  5. 在 `MainWindowView` 把原单按钮导入改为菜单式入口，明确展示两种导入模式，减少误触和行为歧义。
  6. 更新 `README.md` 与 `API说明.md`，补充导入模式说明及对应 API 使用示例。
  7. 运行 `swift test` 验证回归，确认导入模式改造未破坏已有核心能力。
- 原因：原先导入流程只有一种策略，用户在“保留现有预设并并入新数据”和“用导入内容覆盖同名项”之间无法选择，容易出现导入后名称冲突或批量同步效率低的问题。

## 2026-04-09 16:57:54 CST

- 类型：新功能
- 内容：新增“基础模式 / 高级模式”编辑切换，默认使用基础模式，切换后会保留当前草稿并记住用户上次使用的模式。
- 思路：继续按产品计划把编辑体验从“字段很多但都堆在一起”推进到“普通用户先处理高频字段，高阶用户再进入完整控制”。实现上优先复用现有“基础配置 + 高级配置”结构，不改预设文件格式，只新增一个轻量的编辑器模式状态并持久化到设置文件。
- 处理步骤：
  1. 在 `CodexConfigSwitcherCore` 中新增 `PresetEditorMode` 枚举，并把 `presetEditorMode` 挂到 `AppSettings` 上，同时保持旧版 `settings.json` 缺少该字段时默认回落到 `.basic`。
  2. 在 `AppModel` 中新增 `presetEditorMode` 状态、`isAdvancedEditorMode` 派生属性和 `setPresetEditorMode(_:)` 方法，用于统一切换模式并持久化到设置文件。
  3. 重构 `PresetEditorView` 顶部说明区，增加分段选择器，让用户可以显式切换“基础模式 / 高级模式”。
  4. 在基础模式下，仅展示高频字段和工作流相关区域，并用提示卡说明可切换到高级模式继续编辑低频字段。
  5. 在高级模式下，完整展示原有高级字段区，包括 Provider、推理强度、网络访问、上下文窗口等字段；模式切换过程中不重建草稿，因此不会丢失已输入内容。
  6. 在测试中新增 `settingsStorePersistsPresetEditorMode()`，并补充旧设置默认回退到基础模式的断言，确保新字段持久化和向后兼容都稳定。
  7. 更新 `README.md` 与 `API说明.md`，补充模式切换能力说明和新增 API 文档。
- 原因：虽然当前版本已经把高频字段和低频字段分层了，但它仍然更像“带折叠区的完整表单”，还不是面向不同用户层级的真正双模式视图。继续补齐这一层后，普通用户会更容易聚焦主流程，高阶用户也仍然能进入完整配置。

## 2026-04-09 17:43:57 CST

- 类型：新功能
- 内容：新增环境标签与颜色体系，支持为预设标记 `官方 / 代理 / 测试 / 备用`，并在高风险环境应用前增加二次确认。
- 思路：这次把环境标签明确定位为“预设元数据”，用于帮助用户识别和管理环境，而不是写入 live 配置文件的受管字段。这样既能在界面上建立更强的环境辨识能力，又不会影响现有的配置写入逻辑、差异预览逻辑和受管字段指纹。
- 处理步骤：
  1. 在 `CodexConfigSwitcherCore` 中新增 `PresetEnvironmentTag`，定义 `官方 / 代理 / 测试 / 备用` 四种标签，并补充 `title`、`isHighRisk` 与基于 `base_url` 的推断规则。
  2. 扩展 `CodexPreset`，新增 `environmentTag` 字段；同时为 `CodexPreset` 补自定义解码逻辑，让旧版 `presets.json` 或旧导入文件缺少该字段时，仍能根据接口地址自动推断标签，避免升级后历史预设全部失去分类。
  3. 在 `CodexFileService.loadSnapshot` 中为 live 配置读取结果补上环境推断，这样当前 live 摘要区在没有匹配到已保存预设时，也能给出一个基础环境标签。
  4. 在 `PresetEditorView` 的基础配置区新增环境标签选择器，并在选择高风险标签时给出前置提示。
  5. 新增 `PresetEnvironmentBadge` 组件，并把它接入主窗口侧边栏、顶部状态摘要卡片和菜单栏预设项，让环境标签在所有高频入口都有一致颜色和视觉表达。
  6. 在 `AppModel` 中新增高风险环境待确认状态，把“应用草稿”和“菜单栏快速切换”统一接到同一套高风险确认逻辑上，当前先将 `代理` 视为高风险标签。
  7. 在 `MainWindowView` 与 `MenuBarContentView` 中新增高风险环境确认弹窗，避免用户把带代理标签的预设一键直接切过去却没有任何提醒。
  8. 在测试中补充三类验证：导入导出时环境标签可回读、旧预设文件缺少环境标签也能正常加载、从 `localhost` 等 live 地址读取时会自动识别为 `测试` 环境。
  9. 更新 `README.md` 与 `API说明.md`，补充环境标签能力和新增 API 说明。
- 原因：当前产品虽然已经能看到接口地址、模型和当前状态，但在预设数量继续增加后，用户仍然需要自己“读地址猜环境”，这会提高切错环境的概率。尤其菜单栏快速切换场景下，如果缺少环境标签和高风险提醒，误切代理或非默认服务的成本会更高。

## 2026-04-09 18:40:53 CST

- 类型：新功能
- 内容：新增预设环境标签筛选、最近使用优先排序和操作历史能力，帮助用户在多预设场景下更快定位目标环境，并追溯最近做过哪些切换或恢复操作。
- 思路：这轮继续沿用“轻量元数据放 `settings.json`、不污染 `presets.json` 和 live 配置”的策略。筛选、搜索和排序统一收口到 `AppModel` 的派生查询层，避免主窗口各分组各自维护一套规则；最近使用排序则优先读取成功操作历史的时间戳，在升级后历史为空时回退到已有 `recentPresetIDs`，兼顾新能力和旧数据平滑过渡。操作历史本身记录预设名称快照、环境标签、结果和说明，避免后续预设改名后历史不可读。
- 处理步骤：
  1. 在 `CodexConfigSwitcherCore` 中新增 `PresetOperationKind`、`PresetOperationOutcome` 和 `PresetOperationHistoryEntry`，并把 `operationHistory` 挂到 `AppSettings` 上，同时保持旧版 `settings.json` 缺少该字段时默认解码为空数组。
  2. 在 `AppModel` 中新增 `operationHistory` 状态与记录方法，把“应用预设成功 / 失败”“恢复备份成功 / 失败”以及“应用前校验失败”统一写入历史，并限制最多保留最近 20 条记录。
  3. 在 `AppModel` 中新增统一的预设派生查询能力，把关键字搜索、环境标签筛选和排序逻辑集中处理；最近使用排序优先按成功操作历史时间倒序，没有历史时再回退到 `recentPresetIDs` 顺序。
  4. 在 `MainWindowView` 的侧边栏顶部新增“环境筛选”和“排序方式”菜单，让收藏 / 最近使用 / 全部预设三个分组都共享同一套过滤与排序结果。
  5. 新增 `PresetOperationHistoryRow` 组件，并在 `PresetEditorView` 的“状态与备份”区域展示最近操作历史，直接显示目标预设、环境标签、成功/失败结果、时间和简短说明。
  6. 在测试中补充 `settingsStorePersistsOperationHistory()`，并扩展旧版设置兼容断言，确保历史记录持久化和向后兼容都稳定。
  7. 更新 `README.md`、`API说明.md`、`docs/plans/2026-04-09-product-ux-optimization-todo.md`、`task_plan.md`、`findings.md` 和 `progress.md`，同步记录这轮范围、设计决策和完成状态。
  8. 运行 `swift test`，确认本轮新增能力与既有功能一起回归通过；当前 34 个测试全部通过。
- 原因：随着收藏、最近使用、环境标签、导入导出和备份恢复能力逐步补齐，预设规模和操作路径都在变复杂。如果仍然只能靠名字搜索、手工翻列表和记忆上一次做过什么，用户会越来越难快速定位环境，也不容易排查“为什么现在是这个配置”。因此需要把筛选、排序和操作历史一起补齐，形成更完整的管理闭环。

## 2026-04-09 19:25:50 CST

- 类型：新功能
- 内容：新增应用内快捷键，支持用 `⌘⇧O` 打开主窗口、`⌘↩` 应用当前草稿/预设、`⌘R` 重新读取当前配置。
- 思路：这轮先落最轻的应用内快捷键闭环，不直接进入全局热键。实现上把快捷键挂到 SwiftUI `Commands` 菜单中，直接复用现有 `AppModel` 动作，保证键盘入口和主窗口按钮入口保持同一套应用、校验和读取逻辑，避免后续维护两份行为。

- 处理步骤：
  1. 在 `CodexConfigSwitcherApp` 中新增 `快捷操作` 命令菜单，为主窗口打开、当前草稿/预设应用和 live 配置重读提供统一的键盘入口。
  2. 将“打开主窗口”快捷键接到现有 `openWindow(id: "main")` 链路，并在触发前激活应用，保证行为和菜单栏中的“打开主窗口”一致。
  3. 将“立即应用”快捷键直接复用 `AppModel.applyDraft()`，让快捷键入口继续走现有的校验、高风险确认和应用流程；当草稿有未保存修改时，它应用的是当前草稿，而不是忽略编辑区状态。
  4. 将“重新读取当前配置”快捷键直接复用 `AppModel.reloadLiveConfiguration()`，避免额外增加一套状态刷新逻辑。
  5. 更新 `README.md`、`docs/plans/2026-04-09-product-ux-optimization-todo.md`、`task_plan.md`、`findings.md` 和 `progress.md`，同步记录快捷键约定和本轮实现决策。
  6. 运行 `swift test` 做回归验证，确认快捷键接线没有破坏现有编译和测试链路。
- 原因：当前主窗口和菜单栏的切换主链路已经比较完整，但高频用户仍然需要频繁用鼠标点“打开主窗口 / 应用 / 重新读取”这类固定动作。先补应用内快捷键，可以在不引入全局热键复杂度的前提下，立刻提升日常操作效率。

## 2026-04-09 21:13:03 CST

- 类型：新功能
- 内容：新增本地模板库 v1，支持将当前草稿保存为模板，并从模板快速创建新预设；模板默认不保存 `API Key` 等敏感认证字段。
- 思路：把模板明确定位为“非敏感的配置骨架”，与可直接应用的预设分开存放。实现上采用单独的 `templates.json` 持久化和白名单字段复制策略，只保留环境标签、接口地址、模型、认证模式和常用高级配置；`apiKey` 这类敏感字段不进入模板文件。UI 上把“保存为模板”放在编辑器头部，把“从模板新建”放在主窗口侧边栏操作区，尽量复用现有 `AppModel` 草稿/预设流，减少额外交互成本。
- 处理步骤：
  1. 在 `CodexConfigSwitcherCore` 中新增 `ApplicationSupportPaths.templatesFileURL()`、`CodexTemplate` 和 `TemplateStore`，为本地模板提供独立模型与存储入口。
  2. 在 `CodexTemplate` 中新增 `init(preset:name:)` 和 `makePreset(name:)`，通过显式白名单在 `预设 -> 模板 -> 预设` 之间转换，确保模板不携带 `apiKey`，且从模板创建的新预设始终生成新的 `UUID`。
  3. 在 `AppModel` 中新增 `templates` 状态、模板加载/保存逻辑、`saveDraftAsTemplate()` 和 `createPresetFromTemplate(id:)`，并把模板加载改为独立容错，避免 `templates.json` 异常拖垮预设主流程启动。
  4. 在 `PresetEditorView` 头部新增“保存为模板”按钮和说明文案，明确提示模板不会保存敏感字段。
  5. 在 `MainWindowView` 侧边栏操作区新增“从模板新建”菜单，支持直接从已有模板创建并选中新预设。
  6. 在 `CodexFileServiceTests.swift` 中新增模板路径、模板持久化 round-trip、不保存 `apiKey`、从模板创建预设时重新生成 ID 等测试，锁定关键边界。
  7. 更新 `README.md`、`API说明.md`、`docs/plans/2026-04-09-product-ux-optimization-todo.md`、`task_plan.md`、`findings.md` 和 `progress.md`，同步本轮设计与实现结果。
  8. 运行 `swift test`，确认回归通过；当前 38 个测试全部通过。
- 原因：随着预设数量增加，用户经常需要复用“结构相近但密钥不同”的配置。如果只能复制现有预设，就容易把旧环境的 `API Key` 或认证信息一并带到新环境中，也不利于沉淀一套长期复用的配置模板。因此需要把模板单独抽出来，既保留复用效率，又把敏感字段隔离在模板之外。

## 2026-04-10 00:11:35 CST

- 类型：新功能
- 内容：完善本地模板管理闭环，新增模板工作台和快速新建弹出入口，支持模板搜索、载入草稿、覆盖模板、重命名和删除。
- 思路：既然这是个人使用场景，模板功能不需要往“团队共享”扩，而应该先把本地模板做成一个完整、低心智负担的工作流。因此这轮把模板区从“两个零散按钮”升级成真正的工作台：编辑器顶部集中展示模板列表、预览信息和管理动作，主窗口侧边栏则提供轻量的弹出式“从模板快速新建”入口。视觉上以 `Notion` 式温和浅色面板和低对比边界做主参考，再借一点 `Vercel` 式技术标签与更利落的细边框，让它在现有界面里既有存在感又不过度跳脱。
- 处理步骤：
  1. 在 `AppModel` 中新增模板管理动作：`loadTemplateIntoDraft(id:)`、`overwriteTemplate(id:)`、`renameTemplate(id:to:)` 和 `deleteTemplate(id:)`，并补充可注入初始化器，便于直接做工作流测试。
  2. 约定“载入模板到草稿”只更新当前草稿的模板白名单字段，保留当前草稿的 `id` 和名称，不会直接改写当前已选预设；同时继续清空 `apiKey`，避免把旧认证值悄悄带过去。
  3. 在 `PresetEditorView` 中新增 `TemplateWorkbenchPanel`，提供模板搜索、列表选择、元数据预览、载入草稿、从模板创建新预设、覆盖模板、重命名和删除等完整操作。
  4. 在 `MainWindowView` 中把原先的“从模板新建”菜单升级为 `TemplateQuickCreatePopover` 弹出面板，让用户在生成新预设前先看到模板的环境标签、接口地址和模型摘要。
  5. 新增 `CodexConfigSwitcherAppTests` 测试目标，并补充三类工作流测试：模板载入不污染已存预设、覆盖模板仍不保存 `apiKey`、模板重命名和删除后会正确持久化。
  6. 更新 `README.md`、`API说明.md`、`docs/plans/2026-04-09-product-ux-optimization-todo.md`、`task_plan.md`、`findings.md` 和 `progress.md`，同步模板管理闭环的设计与实现结果。
  7. 运行 `swift test` 做完整回归验证，当前 41 个测试全部通过。
- 原因：模板 v1 解决了“能不能存”和“能不能生成”的问题，但还没有解决“模板多了以后怎么找、怎么改、怎么放心复用”的问题。对于个人用户来说，这一层管理闭环比团队同步更迫切，否则模板数量一增长，很快又会退回到“知道有模板，但懒得用”的状态。

## 2026-04-10 01:14:21 CST

- 类型：新功能
- 内容：继续完善 macOS 版本的默认配置管理，并同步启动 Windows 首期 CLI 版本。新增平台感知默认路径 / 默认目标应用、macOS 设置页“恢复默认”入口，以及 `CodexConfigSwitcherCLI` 命令行工作流。
- 思路：现有桌面端基于 `AppKit + SwiftUI`，不能直接平移到 Windows；如果强行先做 GUI，只会把时间耗在平台壳层，而不是预设、模板和配置写入这些真正核心能力上。所以这轮先把平台差异下沉到 core 默认值层，让 macOS 和 Windows 共享同一套预设 / 模板 / 设置存储协议，再用 CLI 作为 Windows 第一阶段入口。macOS 侧则顺手把“恢复默认路径 / 恢复默认目标 App”补齐，避免用户修改过低频设置后只能手工回填。
- 处理步骤：
  1. 新增平台默认值抽象，按运行平台统一计算 `AppPaths.default`、`ManagedAppTarget.codex` 和 `ApplicationSupportPaths.rootDirectory()`，让默认配置目录、应用支持目录和目标应用路径不再只假设 macOS。
  2. 为 Windows 默认值补齐约定：配置文件目录采用 `%USERPROFILE%\\.codex`，应用数据目录采用 `%APPDATA%\\CodexConfigSwitcher`，默认目标应用先按 `%LOCALAPPDATA%\\Programs\\Codex\\Codex.exe` 推断。
  3. 在 macOS 设置页新增“恢复默认路径”和“恢复默认目标 App”，并补充默认值说明文案，让跨平台默认值抽象也能直接反馈到桌面版可用性上。
  4. 调整 `Package.swift`，新增 `CodexConfigSwitcherCLI` 可执行目标，同时保持 macOS 桌面版 target 只在 `macOS` 下参与构建。
  5. 新增 CLI 命令：`status`、`list-presets`、`apply --preset`、`capture-live --name`、`save-template --preset`、`create-from-template --template`，让 Windows 端先具备状态查看、预设应用、模板沉淀和模板派生能力。
  6. 新增 `PlatformDefaultsTests`，覆盖 Windows 默认路径、应用支持目录和默认目标应用推断；随后执行 `swift test`，当前 44 个测试全部通过。
  7. 额外执行 `swift build --product CodexConfigSwitcherCLI` 和 `swift run CodexConfigSwitcherCLI help`，确认新 CLI 能正常构建并输出用法。
  8. 更新 `README.md`、`API说明.md`、`task_plan.md`、`findings.md` 和 `progress.md`，同步记录这轮跨平台推进的范围与接口。
- 原因：现有项目的默认路径、应用支持目录和目标应用配置都默认只考虑 macOS，这会直接阻塞 Windows 版本起步；同时 macOS 用户一旦修改过路径或目标应用，也缺少“一键回到默认值”的回退入口。这轮把两件事一起补齐，既推进了跨平台，也继续完善了 macOS 桌面版的收尾体验。

## 2026-04-10 01:43:08 CST

- 类型：新功能
- 内容：补齐 Windows CLI 的目标应用管理闭环，新增目标应用状态探测、路径配置、恢复默认、手动重启，以及 `apply --restart`。
- 思路：Windows 首期已经能通过 CLI 管理预设和模板，但“配置写进去了，Codex.exe 什么时候吃到新配置”还缺最后一环。如果没有目标应用管理，用户切完配置仍然要手动找进程、手动重启，CLI 价值会被打折。所以这轮先不做 GUI，而是在 core 增加一层跨平台运行时服务，把目标应用状态探测和进程重启能力沉到可复用层；CLI 再在此基础上暴露出 `target` 子命令和 `apply --restart`。Windows 分支优先用 PowerShell 驱动进程查询和启动，兼顾首期落地速度和自定义 `Codex.exe` 路径支持。
- 处理步骤：
  1. 在 `CodexConfigSwitcherCore` 中新增 `ManagedAppRuntimeService` 和 `ManagedAppAvailability`，统一处理目标应用路径展开、存在性检查、运行态探测与重启。
  2. 为 Windows 分支实现 PowerShell 命令方案：通过 `Get-Process` 判断运行态，通过 `Stop-Process` 结束旧进程，通过 `Start-Process` 启动新的 `Codex.exe`。
  3. 在服务里补齐路径展开逻辑，支持 Windows `%VAR%` 风格环境变量路径，同时兼容 macOS / Linux 的 `~` 路径展开。
  4. 扩展 `CodexConfigSwitcherCLI` 命令面，新增 `target status`、`target set-path --path`、`target reset`、`target restart` 四个子命令。
  5. 为 `apply --preset` 增加可选 `--restart` 标记，让“写配置”和“让新配置生效”可以在一个命令里完成。
  6. 新增 `ManagedAppRuntimeServiceTests`，覆盖三类边界：路径缺失时直接返回 `missing`、Windows 运行态识别、Windows 重启时按“探测 -> 结束 -> 启动”顺序发命令。
  7. 运行 `swift test` 做完整回归，当前 47 个测试全部通过。
  8. 额外执行 `swift build --product CodexConfigSwitcherCLI`、`swift run CodexConfigSwitcherCLI help` 和 `swift run CodexConfigSwitcherCLI target status`，确认新命令可构建、可显示帮助并可读取目标应用状态。
- 原因：Windows 首期 CLI 之前只解决了“如何保存和应用配置”，没有解决“如何让目标应用立刻吃到新配置”。补上目标应用管理后，CLI 才真正形成从预设管理到配置生效的完整链路，也为后续 Windows GUI 直接复用这套运行时服务打下基础。

## 2026-04-10 03:31:14 CST

- 类型：新功能
- 内容：启动 Windows WinUI 3 原生 GUI 版本，新增 WinUI 3 工程骨架、CLI JSON 桥和首屏工作台；同时修复 `status --json` 初版会暴露 live `apiKey` 的桥接层安全问题。
- 思路：WinUI 3 版本如果一开始就重写 Swift core，会把大量时间耗在配置写入和 TOML 保留逻辑的重复实现上，风险高且进度慢。因此这轮选择“两层桥接”方案：Windows GUI 直接读取 `%APPDATA%\\CodexConfigSwitcher\\presets.json` 和 `settings.json` 这类轻量本地状态，而 live 配置读取、应用预设和目标应用控制继续交给 `CodexConfigSwitcherCLI`。为了让 GUI 可以稳定消费 CLI 输出，又新增了 `status --json` 和 `target status --json`。在真实命令验证时又发现 `status --json` 把 live `apiKey` 一并返回了，这不符合 GUI 桥的最小暴露原则，于是立即补做脱敏修复，确保桥接层默认不带出敏感认证值。
- 处理步骤：
  1. 新增 WinUI 3 设计文档 `docs/plans/2026-04-10-winui3-windows-bootstrap-design.md`，明确首期只做“预设列表 + 当前 live 摘要 + 目标应用控制 + 一键应用/重启”。
  2. 在 `CodexConfigSwitcherCLI` 中新增 `status --json` 和 `target status --json`，让 Windows GUI 可以直接消费结构化状态，而不是解析面向人类的文本。
  3. 新增 `windows/CodexConfigSwitcher.Windows.sln` 和 `windows/CodexConfigSwitcher.WinUI/`，搭建 WinUI 3 解决方案、项目文件、`App.xaml`、`MainWindow.xaml`、包清单和资源目录。
  4. 在 Windows GUI 中新增本地仓储 `LocalStateRepository`、路径服务 `WindowsStoragePaths`、CLI 桥接服务 `CliBridgeService` 和 `MainWindowViewModel`，打通首屏预设列表、当前状态、应用预设、应用并重启、目标路径设置、恢复默认目标、重启目标应用这些主链路。
  5. 复用现有品牌 PNG 到 WinUI 3 `Assets/` 目录，先填满打包清单要求的资源位，避免工程文件指向空资源。
  6. 在手工审查 WinUI 3 代码时，修复了两个首轮结构问题：`Window` 不能直接承载 `DataContext`，因此将绑定上下文改挂到根 `Grid`；`MainWindowViewModel` 中操作后的刷新原本会被 `IsBusy` 自己拦住，因此改成独立的内部刷新流程。
  7. 在真实执行 `swift run CodexConfigSwitcherCLI status --json` 验证时，定位到 live `apiKey` 被一并输出的问题；随后把 JSON 输出里的 `livePreset` 改为脱敏版本，仅保留 GUI 所需配置骨架。
  8. 运行 `swift test` 做回归验证，当前 47 个测试全部通过；同时额外执行 `swift run CodexConfigSwitcherCLI status --json` 和 `swift run CodexConfigSwitcherCLI target status --json`，确认 WinUI 3 要消费的 JSON 桥已经可用。
  9. 更新 `README.md`、`windows/README.md`、`API说明.md`、`task_plan.md`、`findings.md` 和 `progress.md`，同步记录 WinUI 3 方案、CLI JSON 桥和当前环境限制。
- 原因：Windows 版本已经有 CLI，但还没有原生 GUI，导致普通用户仍然只能在命令行里完成主要流程。同时，如果没有结构化 CLI 桥，WinUI 3 GUI 很难稳定复用现有 Swift 能力，只能走脆弱的文本解析或重复实现核心逻辑。这轮先把桥接协议和 GUI 骨架搭起来，能显著降低后续 Windows 端继续开发的阻力；而对 `status --json` 的敏感字段脱敏修复，则是避免桥接层在扩展过程中扩大安全暴露面。

## 2026-04-13 00:54:15 CST

- 类型：新功能 + BUG修复
- 内容：完成一轮 macOS 主工作区优化，新增“未保存草稿切换保护”、菜单栏快速切换保留当前草稿、主窗口独立“预设编辑 / 模板工作台”双工作区，以及更清晰的顶部状态摘要和快捷动作区。
- 思路：这次没有继续往单页里堆功能，而是先收窄到两个最影响体验的核心问题：一是切换预设或菜单栏快速切换时，当前草稿可能被静默覆盖；二是主窗口把状态、快捷动作、模板管理、编辑表单全都挤在同一视线流里，用户很难快速建立“先看状态、再做动作、最后编辑”的节奏。因此本轮先修状态流，再做信息架构减负。
- 处理步骤：
  1. 审查 `MainWindowView`、`PresetEditorView`、`MenuBarContentView` 和 `AppModel` 后，确认当前主要摩擦点不是单个控件样式，而是“切换预设直接覆盖草稿”和“模板工作台长期占据主编辑流”的结构性问题。
  2. 在 `AppModel` 中新增待切换预设确认流，扩展 `selectPreset(id:)`：当当前草稿存在未保存修改时，不再立即覆盖，而是进入 `presetPendingSelection` 状态，并提供“保存当前修改后切换 / 放弃修改后切换 / 取消”三种后续动作。
  3. 调整菜单栏快速切换逻辑：当主窗口存在未保存草稿时，菜单栏直接应用目标预设，但不再强行改写当前选中预设和草稿，从而避免菜单栏高频切换打断主窗口中的编辑上下文。
  4. 重构主窗口详情区，把顶部改成“状态总览卡 + 快捷动作面板”的双栏结构，并新增“预设编辑 / 模板工作台”分段工作区，让模板管理从默认编辑流里抽离出去，减少首屏拥挤感。
  5. 重排 `PresetEditorView` 顶部，把原先一整排动作按钮拆成更明确的两层操作区，同时保留模板保存入口，但把完整模板管理引导到独立工作区。
  6. 优化菜单栏窗口，新增搜索框并按“收藏 / 最近使用 / 全部预设（或搜索结果）”分组展示，降低预设数量增多后的定位成本。
  7. 为新的状态流补充 `AppModelTemplateWorkflowTests` 回归测试，覆盖“未保存草稿切换需要确认”“保存后再切换会先持久化当前预设”“菜单栏切换不会丢失当前草稿”三条关键路径。
  8. 更新 `API说明.md`，补充新的预设切换确认流 API 说明，并执行 `swift build` 与 `swift test`，确认本轮改造通过编译和 50 项测试回归。
- 原因：旧版 macOS 主窗口虽然功能越来越完整，但交互上仍然存在一个高风险缺陷：用户编辑到一半切换预设时，草稿会被新预设直接覆盖，且菜单栏快速切换也会打断当前编辑上下文；与此同时，模板工作台与主编辑表单长期并排堆叠，使首屏视觉层级混乱、操作路径发散，最终导致“能做很多事，但每次都不够顺手”的体验问题。

## 2026-04-13 22:10:41 CST

- 类型：新功能
- 内容：继续推进 macOS 主工作区优化，新增主窗口 persistent context banner，用来持续提示“当前生效配置”和“当前编辑草稿”已经脱节；同时收口侧边栏低频导入导出操作到“管理”菜单，并把状态摘要中的“当前选中”明确改成“当前编辑”。
- 思路：上一轮已经修掉了“切换预设会直接覆盖草稿”的高风险问题，但在菜单栏快速切换后，主窗口仍然缺少一个持续可见的解释层。用户虽然不会丢数据，却仍然容易搞不清“现在真正生效的是哪个配置”和“我正在编辑的是哪个预设”。所以这轮不做大改版，只补一条持续存在、带明确动作的 context banner，再顺手把侧边栏里最挤的低频管理操作收口，进一步突出主流程。
- 处理步骤：
  1. 按 `artifact-gated-agents` 跑了一轮最小多 agent 关卡，先产出 PRD、DesignSpec、SystemArch、TaskBreakdown、Approval 和 ImplementationPlan，收窄范围到“上下文可见性 + 侧边栏减噪”。
  2. 结合 design explorer 的只读评审意见，把 banner 触发条件收敛为：只有在“存在未保存草稿”且“当前 live 已不等于当前编辑预设”时才显示，避免把正常浏览别的预设误判成异常。
  3. 在 `AppModel` 中新增 `MainWindowContextBannerContext`、`mainWindowContextBannerContext` 和 `shouldShowMainWindowContextBanner`，把 banner 所需标题、正文、live/selected 名称与环境标签做成可测试的派生状态，而不新增任何持久化字段。
  4. 在主窗口中新增 `LiveContextBanner` 组件，放在“状态总览 + 快捷动作”区域下方，提供两个明确动作：`切到当前生效预设` 与 `用当前 live 覆盖草稿`；其中后者增加了二次确认，避免误覆盖未保存草稿。
  5. 调整 `CurrentStatusSummaryCard` 文案，把摘要里的“当前选中”改成“当前编辑”，减少“选中了谁”和“正在编辑谁”之间的认知歧义。
  6. 重排侧边栏底部操作区：保留 `新建 / 复制 / 删除 / 从模板新建 / 导出当前` 这些高频入口，把追加导入、覆盖导入、导出全部、导出收藏收口到 `管理` 菜单，降低视觉噪音但不删除功能。
  7. 在 `AppModelTemplateWorkflowTests` 中补充 3 类回归：菜单栏切换后 banner 会出现且文案正确、live 与 selected 一致时不显示 banner、未读取 live 快照时不误显示 banner。
  8. 执行 `swift test --filter AppModelTemplateWorkflowTests`、`swift test` 和 `swift build`，确认本轮新增 banner 契约、主窗口接线与侧边栏减噪全部通过编译和 52 项测试回归。
- 原因：修掉“草稿被覆盖”只能解决数据安全问题，不能解决理解成本问题。如果菜单栏快速切换后主窗口仍然没有一条持续可见的上下文提示，用户还是会在“当前 live”“当前编辑”“未保存草稿”之间反复确认，产生新的心理负担；而侧边栏底部同时堆着多组导入导出按钮，也会继续稀释主流程的视觉焦点。

## 2026-04-13 22:43:45 CST

- 类型：新功能
- 内容：优化 macOS 编辑页中的“测试连接”反馈链路，把测试中/测试结果从页面中段上移到顶部操作区附近显示，并把下方原结果区改成说明区，避免用户点击后还要向下滚动寻找反馈。
- 思路：这轮不动连接测试底层逻辑，只修“反馈距离太远”这个核心体验问题。用户点“测试连接”时的注意力本来就在按钮附近，所以结果应该在同一视线区域内出现，而不该埋在下面的 `GroupBox` 里。实现上采用顶部内联反馈条，而不是新增 toast 或弹窗，这样既不用引入额外关闭状态，也能保留成功/警告/失败三类结果的完整文案。
- 处理步骤：
  1. 按 `artifact-gated-agents + gstack-style-workflow` 跑了一轮最小关卡，把范围收窄为“测试连接结果近场反馈”，不扩大到整页重构。
  2. 结合只读 explorer 的审查意见，确认结果反馈最合适的位置是 `PresetEditorView` 顶部 header 卡片里，具体放在“测试连接 / 立即应用”按钮行下方、说明文案上方。
  3. 在 `PresetEditorView` 中新增顶部 `connectionFeedbackBanner`：测试进行中时显示蓝色加载提示，测试完成后在同一位置展示成功/警告/失败结果，并保留标题、正文、测试地址和状态码。
  4. 将下方原 `connectionTestSection` 的职责改为“连接检查说明”，保留静态解释文案，但不再重复承担动态结果展示，避免顶部和下方出现两份相同结果。
  5. 根据 reviewer 提醒，补充最小 App 状态层测试，覆盖“开始测试时会进入 loading 且清空旧结果”“测试完成后会正确发布新结果”两条关键路径，而不只依赖 Core 层 `ConnectionTestServiceTests`。
  6. 运行 `swift test --filter AppModelTemplateWorkflowTests`、`swift test` 和 `swift build`，确认顶部反馈改造与新增状态测试一起通过；当前 54 项测试全部通过。
- 原因：原先的“测试连接”虽然已经能正确分类成功/警告/失败，但结果展示位置离按钮过远，用户点击后需要再向下滚动才能看到反馈，这会明显打断编辑流，也降低“测一下马上改一下”的顺滑感。

## 2026-04-15 02:05:41 CST

- 类型：新功能
- 内容：优化 macOS 主窗口首屏排版，收缩右侧“快速动作”区的纵向占用，移除重复/低频入口，并把“全局设置”降级到工作区标题行，减少“工作区总览”下方的大面积空白。
- 思路：这次没有把问题简单理解成“右边再往上挪一点”，而是先从产品优先级看首屏应该服务什么。主窗口首屏的核心任务其实是三件事：先判断当前 live/草稿状态，再执行少量高频动作，然后尽快进入编辑区。现状里右侧 `quickActionPanel` 塞了 6 个大卡片，把高频动作、全局设置和工作区导航放成同级，结果整块区域像一座很高的操作塔，把顶部 `HStack` 整体撑高，左侧摘要卡片下面自然出现大片空白，编辑区也被压到更靠下的位置。所以这轮选择收缩右栏高度，而不是反向把左栏硬拉高去“填空”。
- 处理步骤：
  1. 按 `artifact-gated-agents + gstack-style-workflow` 先做一轮最小关卡，明确这不是单纯的像素微调，而是首屏信息层级和产品优先级优化。
  2. 审查 `MainWindowView`、`CurrentStatusSummaryCard` 和 `PresetEditorView` 后，确认空白的真实根因是顶部 `HStack` 以更高的右侧 `quickActionPanel` 为准，而不是存在额外 `Spacer()` 或滚动容器插入空白。
  3. 从产品经理角度重新划分快速动作范围，只保留 `重新读取`、`载入到草稿`、`恢复最近备份`、`收藏当前预设` 这 4 个与当前配置处理直接相关的高频动作。
  4. 将重复入口 `模板工作台` 从快速动作区移除，因为下方已经有 `工作区` 分段控件可直接切换；将低频全局入口 `打开设置` 从快捷区移除，改放到工作区标题行右侧，保留可达性但降低视觉竞争。
  5. 同步压缩 `quickActionPanel` 的文案密度、内边距和卡片最小高度，让右栏从 2 列 3 行的大卡矩阵收缩成更紧凑的 2 列 2 行。
  6. 轻量收紧 `CurrentStatusSummaryCard` 的整体 spacing、padding 和摘要块最小高度，让左侧摘要节奏与新右栏高度更匹配。
  7. 运行 `swift test` 做回归验证，当前 54 个测试全部通过，并确认 `MainWindowView.swift` 与 `CurrentStatusSummaryCard.swift` 所在目标重新编译成功。
- 原因：旧版首屏的问题不是功能不够，而是首屏预算被低频和重复入口挤占了。只要右侧快捷区继续承担“高频动作 + 全局设置 + 工作区导航”三种职责，它就会持续把主编辑流往下压，用户每次进入页面都会先看到一块很高的操作区，而不是尽快进入真正的编辑工作。把快捷区收敛到高频上下文动作后，首屏才更像一个效率工具而不是操作看板。

## 2026-04-15 20:17:14 CST

- 类型：新功能
- 内容：启动第一轮 macOS 视觉美化落地，新增统一视觉 token，重构主窗口首屏层级、侧边栏底部操作、编辑区头部动作分级与基础模式降噪，并把菜单栏收敛成更轻量的快速切换器。
- 思路：这轮不是“加几层圆角和阴影”式的表面美化，而是先从用户第一眼的理解路径入手。产品真正要解决的是三件事：用户打开后能不能立刻认出当前环境、能不能分清主动作和次动作、菜单栏能不能像真正的快切器而不是缩小版主窗口。因此先建立共享视觉 token，再围绕“总览 Hero 区、主按钮优先级、表单静噪、菜单栏减负”四个方向做最小完整改造。
- 处理步骤：
  1. 按 `artifact-gated-agents + gstack-style-workflow` 先做一轮最小关卡，明确本轮只改 macOS SwiftUI 视图层，不碰 `AppModel` 的配置读写逻辑和持久化结构。
  2. 新增 `Sources/CodexConfigSwitcher/Views/Components/AppTheme.swift`，抽出 `hero/panel/tile/pill` 圆角、卡片背景、边框、阴影和 badge 填充等共享视觉 token，避免样式继续散落在多个视图里各写一套。
  3. 重构 `MainWindowView.swift`：把顶部状态摘要与快速动作合并到同一个 Hero 容器内；给工作区切换区单独做工具条式容器；把侧边栏底部从一整排并列按钮改成“新建预设 + 从模板新建 + 更多操作”结构，把复制、删除、导入导出等低频操作收进菜单，减少视觉噪音。
  4. 重构 `CurrentStatusSummaryCard.swift`、`PresetSidebarRow.swift`、`PresetStatusBadge.swift`、`PresetEnvironmentBadge.swift` 和 `LiveContextBanner.swift`，统一卡片、状态徽章和提示条的样式，让“当前生效 / 未保存 / 最近应用 / 风险提示”四类状态在视觉上形成稳定语义。
  5. 调整 `PresetEditorView.swift` 和 `LabeledFieldHelp.swift`：把头部动作改成“保存当前预设 + 测试连接 + 更多 + 立即应用”分级结构，只保留一个最强主按钮；基础模式默认隐藏底层 key，仅在高级模式下显示；把原来单独的“连接检查说明”盒子收敛成更轻的说明 banner，减少页面里的 Box 数量。
  6. 调整 `MenuBarContentView.swift`，保留“当前生效环境、搜索、收藏/最近使用/全部预设、打开工作台、重新读取、更多操作”这些快切核心内容，把设置、重启目标应用、备份目录和恢复最近备份统一收进二级菜单，避免菜单栏继续承担过多低频管理职责。
  7. 期间出现一个编译问题：`CurrentStatusSummaryCard.swift` 里新增的 `spotlightBlock` 第一个参数定义为无标签，但调用时写成了 `title:`。修复方式是统一改回无标签调用，然后重新跑编译确认没有残留问题。
  8. 运行 `swift build` 和 `swift test`，当前 54 项测试全部通过；另外执行 `swift run CodexConfigSwitcher` 做 GUI 启动级 smoke check，构建完成后进程按预期持续运行，命令由于桌面 App 常驻而在超时后结束，没有出现启动期崩溃或编译错误。
- 原因：旧版界面最大的问题不是功能缺失，而是“所有信息都想第一时间出现”，导致主窗口顶部层级过多、编辑头部按钮同权、基础模式仍然暴露过多底层配置键、菜单栏承担了太多低频管理入口。结果就是界面看起来像工程面板的集合，而不是一款可长期高频使用的 macOS 效率工具。先把视觉语言统一、把高频路径拉到前面，才能为后续第二轮更细的交互动效和局部精修打下稳定基线。

## 2026-04-15 20:29:44 CST

- 类型：新功能
- 内容：完成 macOS 第二轮视觉精修，新增统一的 `GroupBox` 面板样式、次按钮样式与 hover 抬升反馈，并把这套细节同步到主窗口、编辑区、菜单栏和全局设置面板。
- 思路：第一轮已经解决了“结构不清”和“主次不稳”，第二轮要解决的是“看起来像改过，但还不够像成品”的问题。具体表现是：编辑区和设置区虽然已经拆得更合理，但 `GroupBox` 仍然保留了比较原始的系统感；很多次按钮只是能用，还没有和新的卡片语言统一；鼠标移到预设行、快捷卡片和菜单栏预设项时也缺少轻微反馈，导致整个界面的完成度差一口气。所以这轮不再改信息架构，只补“触感层”和“部件统一层”。
- 处理步骤：
  1. 继续按最小实现原则推进，只改视觉与交互细节，不动 `AppModel`、持久化模型和配置写入逻辑，避免把第二轮精修变成新一轮功能改造。
  2. 在 `AppTheme.swift` 中新增 `AppPanelGroupBoxStyle`、`AppSecondaryButtonStyle` 和 `appHoverLift()`，分别负责统一分组面板视觉、次按钮触感，以及 hover 时的轻微抬升与阴影反馈。
  3. 把 `PresetEditorView` 的多个 `GroupBox` 接入 `AppPanelGroupBoxStyle`，让“基础配置 / 认证 / 高级配置 / 差异预览 / 运行记录与备份”从原本偏系统默认的块状控件，统一成和第一轮卡片语言一致的产品化面板。
  4. 同步重做编辑区头部与状态区里的次按钮，把“保存当前预设、测试连接、打开备份目录、恢复最近备份”等动作统一接到 `AppSecondaryButtonStyle`，让主按钮和次按钮的层级更稳定，同时给可用按钮增加 hover 抬升反馈。
  5. 给主窗口侧边栏预设行、右侧快捷动作卡片、菜单栏预设条目、全局设置里的操作按钮，以及工作区中的“全局设置 / 新建预设 / 从模板新建”等入口接入 `appHoverLift()`，补齐 macOS 高频工具常见的鼠标悬停即时反馈。
  6. 将 `SettingsSheetView` 接入同一套视觉体系：低频设置区的 `GroupBox` 统一换成产品化面板，底部“保存设置 / 完成”动作区也做成独立卡片式容器，避免设置面板的风格与主窗口割裂。
  7. 运行 `swift build` 和 `swift test`，当前 54 项测试全部通过；再执行 `swift run CodexConfigSwitcher` 做桌面 App 启动级 smoke check，构建成功且进入常驻运行，命令超时退出前未出现启动期报错或崩溃。
- 原因：第一轮改完后，界面的结构已经明显更清楚，但用户在实际操作中仍然会感受到“卡片和按钮像是分别做完后拼起来的”。尤其是分组面板、次按钮和 hover 反馈不统一时，产品很容易停留在“高级原型”而不是“成熟工具”的观感。第二轮把这些细节收齐后，主窗口、编辑区、菜单栏和设置面板终于开始像一套完整的 macOS 产品，而不是几块独立优化过的页面。

## 2026-04-17 21:40:43 CST

- 类型：新功能
- 内容：新增 macOS `dmg` 打包脚本，并整理 `1.0.0` 发布所需的版本说明、安装说明和 Release 描述素材，便于直接上传到 GitHub Release。
- 思路：仓库此前已经能构建 `.app`，但还缺少“可直接分发的安装镜像”和“能对外说明本次版本价值”的发布资料；同时历史 tag 还停留在 `v0.1.0`，而应用包内版本已经写成 `1.0.0`，如果直接发包会出现安装包版本、Release 标签和说明文案三套口径不一致的问题。所以这轮先统一版本叙述，再补齐 `dmg` 构建脚本和发布说明，让发布流程从“能构建”升级到“能交付”。
- 处理步骤：
  1. 梳理当前版本元信息，确认仓库已有 `v0.1.0` 历史标签、`Support/Info.plist` 中的 `CFBundleShortVersionString = 1.0.0`，随后把本次发布目标统一到 `1.0.0` 口径，并把 `CFBundleVersion` 提升到 `2`，避免和早期构建号混淆。
  2. 更新 `CHANGELOG.md`，补充 `1.0.0` 版本摘要，集中说明多预设工作流增强、模板库、CLI、Windows 起步支持以及 macOS 视觉重构等关键增量。
  3. 新增 `scripts/build-dmg.sh`，在现有 `build-app.sh` 之上自动读取版本号、构建 `.app`、创建带 `/Applications` 快捷方式的 staging 目录，并通过 `hdiutil` 产出可直接分发的压缩 `dmg`。
  4. 更新 `README.md`，补上 `.dmg` 构建命令、产物位置，以及“当前安装包未 notarize，首次打开可能需要系统放行”的安装提示，减少发布后重复答疑。
  5. 预留 GitHub Release 描述素材，准备在实际构建出安装包后补齐校验信息、安装说明和发布亮点，再用于 Release 正文。
- 原因：只有 `.app` 打包脚本时，团队内部可以自测，但对外分发仍然缺少标准安装形式；而版本号与历史标签不一致会让用户很难判断“自己下载的到底是哪一版”。补齐 `dmg`、版本说明和发布文案后，这个项目才具备更完整的交付形态。
