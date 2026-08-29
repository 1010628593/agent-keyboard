# Agent Keyboard

[English](README.md) | 简体中文

把 **ROG Strix Scope II RX**（游侠 2 RX，PID `0x1AB5`）变成 macOS 上的 107 像素 Agent 状态灯板。

这是 ASUS Aura TUF **Direct** HID 协议的 Mac 原生移植——与 Windows 上 [RSS_II_RGB](https://github.com/bbfox0703/RSS_II_RGB) 使用同一套帧格式，最初记录在 OpenRGB 的 TUF 键盘驱动里。Windows 专用部分（`hid.dll` / `setupapi.dll`）换成 **hidapi / IOKit**。Core（107 灯位表、framebuffer、Direct 组包）作为数据复用，不跑 .NET 运行时。

```
Agent 事件
     ↓
HTTP 桥  (127.0.0.1:7420)
     ↓
仪表盘 + 32 FPS 渲染
     ↓
Direct HID 包  (8 × 65 字节，每包 15 个灯)
     ↓
107 × RGB LED
```

## Agent 模式（克制版）

| 区域 | 含义 |
| --- | --- |
| F1–F6 | 六个 Agent。灭 = 空闲，蓝 = 运行，紫 = 工具，橙 = 待批准，绿 = 完成，红 = 错误 |
| Esc | 错误 / 取消 |
| Enter | 需要批准 |
| Space | 当前 Agent 正在运行（缓慢左右流动） |
| ↑↓←→ | 活动 |
| 数字键盘 | Context / token / 工具进度。≥80% 黄 → 红 |
| 其余按键 | 5% 白 |

默认映射：

| 按键 | Agent |
| --- | --- |
| F1 | Codex |
| F2 | Claude Code |
| F3 | Hermes |
| F4 | Cursor |
| F5 | Pi |
| F6 | Workbuddy |

旧 id `spring` / `data` / `browser` / `local` 仍会解析到 F3–F6。

完成状态会保持绿色扫过 2 秒，然后回到空闲。未使用的槽位若 120 秒没有事件，也会回到空闲。

`--style cinematic` 会改画早期的整板场景（F 行流动、Esc+Enter 呼吸、整板扫过），而不是克制版仪表盘。

## 安装

```bash
brew install hidapi
cd agent-keyboard
uv venv --python 3.13
source .venv/bin/activate
uv pip install -e ".[dev]"
```

`hidapi` 是 C 库（IOKit）。Python 的 `hid` 包只是绑定——两样都要装。没有硬件时可以用 `--simulate`。

## 设备接入

灯控走的是 ASUS Aura **厂商 HID 集合**（usage page `0xFF00`，接口 1）。这不是开机键盘接口，因此不会抢走打字，也不需要「输入监控」权限。

### 支持的硬件

| 设备 | PID | 灯控 |
| --- | --- | --- |
| ROG Strix Scope II RX（游侠 2 RX） | `0x1AB5` | 已映射 — 107 灯 |
| ROG Strix Scope II NX | `0x1AB3` | 已映射 — 同一套布局 |
| 其它 TUF / ROG Aura 键盘 | 若干 | 可见，灯位图尚未实现 |
| ROG Omni Receiver | `0x1ACE` | 忽略（鼠标接收器） |
| ROG Harpe Ace | — | 界面占位；滚轮灯不可控 |

### 用 USB 接入

1. 使用键盘自带的 **USB-C 线**。SpeedNova 2.4 GHz 和蓝牙在 macOS 上不暴露 Aura Direct。
2. 不要用 **ROG Omni Receiver**。那是另一台 ASUS 设备（通常是鼠标），会被忽略。
3. 退出 **Armoury Crate**、**OpenRGB** 以及其它占用 Aura 的程序。同一时刻只有一个进程能持有该集合。
4. 只选 **一个** 占用者：`python -m agent_keyboard serve` **或** Agent Light 应用，不要同时开。

### 确认 Aura 接口

```bash
python -m agent_keyboard enumerate
python -m agent_keyboard probe
```

`enumerate` 应列出带 `*` 的一行，且 `usage=FF00:0001`。`probe` 会打印固件和布局 id。

还没有键盘：用 `--simulate`，或在应用里打开 设置 → 模拟键盘。

### Agent Light 应用

应用启动时会打开键盘。**设备** 页会自动显示已连接 / 不可用。

- 启动应用前先停掉 `python -m agent_keyboard serve`。
- 如果打开失败，到 设置 → 键盘 → **连接键盘**。
- **用于 Agent 灯光** 会在已映射的键盘上启用仪表盘。

### 连接失败时

| 现象 | 处理 |
| --- | --- |
| 没有 ASUS HID，或没有 `*` 行 | 换成数据线，不要用 2.4G / Omni。Python CLI 需先 `brew install hidapi` |
| Aura 接口正被占用 | 停掉另一个占用者，再连接 |
| 未映射的键盘 | 只能出现在目录里，直到该 PID 有灯位图 |
| HID 写入失败 | 拔掉再插 USB；关闭 Armoury Crate / OpenRGB |

## 命令

```bash
# 看 Aura 接口是否可见
python -m agent_keyboard enumerate

# 打开并打印固件 / 布局 id
python -m agent_keyboard probe

# 守护进程 + HTTP 桥（没插键盘时先 --simulate）
python -m agent_keyboard serve --simulate --preview
python -m agent_keyboard serve

# 推送事件（守护进程必须在跑）
python -m agent_keyboard send codex running --context 0.6
python -m agent_keyboard send f2 approval
python -m agent_keyboard send f1 done

# 在硬件 / 模拟器上循环所有场景
python -m agent_keyboard demo --simulate --preview --hold 0.8
```

任意 Agent 钩子里：

```bash
./hooks/agent-status.sh codex running 0.42
```

```json
POST http://127.0.0.1:7420/event
{
  "agent": "codex",
  "status": "running",
  "context": 0.6
}
```

`status` 接受：`idle`、`running` / `thinking`、`tool` / `tool_calling`、`approval`、`done` / `completed`、`error`。

## MCP（智能体逐键控灯）

Agent Light 在 `http://127.0.0.1:7420/mcp` 提供像素层。**不走** cookbook 灯效（Wave / Comet 等）。智能体自己指定键名、颜色、必填的 `duration`（最长 15 秒）和 `brightness`（0–1）。租约结束即交还 cookbook。

| 工具 | 作用 |
| --- | --- |
| `keyboard_layout` | 107 键名称、行列、别名 |
| `keyboard_keys` | 静帧。必须传 `duration` 和 `brightness`。 |
| `keyboard_frames` | 时间轴：`loop: true` 循环；默认分段叙事。`frames`+`fps` 或带 `at` 的 `cues`。 |
| `keyboard_state` | 设备 + 剩余租约 |
| `keyboard_release` | 提前结束租约 |

HTTP：`GET /lighting/layout`、`POST /lighting/keys`、`POST /lighting/frames`、`POST /lighting/release`。stdio：`python -m agent_keyboard mcp`。

用本仓库 `.cursor/mcp.json` 连接 Cursor，或在设置 → MCP → **安装 Cursor MCP** 合并 `~/.cursor/mcp.json`。该页可复制配置提示词。应用必须在听 `:7420`。启用 `agent-keyboard` 并允许工具。

## Swift 应用（macOS 15+）

同一套仪表盘也在 `macos/AgentKeyboard` 里，是原生 SwiftUI 应用：IOKit HID、32 FPS 预览、oMLX 风格侧栏（Dashboard / Agents / Lighting / Bridge / Devices / Logs）、菜单栏图标、设置，以及同样的 HTTP 约定 `127.0.0.1:7420`。驱动按厂商可插拔；本构建只实现 **ASUS / ROG Aura Direct**（Scope II RX/NX 已映射；其它 TUF/ROG 列为未映射）。Aura 集合同一时刻只能被一个进程占用——启动应用前先停掉 `python -m agent_keyboard serve`。

Bridge → 安装可用钩子 会把 1 秒超时、即发即忘的 `notify.sh` 插到 Codex / Claude / Cursor / Hermes 配置最前面，不会替换 mnemon/memmy。应用启动时也会做这件事。Pi 使用 `hooks/pi-hooks.yaml`；Workbuddy 仅在 `~/.codebuddy/settings.json` 存在时安装。

```bash
./hooks/notify.sh codex SessionStart
./hooks/agent-status.sh hermes running 0.42
```

```bash
cd agent-keyboard
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
swift test --package-path macos/AgentKeyboard
bash macos/AgentKeyboard/scripts/package-app.sh
open macos/AgentKeyboard/.build/AgentKeyboard.app
```

钩子继续可用：

```bash
./hooks/agent-status.sh codex running 0.42
```

设置 → 模拟键盘 可在没有硬件时跑渲染。连接失败见 [设备接入](#设备接入)。

## 测试

```bash
pytest
```

协议测试是 RSS_II_RGB 硬件验证过的 Direct 包夹具的 Python 移植（8 个包，15+15+…+2 个灯，按 key-id 顺序）。

## 为什么不用 Air75 V3

Scope II RX 已经是一块 107 像素的 RGB framebuffer。如果你要 75% / Mac 配列 / 无线 / 低矮，Air75 V3 仍然是合适的键盘——不是因为它是更好的 Agent 灯。

## 许可

GPL-3.0-or-later。协议和 107 灯位表来自 OpenRGB（GPL-2.0-or-later）和 RSS_II_RGB（GPL-3.0）。见 `NOTICE`。
