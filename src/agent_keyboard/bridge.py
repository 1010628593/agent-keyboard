"""Local HTTP event bridge.

POST /event          { "agent": "codex", "status": "running", "context": 0.6 }
GET  /state
GET  /health
POST /demo/<name>    optional cinematic helpers
"""

from __future__ import annotations

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import urlparse

from .renderer import Engine
from .state import AgentEvent, AgentStatus


def _json(handler: BaseHTTPRequestHandler, code: int, payload: Any) -> None:
    body = json.dumps(payload).encode("utf-8")
    handler.send_response(code)
    handler.send_header("content-type", "application/json")
    handler.send_header("content-length", str(len(body)))
    handler.send_header("access-control-allow-origin", "*")
    handler.end_headers()
    handler.wfile.write(body)


def make_handler(engine: Engine):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, format: str, *args) -> None:  # noqa: A003
            return

        def do_OPTIONS(self) -> None:  # noqa: N802
            self.send_response(204)
            self.send_header("access-control-allow-origin", "*")
            self.send_header("access-control-allow-methods", "GET,POST,OPTIONS")
            self.send_header("access-control-allow-headers", "content-type")
            self.end_headers()

        def do_GET(self) -> None:  # noqa: N802
            path = urlparse(self.path).path.rstrip("/") or "/"
            if path == "/health":
                _json(self, 200, {"ok": True, "frames": engine.frames, "device": engine.device.info})
                return
            if path == "/state":
                _json(self, 200, engine.snapshot())
                return
            _json(self, 404, {"error": "not found"})

        def do_POST(self) -> None:  # noqa: N802
            path = urlparse(self.path).path.rstrip("/") or "/"
            length = int(self.headers.get("content-length") or 0)
            raw = self.rfile.read(length) if length else b"{}"
            try:
                payload = json.loads(raw.decode("utf-8") or "{}")
            except json.JSONDecodeError:
                _json(self, 400, {"error": "invalid json"})
                return
            if path == "/event":
                try:
                    event = AgentEvent.from_dict(payload if isinstance(payload, dict) else {})
                    engine.apply_event(event)
                except (KeyError, ValueError) as exc:
                    _json(self, 400, {"error": str(exc)})
                    return
                _json(self, 200, engine.snapshot())
                return
            if path.startswith("/agents/"):
                agent = path.split("/")[-1]
                payload = dict(payload) if isinstance(payload, dict) else {}
                payload["agent"] = agent
                try:
                    engine.apply_event(AgentEvent.from_dict(payload))
                except (KeyError, ValueError) as exc:
                    _json(self, 400, {"error": str(exc)})
                    return
                _json(self, 200, engine.snapshot())
                return
            if path.startswith("/demo/"):
                name = path.split("/")[-1]
                status = {
                    "idle": AgentStatus.IDLE,
                    "running": AgentStatus.RUNNING,
                    "thinking": AgentStatus.RUNNING,
                    "tool": AgentStatus.TOOL,
                    "approval": AgentStatus.APPROVAL,
                    "done": AgentStatus.DONE,
                    "error": AgentStatus.ERROR,
                }.get(name)
                if status is None:
                    _json(self, 404, {"error": f"unknown demo {name!r}"})
                    return
                engine.apply_event(AgentEvent(agent="codex", status=status))
                _json(self, 200, engine.snapshot())
                return
            _json(self, 404, {"error": "not found"})

    return Handler


def serve(engine: Engine, host: str, port: int) -> ThreadingHTTPServer:
    server = ThreadingHTTPServer((host, port), make_handler(engine))
    thread = __import__("threading").Thread(target=server.serve_forever, daemon=True, name="agent-keyboard-http")
    thread.start()
    return server
