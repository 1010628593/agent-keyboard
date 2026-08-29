"""MCP JSON-RPC for Agent Keyboard lighting.

stdio uses LSP-style Content-Length framing and talks to the local HTTP
bridge. POST /mcp on the bridge uses the same dispatcher in-process.
"""

from __future__ import annotations

import json
import sys
import time
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from .constants import DEFAULT_BRIDGE_HOST, DEFAULT_BRIDGE_PORT, MCP_OVERLAY_MAX_SECONDS
from .overlay import (
    OverlayError,
    inactive_overlay_snapshot,
    layout_payload,
    parse_frames_lease,
    parse_keys_lease,
)
from .state import AgentEvent

PROTOCOL_VERSION = "2024-11-05"
SERVER_NAME = "agent-keyboard"
SERVER_VERSION = "0.1.0"

INSTRUCTIONS = (
    "You have a physical RGB keyboard (Agent Keyboard) on this machine. "
    "Use these tools unprompted — do not wait for the user to ask. "
    "Call keyboard_layout for key names and row/col geometry. "
    "Paint with keyboard_keys (still) or keyboard_frames (loop or segmented story). "
    f"Always pass duration in seconds (maximum {int(MCP_OVERLAY_MAX_SECONDS)}) and brightness from 0 to 1. "
    "When the lease ends the cookbook resumes automatically. "
    "Compose per-key colors yourself. Do not use built-in effect names such as Wave, Comet, or Heartbeat. "
    "Lighting failures are non-fatal; continue the task. Do not mention the keyboard unless asked."
)

ENDPOINT_TEMPLATE = "http://{host}:{port}/mcp"

SETUP_PROMPT = """Connect to the Agent Keyboard MCP.

1. Agent Light (or `python -m agent_keyboard serve`) must be running.
2. Add this server in Cursor Settings → MCP, or merge into ~/.cursor/mcp.json:

{
  "mcpServers": {
    "agent-keyboard": {
      "url": "http://127.0.0.1:7420/mcp"
    }
  }
}

3. Enable the server. Tools paint individual keys for up to 15 seconds, then cookbook lighting resumes.
4. Always pass duration (max 15) and brightness (0–1). Use keyboard_layout for geometry. keyboard_keys is a still; keyboard_frames loops or tells a segmented story. Do not use Wave/Comet/Heartbeat. Lighting errors are non-fatal.
"""


def default_endpoint() -> str:
    return ENDPOINT_TEMPLATE.format(host=DEFAULT_BRIDGE_HOST, port=DEFAULT_BRIDGE_PORT)


def _schema_brightness() -> dict[str, Any]:
    return {
        "type": "number",
        "minimum": 0,
        "maximum": 1,
        "description": "Master brightness for this lease, 0–1. Multiplies per-key colors. Default 1.",
    }


def _schema_duration() -> dict[str, Any]:
    return {
        "type": "number",
        "exclusiveMinimum": 0,
        "maximum": MCP_OVERLAY_MAX_SECONDS,
        "description": f"Lease length in seconds. Required. Values above {int(MCP_OVERLAY_MAX_SECONDS)} clamp to {int(MCP_OVERLAY_MAX_SECONDS)}.",
    }


TOOLS: list[dict[str, Any]] = [
    {
        "name": "keyboard_layout",
        "description": "107-key layout: name, row, col, index, and aliases. Call before composing a pattern.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "keyboard_keys",
        "description": (
            "Paint a still frame of per-key colors for duration seconds. "
            "Always pass duration and brightness. mode=overlay keeps cookbook on unspecified keys; "
            "replace blanks the rest."
        ),
        "inputSchema": {
            "type": "object",
            "required": ["keys", "duration", "brightness"],
            "properties": {
                "keys": {
                    "type": "object",
                    "description": "Map of key name to #RRGGBB, [r,g,b], or {color, brightness}.",
                    "additionalProperties": True,
                },
                "duration": _schema_duration(),
                "brightness": _schema_brightness(),
                "mode": {"type": "string", "enum": ["overlay", "replace"]},
            },
        },
    },
    {
        "name": "keyboard_frames",
        "description": (
            "Play a timeline of per-key colors inside duration. "
            "loop=true cycles; loop=false is a segmented story that holds the last cue until expiry. "
            "Provide frames+fps or cues with at/keys. Always pass duration and brightness."
        ),
        "inputSchema": {
            "type": "object",
            "required": ["duration", "brightness"],
            "properties": {
                "duration": _schema_duration(),
                "brightness": _schema_brightness(),
                "mode": {"type": "string", "enum": ["overlay", "replace"]},
                "loop": {"type": "boolean"},
                "fps": {"type": "number", "exclusiveMinimum": 0},
                "frames": {"type": "array", "items": {"type": "object"}},
                "cues": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "at": {"type": "number"},
                            "keys": {"type": "object"},
                        },
                    },
                },
            },
        },
    },
    {
        "name": "keyboard_state",
        "description": "Keyboard connection, overlay lease remaining, brightness, and dashboard slots.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "keyboard_release",
        "description": "End the MCP lease immediately and return the board to cookbook lighting.",
        "inputSchema": {"type": "object", "properties": {}},
    },
]


