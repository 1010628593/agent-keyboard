from agent_keyboard.constants import DONE_HOLD_SECONDS
from agent_keyboard.layout import NUMPAD_BAR_NAMES, PROFILE
from agent_keyboard.rgb import APPROVAL, DONE, ERROR, RUNNING, TOOL
from agent_keyboard.scenes import RenderStyle, render_dashboard
from agent_keyboard.state import AgentEvent, AgentStatus, Dashboard


def _px(dashboard: Dashboard, t: float = 1.0, style=RenderStyle.DASHBOARD):
    return render_dashboard(dashboard, t, style=style, idle_white=0.05)


def _color(pixels, name: str):
    return pixels[PROFILE.index(name if name != "ENTER" else "ANSI_ENTER")]


def test_idle_f_keys_are_off_and_other_keys_are_dim():
    dash = Dashboard()
    pixels = _px(dash)
    assert _color(pixels, "F1").is_black()
    assert _color(pixels, "F6").is_black()
    space = _color(pixels, "SPACE")
    assert space.r > 0 and space.r < 40
    assert space.r == space.g == space.b


def test_running_lights_f1_blue_and_space():
    dash = Dashboard()
    dash.apply(AgentEvent("codex", AgentStatus.RUNNING), now=0)
    pixels = _px(dash, t=1.0)
    f1 = _color(pixels, "F1")
    assert f1.b > f1.r and f1.b > f1.g
    space = _color(pixels, "SPACE")
    assert space.b > space.r


def test_tool_is_purple_on_agent_key():
    dash = Dashboard()
    dash.apply(AgentEvent("f2", AgentStatus.TOOL), now=0)
    pixels = _px(dash, t=0.2)
    f2 = _color(pixels, "F2")
    assert f2.r > 20 and f2.b > 40 and f2.g < f2.b


def test_approval_lights_enter_orange():
    dash = Dashboard()
    dash.apply(AgentEvent("claude", AgentStatus.APPROVAL), now=0)
    pixels = _px(dash, t=0.4)
    enter = _color(pixels, "ENTER")
    assert enter.r > enter.b and enter.g > 10
    f2 = _color(pixels, "F2")
    assert f2.r > enter.b


def test_error_blinks_escape():
    dash = Dashboard()
    dash.apply(AgentEvent("codex", AgentStatus.ERROR), now=0)
    on = _color(_px(dash, t=0.05), "ESCAPE")
    off = _color(_px(dash, t=0.30), "ESCAPE")
    assert on.r > 100
    assert off.r < on.r


def test_done_holds_then_returns_to_idle():
    dash = Dashboard()
    dash.apply(AgentEvent("codex", AgentStatus.DONE), now=10.0)
    dash.tick(now=10.5)
    assert dash.slots[0].status is AgentStatus.DONE
    pixels = _px(dash, t=10.5)
    assert _color(pixels, "F1").g > 80
    dash.tick(now=10.0 + DONE_HOLD_SECONDS + 0.01)
    assert dash.slots[0].status is AgentStatus.IDLE


def test_numpad_fills_with_context():
    dash = Dashboard()
    dash.apply(AgentEvent("codex", AgentStatus.RUNNING, context=0.6), now=0)
    pixels = _px(dash)
    lit = 0
    for name in NUMPAD_BAR_NAMES:
        color = pixels[PROFILE.index(name)]
        if color.g > 20 or color.r > 20:
            lit += 1
    assert 8 <= lit <= 12


def test_context_hot_goes_yellow_red():
    dash = Dashboard()
    dash.apply(AgentEvent("codex", AgentStatus.RUNNING, context=0.97), now=0)
    pixels = _px(dash)
    zero = pixels[PROFILE.index("NUMPAD_0")]
    assert zero.r > zero.g and zero.r > zero.b


def test_aliases_resolve():
    dash = Dashboard()
    dash.apply(AgentEvent("F3", AgentStatus.RUNNING), now=0)
    assert dash.resolve("spring").status is AgentStatus.RUNNING
    dash.apply(AgentEvent.from_dict({"agent": "local", "status": "thinking"}))
    assert dash.resolve("f6").status is AgentStatus.RUNNING


def test_cinematic_error_is_escape_only():
    dash = Dashboard()
    dash.apply(AgentEvent("codex", AgentStatus.ERROR), now=0)
    pixels = _px(dash, t=0.05, style=RenderStyle.CINEMATIC)
    assert _color(pixels, "ESCAPE").r > 100
