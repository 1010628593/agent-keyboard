from agent_keyboard.device import NullDevice
from agent_keyboard.renderer import Engine
from agent_keyboard.state import AgentEvent, AgentStatus, Dashboard


def test_null_device_accepts_frames():
    device = NullDevice()
    dash = Dashboard()
    engine = Engine(dash, device, fps=40)
    engine.apply_event(AgentEvent("codex", AgentStatus.RUNNING, context=0.4))
    engine.start()
    import time

    time.sleep(0.12)
    engine.stop(restore=False)
    assert engine.frames >= 2
    assert device.frames >= 2
    assert device.last_frame is not None
    assert len(device.last_frame) == 107
