# Agent Light

Agent Light 不是 Agent 管理器，也不是 RGB 管家。它只做一件事：**把 Agent 状态映射成外设灯光。**

```text
Agent
  │ color scheme
  ▼
Cookbook (Idle / Thinking / Tool / Approval / Done / Error)
  │
  ├─ F1–F6          identity lamps
  └─ Main + Numpad  priority canvas
```

产品只有三页。设置和菜单栏是 Utility 外壳，不是产品功能。

| 页面 | 只解决一个问题 |
| --- | --- |
| Devices | 哪些 RGB 外设可用？ |
| Agents | 哪个 Agent 在 F 键上、用哪套配色？ |
| Lighting | 这套配色怎么铺满键盘？ |

---

## Devices

自动发现外设。插上就出现，界面没有 Connect。

每台设备只显示：

- 名称
- 连接方式（USB / 2.4G）
- Connected / Unavailable
- 键盘角色：F1–F6 是在线 Agent，其余是自动焦点画布
- **Use for Agent Lighting**

当前硬件：

- ROG STRIX SCOPE II RX：真实 HID，可启用
- ROG Harpe Ace：界面占位，Wheel 不可控，状态必须是 Unavailable

用户不需要看到 HID、PID、Adapter。不把 Agent 拖到灯区。

---

## Agents

产品核心。左边选 Agent，中间是只读的 F1–F6 身份灯，右边编辑该 Agent 的配色方案。

```text
Codex  →  F1  →  purple scheme
Hermes →  F3  →  teal scheme
```

- F 键槽位来自现有 HTTP 映射，立刻显示，没有 Apply Assignment
- 右侧 **Agent State Colors** 打开小弹层，点某一个状态（例如 Thinking）跳到 Lighting

键盘角色（固定，不由用户分配）：

- F1–F6：在线 Agent 身份灯（idle 也留一盏暗灯）
- 主键区 + 数字键盘 + F7–F12：焦点画布，按优先级自动铺配色（Error > Approval > Tool > Thinking > Done）
- Wheel：未实现（鼠标不可控）

Agent 进入 Thinking 时，主键区先用像素字帖打出该 Agent 的字母或 icon（约 1.6 秒），再回到整板灯效。

状态来自本机 HTTP `127.0.0.1:7420`。应用启动时会把 `notify.sh` 插到钩子列表最前面（短超时、不阻塞 memmy）。Cursor 会同时执行 `~/.claude/settings.json`，notify 看到 `cursor_version` 时只点亮 Cursor，不会把 Claude 标成在线。

界面库：Codex、Claude Code、Hermes、Cursor、Workbuddy。Pi 仍可通过 HTTP 点亮 F5，但不出现在库里。

---

## Lighting

按整板画布思维：设备 → 灯效。配色属于选中的 Agent，铺满主键区和数字键盘。

灯效：Static / Breathing / Wave / Ripple / Comet / Meteor / Flow / Rain / Scanner / Sparkle / Aurora / Gradient / Rainbow / Heartbeat / Reactive / Off

- 空间类灯效（Wave、Ripple、Comet、Meteor、Flow、Rain、Scanner、Aurora、Gradient、Rainbow）在单键灯区（F1–F6 身份灯）自动退化为呼吸，保证身份灯平滑。
- 状态默认搭配：Thinking → Comet、Tool → Ripple、Approval → Heartbeat、Done → Static、Error → Reactive。
- 规则预览面板内可直接换灯效、取色（6 色板 + 自定义）；Apply 钉住画布后可用"恢复自动"解除。

右侧参数：颜色、亮度、速度。选 Thinking 时可预览启动字帖。

Agent 状态是预设映射层，不在每次配灯时重选：

```text
Idle      → 灯效 A
Thinking  → 灯效 B
Tool      → 灯效 C
Approval  → 灯效 D
Done      → 灯效 E
Error     → 灯效 F
```

Apply Lighting 把当前状态的方案钉在画布上；HTTP 状态到来后改由该 Agent 的 cookbook 接管。看门狗 idle 不会清掉钉子。

鼠标只做预览，不写入 HID。

---

## MCP

MCP 是后台灯光 I/O，不是产品第三页。智能体按键名自绘像素，最长 15 秒，到期交还 cookbook。不走 Lighting 页那 16 种效果，也不是用户自绘字帖。Settings → MCP 显示服务状态、端点，并一键写入 `~/.cursor/mcp.json`。

HTTP `127.0.0.1:7420`（含 `POST /mcp`）、HID 重连、钩子安装、MCP 配置留在后台和 Settings。

---

## 不做

Agent Prompt / Model / Token、Agent 生命周期、Dashboard、Scenes、Automations、Rule Engine、Analytics、Runtime Health、Bridge 页、Logs 页、Agent 创建器、DPI、按键映射、固件升级、用户自绘字帖。
