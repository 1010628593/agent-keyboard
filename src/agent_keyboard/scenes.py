"""Render Agent state onto the 107-LED framebuffer.

Two styles:

- dashboard (default): restrained. F1–F6 are agent lamps. Esc / Enter / Space /
  arrows / numpad carry global signals. Everything else stays 5% white.
- cinematic: the earlier full-keyboard scenes (F-row flow, green sweep, …).
"""

from __future__ import annotations

import math
from enum import Enum

from .constants import DONE_HOLD_SECONDS
from .layout import (
    ARROW_NAMES,
    F_ROW_NAMES,
    NUMPAD_BAR_NAMES,
    PROFILE,
    indices_named,
)
from .rgb import (
    APPROVAL,
    BLACK,
    CONTEXT_HOT,
    CONTEXT_OK,
    CONTEXT_WARN,
    DONE,
    ERROR,
    RUNNING,
    TOOL,
    WHITE,
    Rgb,
)
from .state import AgentStatus, AgentSlot, Dashboard


class RenderStyle(str, Enum):
    DASHBOARD = "dashboard"
    CINEMATIC = "cinematic"


class Framebuffer:
    def __init__(self, led_count: int = PROFILE.led_count) -> None:
        self.pixels = [BLACK] * led_count

    def fill(self, color: Rgb) -> None:
        self.pixels[:] = [color] * len(self.pixels)

    def set(self, index: int, color: Rgb) -> None:
        self.pixels[index] = color

    def overlay(self, index: int, color: Rgb) -> None:
        self.pixels[index] = self.pixels[index].max_with(color)

    def paint_named(self, name: str, color: Rgb, overlay: bool = True) -> None:
        for index in PROFILE.indices(name):
            if overlay:
                self.overlay(index, color)
            else:
                self.set(index, color)


def _breath(elapsed: float, period: float = 2.2) -> float:
    return 0.5 + 0.5 * math.sin(elapsed * (2 * math.pi / period))


def _pulse(elapsed: float, period: float = 0.9) -> float:
    return 0.35 + 0.65 * _breath(elapsed, period)


def _blink(elapsed: float, period: float = 0.45) -> bool:
    return (elapsed % period) < (period * 0.5)


def _status_color(status: AgentStatus, elapsed: float) -> Rgb | None:
    if status is AgentStatus.IDLE:
        return None
    if status is AgentStatus.RUNNING:
        return RUNNING
    if status is AgentStatus.TOOL:
        return TOOL.scale(_pulse(elapsed, 1.1))
    if status is AgentStatus.APPROVAL:
        return APPROVAL.scale(0.35 + 0.65 * _breath(elapsed, 1.8))
    if status is AgentStatus.DONE:
        return DONE
    if status is AgentStatus.ERROR:
        return ERROR if _blink(elapsed, 0.4) else ERROR.scale(0.15)
    return None


def _context_color(level: float) -> Rgb:
    if level >= 0.95:
        return CONTEXT_HOT
    if level >= 0.80:
        t = (level - 0.80) / 0.20
        return Rgb.lerp(CONTEXT_WARN, CONTEXT_HOT, t)
    if level >= 0.40:
        return Rgb.lerp(CONTEXT_OK, CONTEXT_WARN, (level - 0.40) / 0.40)
    return CONTEXT_OK.scale(0.55 + 0.45 * level / 0.40)


def _paint_space_flow(fb: Framebuffer, color: Rgb, elapsed: float, speed: float = 0.55) -> None:
    spaces = [PROFILE.by_index(i) for i in indices_named("SPACE")]
    if not spaces:
        return
    cols = [key.col for key in spaces]
    lo, hi = min(cols), max(cols)
    span = max(1, hi - lo)
    phase = (elapsed * speed) % 1.0
    for key in spaces:
        t = (key.col - lo) / span
        dist = min(abs(t - phase), 1 - abs(t - phase))
        intensity = max(0.0, 1.0 - dist * 2.4)
        fb.overlay(key.index, color.scale(0.18 + 0.82 * intensity))


def _paint_green_sweep(fb: Framebuffer, elapsed_since_done: float) -> None:
    t = elapsed_since_done / DONE_HOLD_SECONDS
    if t >= 1:
        return
    head = t * (PROFILE.cols + 4)
    for key in PROFILE.keys:
        dist = abs(key.col - head)
        if dist < 3.5:
            fb.overlay(key.index, DONE.scale(max(0.0, 1.0 - dist / 3.5)))


def _paint_arrows(fb: Framebuffer, color: Rgb, elapsed: float) -> None:
    names = ARROW_NAMES
    idx = int(elapsed * 3.0) % len(names)
    for i, name in enumerate(names):
        level = 1.0 if i == idx else 0.18
        fb.paint_named(name, color.scale(level))


