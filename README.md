# Agent Keyboard

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

This daemon looks for PID **0x1AB5** (Scope II RX) or **0x1AB3** (NX). A **ROG Omni Receiver** (mouse dongle, PID `0x1ACE`) is a different ASUS device and is ignored. Plug the 游侠 2 RX in over USB.

macOS talks to the **vendor control collection** (usage page `0xFF00`, interface 1). That is not the boot keyboard interface, so this should not steal typing.

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

## Swift app (macOS 15+)

The same dashboard lives in `macos/AgentKeyboard` as a native SwiftUI app: IOKit HID, 32 FPS preview, oMLX-style sidebar (Dashboard / Agents / Lighting / Bridge / Devices / Logs), menu bar extra, Settings, and the same HTTP contract on `127.0.0.1:7420`. The driver is vendor-pluggable; this build only implements **ASUS / ROG Aura Direct** (Scope II RX/NX mapped; other TUF/ROG boards are listed as unmapped). Only one process can own the Aura collection — stop `python -m agent_keyboard serve` before launching the app.

Bridge → Install available hooks prepends a 1s fire-and-forget `notify.sh` onto Codex / Claude / Cursor / Hermes configs without replacing mnemon/memmy. The app also does this on launch. Pi gets `hooks/pi-hooks.yaml`; Workbuddy installs only if `~/.codebuddy/settings.json` exists.

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

Settings → Simulate keyboard runs the renderer without hardware. Close Armoury Crate / OpenRGB first if Connect fails.

## Tests

```bash
pytest
```

Protocol tests are a Python port of RSS_II_RGB's hardware-verified Direct packet fixtures (8 packets, 15+15+…+2 LEDs, key-id order).

## Why not Air75 V3 for this

The Scope II RX is already a 107-pixel RGB framebuffer. An Air75 V3 is still the right keyboard if you want 75% / Mac layout / wireless / low profile — not because it is a better Agent lamp.

## License

GPL-3.0-or-later. Protocol and 107-LED table derived from OpenRGB (GPL-2.0-or-later) and RSS_II_RGB (GPL-3.0). See `NOTICE`.