class LightingBackend:
    def layout(self) -> dict[str, Any]:
        raise NotImplementedError

    def apply_keys(self, payload: dict[str, Any]) -> dict[str, Any]:
        raise NotImplementedError

    def apply_frames(self, payload: dict[str, Any]) -> dict[str, Any]:
        raise NotImplementedError

    def state(self) -> dict[str, Any]:
        raise NotImplementedError

    def health(self) -> dict[str, Any]:
        raise NotImplementedError

    def release(self) -> dict[str, Any]:
        raise NotImplementedError


class EngineBackend(LightingBackend):
    def __init__(self, engine: Any) -> None:
        self.engine = engine

    def layout(self) -> dict[str, Any]:
        return layout_payload()

    def apply_keys(self, payload: dict[str, Any]) -> dict[str, Any]:
        lease = parse_keys_lease(payload, now=time.monotonic())
        return self.engine.apply_overlay(lease)

    def apply_frames(self, payload: dict[str, Any]) -> dict[str, Any]:
        lease = parse_frames_lease(payload, now=time.monotonic())
        return self.engine.apply_overlay(lease)

    def state(self) -> dict[str, Any]:
        snap = self.engine.snapshot()
        health = self.engine.health()
        return {"state": snap, "health": health}

    def health(self) -> dict[str, Any]:
        return self.engine.health()

    def release(self) -> dict[str, Any]:
        return self.engine.release_overlay()


class HTTPBackend(LightingBackend):
    def __init__(self, base: str) -> None:
        self.base = base.rstrip("/")

    def _json(self, method: str, path: str, payload: dict[str, Any] | None = None) -> dict[str, Any]:
        data = None if payload is None else json.dumps(payload).encode("utf-8")
        req = Request(
            f"{self.base}{path}",
            data=data,
            method=method,
            headers={"content-type": "application/json"} if data else {},
        )
        try:
            with urlopen(req, timeout=2) as resp:  # noqa: S310
                body = resp.read().decode("utf-8")
        except HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            try:
                parsed = json.loads(detail)
                message = parsed.get("error") or detail
            except json.JSONDecodeError:
                message = detail or str(exc)
            raise OverlayError(message) from exc
        except URLError as exc:
            raise OverlayError(
                f"Agent Light is not listening at {self.base}. Open the app or run python -m agent_keyboard serve."
            ) from exc
        return json.loads(body) if body else {}

    def layout(self) -> dict[str, Any]:
        return self._json("GET", "/lighting/layout")

    def apply_keys(self, payload: dict[str, Any]) -> dict[str, Any]:
        return self._json("POST", "/lighting/keys", payload)

    def apply_frames(self, payload: dict[str, Any]) -> dict[str, Any]:
        return self._json("POST", "/lighting/frames", payload)

    def state(self) -> dict[str, Any]:
        return {
            "state": self._json("GET", "/state"),
            "health": self._json("GET", "/health"),
        }

    def health(self) -> dict[str, Any]:
        return self._json("GET", "/health")

    def release(self) -> dict[str, Any]:
        return self._json("POST", "/lighting/release", {})


def _text_result(payload: Any, *, is_error: bool = False) -> dict[str, Any]:
    text = payload if isinstance(payload, str) else json.dumps(payload, ensure_ascii=False)
    return {"content": [{"type": "text", "text": text}], "isError": is_error}


