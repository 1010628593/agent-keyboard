# Agent Light

Agent Light 不是 Agent 管理器，也不是 RGB 管家。它只做一件事：**把 Agent 状态映射成外设灯光。**

```text
Agent
  │ state assignment
  ▼
Cookbook (Idle / Thinking / Tool / Approval / Done / Error)
  │ named shared scheme
  ├─ F1–F6          identity lamps
  └─ Selected keys  priority canvas
```

产品只有三页。设置和菜单栏是 Utility 外壳，不是产品功能。

| 页面 | 只解决一个问题 |
| --- | --- |
| Devices | 哪些 RGB 外设可用？ |
| Agents | 哪个 Agent 在 F 键上、用哪套配色？ |
| Lighting | 这套配色用什么参数、作用在哪些键？ |

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

按配色画布思维：智能体 → 状态 → 命名方案 → 按键选区与灯效。每个状态保存一个方案 ID；方案保存颜色/渐变、灯效专属参数、亮度、速度和选区。旧配置会迁移为内置绑定或“已迁移”自定义方案；缺少选区字段时默认使用除 F1–F6 外的全部画布。

### 方案库

- 内置方案 ID 固定为 `builtin.<agentID>.<status>`，保持各智能体现有默认色与状态灯效，只读；首次修改时自动生成副本并只重新绑定当前状态。
- 自定义方案是共享引用。一个方案可被多个智能体状态使用，颜色、参数和选区的修改会同步到所有使用位置；界面显示数量和具体使用位置。
- “复制为独立方案”会解除当前状态与共享方案的连带编辑。方案名称去除首尾空白、不能为空、忽略大小写后不可重复。
- 被任何状态引用的方案不能删除；未引用方案需确认后删除。绑定和编辑即时持久化。
- “复制到其他状态”复制当前完整 `StateLook`（灯效、色板、参数、亮度、速度和按键选区），并为每个目标状态创建独立自定义方案，后续修改互不联动。

灯效：Static / Breathing / Wave / Ripple / Comet / Meteor / Flow / Rain / Scanner / Sparkle / Aurora / Gradient / Rainbow / Heartbeat / Reactive / Off

| 灯效组 | 属性 |
| --- | --- |
| Static | 单色、亮度 |
| Breathing / Heartbeat | 1–2 色、最低亮度、速度 |
| Wave / Flow / Aurora | 2–5 色渐变、角度、宽度/尺度、速度 |
| Ripple / Scanner / Reactive | 前景/背景色、宽度或衰减、速度 |
| Comet | 2–5 色、角度、尾迹、速度 |
| Meteor / Rain | 前景/背景色、角度、密度、尾迹、速度 |
| Sparkle | 前景/背景色、密度、随机颜色、速度 |
| Gradient | 2–5 个可定位色标、角度、动画开关；动画开启后显示速度 |
| Rainbow | 固定 Aura 光谱、角度、带宽、速度 |
| Off | 不显示颜色和动态参数 |

- 空间类灯效（Wave、Ripple、Comet、Meteor、Flow、Rain、Scanner、Aurora、Gradient、Rainbow）在单键灯区（F1–F6 身份灯）自动退化为呼吸，保证身份灯平滑。
- 状态默认搭配：Thinking → Comet、Tool → Ripple、Approval → Heartbeat、Done → Static、Error → Reactive。
- 主页面固定为左右工作台：左侧六个 Agent、六种状态、完整键盘和按键范围入口，右侧常驻当前 Agent/状态、方案、灯效、颜色与属性。方案库和跨状态复制使用弹层，不再把主流程推到折叠区或页面下方。
- 进入 Lighting 即开启真实键盘实时预览，修改自动持久化；点击“完成”、切换侧栏或关闭窗口都会结束预览并恢复自动状态灯光。旧版 `Apply Lighting` / `Resume Auto` 快照钉住流程仅在启动迁移时清理，不再产生新快照。
- 颜色编辑包含 6 色板、自定义取色、Hex、背景色和渐变色标；灯效缩略图直接调用正式渲染器，并遵守“减少动态效果”。
- 键盘默认用于预览；点击“编辑按键范围”才进入选区模式。选区支持全部、主键区、F7–F12、导航与方向键、数字键盘和 Logo 快捷区域，也支持单击或拖动逐键添加、擦除。
- F1–F6 始终锁定为智能体身份灯，不进入任何 cookbook 选区；方案生效时，未选按键完全熄灭。
- Thinking 启动字帖只在该状态已选按键内显示，然后进入当前灯效。

右侧属性面板是 Lighting 的唯一编辑入口；全局 Inspector 在此页隐藏，避免出现双重右栏。选 Thinking 时可预览启动字帖。

Agent 状态是预设映射层，不在每次配灯时重选：

```text
Idle      → 灯效 A
Thinking  → 灯效 B
Tool      → 灯效 C
Approval  → 灯效 D
Done      → 灯效 E
Error     → 灯效 F
```

Lighting 实时预览优先于 cookbook，离开工作台后立即交还给按优先级渲染的 Agent 状态。HTTP、看门狗和 MCP 临时像素层协议保持不变；MCP 预览租约仍在到期后交还 cookbook。

鼠标只做预览，不写入 HID。

---

## MCP

MCP 是后台灯光 I/O，不是产品第三页。智能体按键名自绘像素，最长 15 秒，到期交还 cookbook。不走 Lighting 页那 16 种效果，也不是用户自绘字帖。Settings → MCP 显示服务状态、端点，并一键写入 `~/.cursor/mcp.json`。

HTTP `127.0.0.1:7420`（含 `POST /mcp`）、HID 重连、钩子安装、MCP 配置留在后台和 Settings。

---

## 不做

Agent Prompt / Model / Token、Agent 生命周期、Dashboard、Scenes、Automations、Rule Engine、Analytics、Runtime Health、Bridge 页、Logs 页、Agent 创建器、DPI、按键功能重映射、按灯区分配智能体、固件升级、用户自绘字帖、Aura Creator 多层时间轴、Aura Sync 多设备同步、音乐响应、屏幕取色、AI Aura、方案导入导出与云同步。
