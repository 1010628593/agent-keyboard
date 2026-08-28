# AgentKeyboard UI 优化与交互 Bug 修复报告

日期：2026-08-29

## 一、Workbuddy hook 安装失败 —— 根因与修复（已验证）

**根因**：`HookInstaller` 只检查 `~/.codebuddy/settings.json`，而本机 WorkBuddy 的实际配置在
`~/.workbuddy/settings.json`（已存在，含 enabledPlugins / sandbox / claw 等配置）。路径不存在 →
`available=false` → 安装直接跳过，界面显示"不可用"。

**修复**（`Sources/AgentKeyboardCore/Config.swift`）：
- 新增 `HookInstaller.workbuddySettingsURL()`：优先 `~/.workbuddy/settings.json`，
  回退 `~/.codebuddy/settings.json`；目录存在但文件缺失时可创建。
- `inspectWorkbuddy` / `installWorkbuddyIfPresent` 全部改走该路径。

**验证**（对真实配置的副本执行合并，未动原文件）：
- `enabledPlugins` / `sandbox` / `claw` 完整保留 ✅
- 4 个生命周期 hook 写入成功，命令指向 notify.sh ✅
- 重复合并不产生重复条目（幂等）✅
- 路径解析结果：`/Users/hanxin/.workbuddy/settings.json` ✅

## 二、Agent 槽位顺序调整（新增功能）

- `Dashboard.swapAssignments(slotA:slotB:)`（Core）：交换两个 F 槽位的智能体，槽位身份
  （F1–F6、keyName）不变，瞬态状态重置，事件按新槽位继续解析。
- `AppModel.moveAgent(slotID:offset:)` + `persistAgentSpecs()`：移动后立即回写
  `agents.toml`，重启后顺序保留。
- Agents 页每个槽位卡片新增上移/下移按钮；未分配槽位禁用并显示"未分配"。
- 槽位卡片改为自适应网格（窄窗口不再挤压变形）。

## 三、交互 Bug 修复

| 问题 | 修复 |
| --- | --- |
| 状态颜色弹窗点击跳转灯光页后弹窗残留 | `AgentStateLooksPopover` 回调先关闭弹窗再跳转 |
| 拖动亮度/速度滑杆时每帧写 UserDefaults 造成卡顿 | `writeLook` / 设置滑杆改为 400–500ms 防抖持久化 |
| 未分配槽位点击无任何反馈 | 按钮禁用 + 60% 透明度 + "未分配"文案 |
| 6 个效果按钮 HStack 窄窗口溢出 | 改为 LazyVGrid 自适应网格 |

## 四、设置界面重构

原设置只有一个"通用"Tab，现拆为三个：
1. **通用**：语言、外观、亮度、空闲亮度、智能体灯光（滑杆防抖保存）
2. **键盘**：连接状态 + 一键重连按钮、错误信息、模拟键盘、看门狗；新增**诊断**区
   （事件桥监听状态、近 60 秒事件数、已渲染帧数、运行时长）
3. **智能体钩子**：每个 agent 独立安装/重装按钮 + 状态灯 + 配置路径；新增 agents.toml
   "在 Finder 中显示"

## 五、验证情况

- `AgentKeyboardCore` target：`swift build` 通过（CLT 工具链）
- App 层：swift-frontend `-typecheck` 全量通过（Xcode-beta 工具链 + 进程内宏插件，
  因终端沙箱阻止 swift-plugin-server，完整链接需在 Xcode 中构建）
- 15 项 Core 行为断言全部 PASS（含真实 workbuddy 配置副本合并验证）
- 新增单测 `mergeNestedJSONHooksPreservesUnrelatedWorkbuddySettings`（Xcode 中
  `swift test` 可跑）

## 修改文件清单

- `macos/AgentKeyboard/Sources/AgentKeyboardCore/Config.swift` — Workbuddy 双路径修复
- `macos/AgentKeyboard/Sources/AgentKeyboardCore/AgentState.swift` — swapAssignments
- `macos/AgentKeyboard/Sources/AgentKeyboardApp/AppModel.swift` — moveAgent / 持久化 / 防抖
- `macos/AgentKeyboard/Sources/AgentKeyboardApp/AgentsView.swift` — 槽位卡片重设计
- `macos/AgentKeyboard/Sources/AgentKeyboardApp/InspectorPane.swift` — 弹窗关闭修复
- `macos/AgentKeyboard/Sources/AgentKeyboardApp/LightingView.swift` — 网格布局
- `macos/AgentKeyboard/Sources/AgentKeyboardApp/SettingsView.swift` — 三 Tab 重构
- `macos/AgentKeyboard/Sources/AgentKeyboardApp/Resources/{en,zh-Hans}.lproj/Localizable.strings` — 新增文案
- `macos/AgentKeyboard/Tests/AgentKeyboardCoreTests/HookInstallerTests.swift` — 新增测试
- `hooks/workbuddy-hooks.json` — 路径说明更新

## 后续建议

- 在 Xcode 中完整构建一次并实际运行，确认 Workbuddy 钩子在真实会话中点亮 F6
- 考虑为槽位卡片补充拖拽排序（当前为按钮移动）