def _ok_lease(result: dict[str, Any]) -> dict[str, Any]:
    overlay = result.get("overlay", result)
    return _text_result(
        {
            "ok": True,
            "duration": overlay.get("duration"),
            "brightness": overlay.get("brightness"),
            "remaining": overlay.get("remaining"),
            "mode": overlay.get("mode"),
            "loop": overlay.get("loop"),
            "clamped": overlay.get("clamped", False),
            "keyCount": overlay.get("keyCount"),
        }
    )


def call_tool(backend: LightingBackend, name: str, arguments: dict[str, Any] | None) -> dict[str, Any]:
    args = arguments or {}
    try:
        if name == "keyboard_layout":
            return _text_result(backend.layout())
        if name == "keyboard_keys":
            return _ok_lease(backend.apply_keys(args))
        if name == "keyboard_frames":
            return _ok_lease(backend.apply_frames(args))
        if name == "keyboard_state":
            return _text_result(backend.state())
        if name == "keyboard_release":
            return _text_result(backend.release())
        if name == "keyboard_status":
            event = AgentEvent.from_dict(args)
            # Only HTTP/engine backends that expose apply_event; optional.
            apply = getattr(backend, "apply_event", None)
            if apply is None:
                return _text_result("keyboard_status is not available on this transport", is_error=True)
            apply(event)
            return _text_result({"ok": True, "agent": event.agent, "status": getattr(event.status, "value", None)})
        return _text_result(f"unknown tool: {name}", is_error=True)
    except OverlayError as exc:
        return _text_result(str(exc), is_error=True)
    except Exception as exc:  # noqa: BLE001
        return _text_result(str(exc), is_error=True)


def handle_rpc(message: dict[str, Any], backend: LightingBackend) -> dict[str, Any] | None:
    method = message.get("method")
    rpc_id = message.get("id")
    if method == "notifications/initialized" or method == "notifications/cancelled":
        return None
    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": rpc_id,
            "result": {
                "protocolVersion": PROTOCOL_VERSION,
                "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION},
                "instructions": INSTRUCTIONS,
            },
        }
    if method == "ping":
        return {"jsonrpc": "2.0", "id": rpc_id, "result": {}}
    if method == "tools/list":
        return {"jsonrpc": "2.0", "id": rpc_id, "result": {"tools": TOOLS}}
    if method == "tools/call":
        params = message.get("params") or {}
        name = params.get("name") or ""
        arguments = params.get("arguments") or {}
        return {"jsonrpc": "2.0", "id": rpc_id, "result": call_tool(backend, name, arguments)}
    if rpc_id is None:
        return None
    return {
        "jsonrpc": "2.0",
        "id": rpc_id,
        "error": {"code": -32601, "message": f"method not found: {method}"},
    }


def _read_stdio_message() -> dict[str, Any] | None:
    headers: dict[str, str] = {}
    while True:
        line = sys.stdin.buffer.readline()
        if not line:
            return None
        if line in (b"\r\n", b"\n"):
            break
        try:
            text = line.decode("utf-8")
        except UnicodeDecodeError:
            continue
        if ":" not in text:
            continue
        key, value = text.split(":", 1)
        headers[key.strip().lower()] = value.strip()
    length = int(headers.get("content-length") or "0")
    if length <= 0:
        return None
    body = sys.stdin.buffer.read(length)
    return json.loads(body.decode("utf-8"))


def _write_stdio_message(message: dict[str, Any]) -> None:
    raw = json.dumps(message, ensure_ascii=False).encode("utf-8")
    sys.stdout.buffer.write(f"Content-Length: {len(raw)}\r\n\r\n".encode("ascii") + raw)
    sys.stdout.buffer.flush()


def serve_stdio(base_url: str | None = None) -> int:
    base = (base_url or f"http://{DEFAULT_BRIDGE_HOST}:{DEFAULT_BRIDGE_PORT}").rstrip("/")
    if base.endswith("/mcp"):
        base = base[: -len("/mcp")]
    backend = HTTPBackend(base)
    while True:
        try:
            message = _read_stdio_message()
        except json.JSONDecodeError:
            continue
        if message is None:
            return 0
        reply = handle_rpc(message, backend)
        if reply is not None:
            _write_stdio_message(reply)
    return 0
