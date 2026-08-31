# Agent Keyboard

English | [简体中文](README.zh-CN.md)

Turn a **ROG Strix Scope II RX** (游侠 2 RX, PID `0x1AB5`) into a 107-pixel Agent status dashboard on macOS.

This is a Mac-native port of the ASUS Aura TUF **Direct** HID protocol — the same framing [RSS_II_RGB](https://github.com/bbfox0703/RSS_II_RGB) uses on Windows, originally documented in OpenRGB's TUF keyboard driver. The Windows-only bits (`hid.dll` / `setupapi.dll`) are replaced with **hidapi / IOKit**. The Core (107-LED map, framebuffer, Direct packet builder) is reused as data, not as a .NET runtime.

```
Agent Events
     ↓
HTTP bridge  (127.0.0.1:7420)
     ↓
Dashboard + 32 FPS renderer
     ↓
Direct HID packets  (8 × 65 bytes, 15 LEDs each)
     ↓
107 × RGB LEDs
```

## Agent Mode (restrained)

| Region | Meaning |
| --- | --- |
| F1–F6 | Six agents. Off = idle, blue = running, purple = tool, orange = approval, green = done, red = error |
| Esc | Error / cancel |
| Enter | Approval required |
| Space | Current agent running (slow left–right flow) |
| ↑↓←→ | Activity |
| NumPad | Context / token / tool progress. ≥80% yellow → red |
| Everything else | 5% white |

Default mapping:

| Key | Agent |
| --- | --- |
| F1 | Codex |
| F2 | Claude Code |
| F3 | Hermes |
| F4 | Cursor |
| F5 | Pi |
| F6 | Workbuddy |

Legacy ids `spring` / `data` / `browser` / `local` still resolve to F3–F6.

Done holds a green sweep for 2 seconds, then returns to idle. Unused slots return to idle after 120s without events.

`--style cinematic` paints the earlier full-keyboard scenes (F-row flow, Esc+Enter breathing, whole-board sweep) instead of the restrained dashboard.

## Setup

```bash
brew install hidapi
cd agent-keyboard
uv venv --python 3.13
source .venv/bin/activate
uv pip install -e ".[dev]"
```

`hidapi` is the C library (IOKit). The Python `hid` package is only a binding — install both. `--simulate` works without hardware.

## Connecting a device

Lighting control uses the ASUS Aura **vendor HID collection** (usage page `0xFF00`, interface 1). That is not the boot keyboard, so typing is not stolen and Input Monitoring is not required.

### Supported hardware

| Device | PID | Lighting |
| --- | --- | --- |
| ROG Strix Scope II RX (游侠 2 RX) | `0x1AB5` | Mapped — 107 LEDs |
| ROG Strix Scope II NX | `0x1AB3` | Mapped — same layout |
| Other TUF / ROG Aura boards | various | Visible, LED map not implemented |
| ROG Omni Receiver | `0x1ACE` | Ignored (mouse dongle) |
| ROG Harpe Ace | — | UI placeholder; wheel lighting is not controllable |

### Plug in over USB

1. Use the keyboard’s **USB-C cable**. SpeedNova 2.4 GHz and Bluetooth do not expose Aura Direct on macOS.
2. Do not use a **ROG Omni Receiver**. That dongle is a different ASUS device (typically a mouse) and is ignored.
3. Quit **Armoury Crate**, **OpenRGB**, and any other Aura owner. Only one process can hold the collection.
4. Pick **one** owner: `python -m agent_keyboard serve` **or** the Agent Light app, not both.

### Verify the Aura interface

```bash
python -m agent_keyboard enumerate
python -m agent_keyboard probe
```

`enumerate` should list a row marked `*` with `usage=FF00:0001`. `probe` prints firmware and layout id.

No keyboard yet: use `--simulate`, or Settings → Simulate keyboard in the app.

### Agent Light app

The app opens the keyboard on launch. **Devices** shows Connected / Unavailable automatically.

- Stop `python -m agent_keyboard serve` before launching the app.
- Settings → Keyboard → **Connect Keyboard** if the open failed.
- **Use for Agent Lighting** enables the dashboard on a mapped board.

### If connect fails

| Symptom | What to do |
| --- | --- |
| No ASUS HID, or no `*` row | Cable in, not 2.4G / Omni. For the Python CLI: `brew install hidapi` |
| Aura interface busy | Stop the other owner, then Connect |
| Unmapped board | Catalog only until a LED map exists for that PID |
| HID write failed | Unplug/replug USB; close Armoury Crate / OpenRGB |

## Commands

```bash
# See whether the Aura interface is visible
python -m agent_keyboard enumerate

# Open it and print firmware / layout id
python -m agent_keyboard probe

# Daemon + HTTP bridge (use --simulate until the keyboard is plugged in)
python -m agent_keyboard serve --simulate --preview
python -m agent_keyboard serve

# Push an event (daemon must be running)
python -m agent_keyboard send codex running --context 0.6
python -m agent_keyboard send f2 approval
python -m agent_keyboard send f1 done

# Cycle every scene on the hardware / simulator
python -m agent_keyboard demo --simulate --preview --hold 0.8
```

From any agent hook:

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

`status` accepts: `idle`, `running` / `thinking`, `tool` / `tool_calling`, `approval`, `done` / `completed`, `error`.

## MCP (agent-driven keys)

Agent Light exposes a pixel overlay at `http://127.0.0.1:7420/mcp`. It does **not** use cookbook effects (Wave / Comet / …). The agent names keys, colors, `duration` (required, max 15s), and `brightness` (0–1). When the lease ends, cookbook lighting resumes.

| Tool | Role |
| --- | --- |
| `keyboard_layout` | 107-key names, row/col, aliases |
| `keyboard_keys` | Still frame. Always pass `duration` and `brightness`. |
| `keyboard_frames` | Timeline: `loop: true` cycles; default is a segmented story. `frames`+`fps` or `cues` with `at`. |
| `keyboard_state` | Device + overlay remaining |
| `keyboard_release` | End the lease early |

HTTP: `GET /lighting/layout`, `POST /lighting/keys`, `POST /lighting/frames`, `POST /lighting/release`. Stdio: `python -m agent_keyboard mcp`.

Connect Cursor with `.cursor/mcp.json` (this repo) or Settings → MCP → **Install Cursor MCP**, which merges `~/.cursor/mcp.json`. Copy the setup prompt from that pane if another agent needs to connect itself. Agent Light must be listening on `:7420`. Enable `agent-keyboard` and allow the tools.

## Swift app (macOS 15+)

The same dashboard lives in `macos/AgentKeyboard` as a native SwiftUI app: IOKit HID, 32 FPS preview, oMLX-style sidebar (Dashboard / Agents / Lighting / Bridge / Devices / Logs), menu bar extra, Settings, and the same HTTP contract on `127.0.0.1:7420`. The driver is vendor-pluggable; this build only implements **ASUS / ROG Aura Direct** (Scope II RX/NX mapped; other TUF/ROG boards are listed as unmapped). Only one process can own the Aura collection — stop `python -m agent_keyboard serve` before launching the app.

The Lighting workbench keeps all six agents, all six editable states, the full keyboard, and an always-visible property panel on one screen. Entering the workbench previews every edit on the connected keyboard in real time and saves it automatically; **Done** (or leaving the page/window) restores automatic status lighting. Each agent state binds to a named scheme containing the effect, a 1–5 stop palette, effect-specific properties, brightness, speed, and a per-key selection. Custom schemes can remain shared references, while **Copy to Other States** creates an independent scheme for every target, including its key selection. Built-in schemes fork on first edit. F1–F6 remain locked identity lamps and never enter the editable selection.

The 16 cookbook effects expose only properties they render (for example angle/width for spatial effects, density/tail for particles, decay/background for transient effects, and positioned stops for gradients). This is a single-device editor inspired by Armoury Crate’s basic lighting properties; it does not implement key-function remapping, agent-by-zone assignment, Aura Sync, profile import/export, or an Aura Creator timeline.

Bridge → Install available hooks prepends a 1s fire-and-forget `notify.sh` onto Codex / Claude / Cursor / Hermes configs without replacing mnemon/memmy. The app also does this on launch. Pi gets `hooks/pi-hooks.yaml`; Workbuddy installs only if `~/.codebuddy/settings.json` exists.

Codex discovers new commands from `~/.codex/hooks.json` as untrusted. Open `/hooks` once and trust the `~/.codex/hooks/agent-keyboard.sh` entries; enabled-but-untrusted hooks are skipped and F1 remains idle.

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

Hooks keep working:

```bash
./hooks/agent-status.sh codex running 0.42
```

Settings → Simulate keyboard runs the renderer without hardware. See [Connecting a device](#connecting-a-device) if Connect fails.

## Tests

```bash
pytest
```

Protocol tests are a Python port of RSS_II_RGB's hardware-verified Direct packet fixtures (8 packets, 15+15+…+2 LEDs, key-id order).

## Why not Air75 V3 for this

The Scope II RX is already a 107-pixel RGB framebuffer. An Air75 V3 is still the right keyboard if you want 75% / Mac layout / wireless / low profile — not because it is a better Agent lamp.

## License

GPL-3.0-or-later. Protocol and 107-LED table derived from OpenRGB (GPL-2.0-or-later) and RSS_II_RGB (GPL-3.0). See `NOTICE`.