def _paint_numpad(fb: Framebuffer, level: float) -> None:
    if level <= 0:
        return
    color = _context_color(level)
    filled = min(len(NUMPAD_BAR_NAMES), max(1, round(level * len(NUMPAD_BAR_NAMES))))
    for i, name in enumerate(NUMPAD_BAR_NAMES):
        if i < filled:
            fb.paint_named(name, color)
        elif level >= 0.80:
            fb.paint_named(name, color.scale(0.12))


def _paint_agent_lamp(fb: Framebuffer, slot: AgentSlot, elapsed: float) -> None:
    color = _status_color(slot.status, elapsed)
    if color is None:
        fb.paint_named(slot.spec.key_name, BLACK, overlay=False)
        return
    fb.paint_named(slot.spec.key_name, color)


def render_dashboard(
    dashboard: Dashboard,
    elapsed: float,
    *,
    style: RenderStyle = RenderStyle.DASHBOARD,
    idle_white: float = 0.05,
) -> list[Rgb]:
    fb = Framebuffer()
    base = WHITE.scale(idle_white)
    fb.fill(base)

    primary = dashboard.primary()
    done_slots = [s for s in dashboard.slots if s.status is AgentStatus.DONE]
    error = dashboard.any_status(AgentStatus.ERROR)
    approval = dashboard.any_status(AgentStatus.APPROVAL)
    running = dashboard.any_status(AgentStatus.RUNNING, AgentStatus.TOOL)
    tool = dashboard.any_status(AgentStatus.TOOL)

    if style is RenderStyle.CINEMATIC:
        _render_cinematic(fb, dashboard, elapsed, primary, done_slots, error, approval, running, tool)
    else:
        for slot in dashboard.slots:
            _paint_agent_lamp(fb, slot, elapsed)

        if error:
            fb.paint_named("ESCAPE", ERROR if _blink(elapsed) else ERROR.scale(0.12))
        if approval:
            fb.paint_named("ANSI_ENTER", APPROVAL.scale(0.35 + 0.65 * _breath(elapsed, 1.8)))

        if done_slots:
            newest = max(done_slots, key=lambda s: s.done_until or 0)
            remaining = (newest.done_until or elapsed) - elapsed
            since = max(0.0, DONE_HOLD_SECONDS - remaining)
            _paint_space_flow(fb, DONE, elapsed, speed=1.4)
            _paint_green_sweep(fb, since)
        elif tool:
            _paint_space_flow(fb, TOOL, elapsed, speed=0.9)
        elif running:
            _paint_space_flow(fb, RUNNING, elapsed)

        if running:
            _paint_arrows(fb, TOOL if tool else RUNNING, elapsed)

        context_source = primary or max(dashboard.slots, key=lambda s: s.context, default=None)
        if context_source and (context_source.fill > 0 or context_source.context >= 0.80):
            _paint_numpad(fb, context_source.context if context_source.context >= 0.80 else context_source.fill)

    return fb.pixels


def _render_cinematic(
    fb: Framebuffer,
    dashboard: Dashboard,
    elapsed: float,
    primary: AgentSlot | None,
    done_slots: list[AgentSlot],
    error: bool,
    approval: bool,
    running: bool,
    tool: bool,
) -> None:
    for name in F_ROW_NAMES:
        fb.paint_named(name, BLACK, overlay=False)
    for slot in dashboard.slots:
        _paint_agent_lamp(fb, slot, elapsed)

    if done_slots:
        newest = max(done_slots, key=lambda s: s.done_until or 0)
        remaining = (newest.done_until or elapsed) - elapsed
        since = max(0.0, DONE_HOLD_SECONDS - remaining)
        _paint_green_sweep(fb, since)
        return

    if error:
        fb.paint_named("ESCAPE", ERROR if _blink(elapsed) else BLACK)
        return

    if approval:
        glow = APPROVAL.scale(0.35 + 0.65 * _breath(elapsed, 1.8))
        fb.paint_named("ESCAPE", glow)
        fb.paint_named("ANSI_ENTER", glow)
        for name in F_ROW_NAMES:
            fb.paint_named(name, glow.scale(0.55))
        return

    if tool:
        _paint_space_flow(fb, TOOL, elapsed, speed=0.9)
        for name in ("Q", "W", "E", "A", "S", "D", "Z", "X", "C"):
            fb.paint_named(name, TOOL.scale(_pulse(elapsed, 1.0) * 0.7))
        return

    if running:
        _paint_space_flow(fb, RUNNING, elapsed)
        flow = (elapsed * 0.35) % 1.0
        for i, name in enumerate(F_ROW_NAMES):
            t = i / max(1, len(F_ROW_NAMES) - 1)
            dist = min(abs(t - flow), 1 - abs(t - flow))
            fb.paint_named(name, RUNNING.scale(max(0.12, 1.0 - dist * 4)))
        return

    context_source = primary or max(dashboard.slots, key=lambda s: s.context, default=None)
    if context_source and context_source.context >= 0.80:
        _paint_numpad(fb, context_source.context)
