import json
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from agent_keyboard.bridge import serve
from agent_keyboard.device import NullDevice
from agent_keyboard.layout import PROFILE
from agent_keyboard.mcp import EngineBackend, call_tool, handle_rpc
from agent_keyboard.renderer import Engine
from agent_keyboard.state import Dashboard


def _engine():
    return Engine(Dashboard(), NullDevice(), fps=10)


def _post(url: str, payload: dict, timeout: float = 2):
    req = Request(
        url,
        data=json.dumps(payload).encode(),
        headers={"content-type": "application/json"},
        method="POST",
    )
    with urlopen(req, timeout=timeout) as resp:
        return resp.status, json.loads(resp.read().decode())


def test_mcp_initialize_and_keys_tool():
    engine = _engine()
    backend = EngineBackend(engine)
    init = handle_rpc(
        {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}},
        backend,
    )
    assert init["result"]["serverInfo"]["name"] == "agent-keyboard"
    assert "brightness" in init["result"]["instructions"]
    listed = handle_rpc({"jsonrpc": "2.0", "id": 2, "method": "tools/list"}, backend)
    names = [tool["name"] for tool in listed["result"]["tools"]]
    assert "keyboard_keys" in names
    result = call_tool(
        backend,
        "keyboard_keys",
        {"keys": {"F4": "#8B5CF6"}, "duration": 4, "brightness": 0.8},
    )
    assert result["isError"] is False
    payload = json.loads(result["content"][0]["text"])
    assert payload["ok"] is True
    assert payload["duration"] == 4
    assert payload["brightness"] == 0.8


def test_http_lighting_and_mcp_routes():
    engine = _engine()
    server = serve(engine, "127.0.0.1", 0)
    host, port = server.server_address[:2]
    try:
        req = Request(f"http://{host}:{port}/lighting/layout")
        with urlopen(req, timeout=2) as resp:
            layout = json.loads(resp.read().decode())
        assert layout["ledCount"] == PROFILE.led_count
        status, body = _post(
            f"http://{host}:{port}/lighting/keys",
            {"keys": {"W": "#00ff88"}, "duration": 3, "brightness": 1},
        )
        assert status == 200
        assert body["overlay"]["active"] is True
        assert body["overlay"]["brightness"] == 1
        assert "W" in body["overlay"]["keys"]
        status, clamped = _post(
            f"http://{host}:{port}/lighting/keys",
            {"keys": {"W": "#00ff88"}, "duration": 30, "brightness": 1},
        )
        assert status == 200
        assert clamped["overlay"]["duration"] == 15
        assert clamped["overlay"]["clamped"] is True
        status, rpc = _post(
            f"http://{host}:{port}/mcp",
            {"jsonrpc": "2.0", "id": 9, "method": "tools/list"},
        )
        assert status == 200
        assert any(tool["name"] == "keyboard_layout" for tool in rpc["result"]["tools"])
        status, called = _post(
            f"http://{host}:{port}/mcp",
            {
                "jsonrpc": "2.0",
                "id": 10,
                "method": "tools/call",
                "params": {
                    "name": "keyboard_keys",
                    "arguments": {"keys": {"F4": "#8B5CF6"}, "duration": 2, "brightness": 1},
                },
            },
        )
        assert status == 200
        lease = json.loads(called["result"]["content"][0]["text"])
        assert lease["ok"] is True
        assert lease["duration"] == 2
        status, released = _post(f"http://{host}:{port}/lighting/release", {})
        assert status == 200
        assert released["overlay"]["active"] is False
    finally:
        server.shutdown()
        server.server_close()


def test_http_unknown_key_and_missing_duration():
    engine = _engine()
    server = serve(engine, "127.0.0.1", 0)
    host, port = server.server_address[:2]
    try:
        try:
            _post(
                f"http://{host}:{port}/lighting/keys",
                {"keys": {"NOPE": "#ffffff"}, "duration": 1, "brightness": 1},
            )
            raise AssertionError("expected HTTP 400")
        except HTTPError as exc:
            assert exc.code == 400
            body = json.loads(exc.read().decode())
            assert "NOPE" in body["unknown"]
            assert "ESCAPE" in body["keys"]
        try:
            _post(
                f"http://{host}:{port}/lighting/keys",
                {"keys": {"W": "#ffffff"}, "brightness": 1},
            )
            raise AssertionError("expected HTTP 400")
        except HTTPError as exc:
            assert exc.code == 400
            body = json.loads(exc.read().decode())
            assert "duration" in body["error"]
        status, _ = _post(
            f"http://{host}:{port}/lighting/keys",
            {"keys": {"W": "#00ff88"}, "duration": 5, "brightness": 1},
        )
        assert status == 200
        req = Request(f"http://{host}:{port}/state")
        with urlopen(req, timeout=2) as resp:
            state = json.loads(resp.read().decode())
        assert state["overlay"]["active"] is True
        assert state["overlay"]["remaining"] <= 5
        assert "W" in state["overlay"]["keys"]
    finally:
        server.shutdown()
        server.server_close()
