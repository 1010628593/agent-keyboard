import json
from urllib.request import Request, urlopen

from agent_keyboard.bridge import serve
from agent_keyboard.device import NullDevice
from agent_keyboard.renderer import Engine
from agent_keyboard.state import AgentEvent, AgentStatus, Dashboard


def test_event_aliases():
    event = AgentEvent.from_dict({"agent": "f1", "status": "thinking", "context": 1.5})
    assert event.status is AgentStatus.RUNNING
    dash = Dashboard()
    dash.apply(event)
    assert dash.slots[0].status is AgentStatus.RUNNING
    assert dash.slots[0].context == 1.0


def test_http_event_updates_dashboard():
    engine = Engine(Dashboard(), NullDevice(), fps=10)
    server = serve(engine, "127.0.0.1", 0)
    host, port = server.server_address[:2]
    try:
        payload = json.dumps({"agent": "claude", "status": "approval"}).encode()
        req = Request(
            f"http://{host}:{port}/event",
            data=payload,
            headers={"content-type": "application/json"},
        )
        with urlopen(req, timeout=2) as resp:
            body = json.loads(resp.read().decode())
        assert engine.dashboard.resolve("f2").status is AgentStatus.APPROVAL
        assert body["agents"][1]["status"] == "approval"
    finally:
        server.shutdown()
        server.server_close()
