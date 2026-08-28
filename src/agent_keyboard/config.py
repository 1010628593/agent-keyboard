"""Load config/agents.toml if present; otherwise use built-in defaults."""

from __future__ import annotations

import tomllib
from dataclasses import dataclass
from pathlib import Path

from .constants import DEFAULT_BRIDGE_HOST, DEFAULT_BRIDGE_PORT, DEFAULT_IDLE_WHITE, DEFAULT_TARGET_FPS
from .scenes import RenderStyle
from .state import DEFAULT_AGENTS, AgentSpec, specs_from_config


@dataclass(frozen=True, slots=True)
class AppConfig:
    host: str = DEFAULT_BRIDGE_HOST
    port: int = DEFAULT_BRIDGE_PORT
    fps: int = DEFAULT_TARGET_FPS
    style: RenderStyle = RenderStyle.DASHBOARD
    idle_white: float = DEFAULT_IDLE_WHITE
    agents: tuple[AgentSpec, ...] = DEFAULT_AGENTS
    path: Path | None = None


def default_config_paths() -> list[Path]:
    here = Path(__file__).resolve().parents[2]
    return [
        Path.cwd() / "config" / "agents.toml",
        here / "config" / "agents.toml",
        Path.home() / ".config" / "agent-keyboard" / "agents.toml",
    ]


def load_config(path: Path | None = None) -> AppConfig:
    chosen = path
    if chosen is None:
        for candidate in default_config_paths():
            if candidate.is_file():
                chosen = candidate
                break
    if chosen is None or not chosen.is_file():
        return AppConfig()
    with chosen.open("rb") as fh:
        raw = tomllib.load(fh)
    bridge = raw.get("bridge") or {}
    render = raw.get("render") or {}
    style_raw = str(render.get("style") or "dashboard").lower()
    try:
        style = RenderStyle(style_raw)
    except ValueError:
        style = RenderStyle.DASHBOARD
    agents = specs_from_config(list(raw.get("agents") or []))
    return AppConfig(
        host=str(bridge.get("host") or DEFAULT_BRIDGE_HOST),
        port=int(bridge.get("port") or DEFAULT_BRIDGE_PORT),
        fps=int(render.get("fps") or DEFAULT_TARGET_FPS),
        style=style,
        idle_white=float(render.get("idle_white") or DEFAULT_IDLE_WHITE),
        agents=agents,
        path=chosen,
    )
