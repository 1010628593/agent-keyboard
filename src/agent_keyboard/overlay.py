"""Agent-authored per-key pixel overlay. Independent of cookbook effects.

A lease lasts at most MCP_OVERLAY_MAX_SECONDS. Inside that window the agent
may hold a still, loop frames, or play a stepped cue timeline. Expiry always
returns the board to cookbook lighting.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from .constants import LED_COUNT, MCP_OVERLAY_MAX_SECONDS
from .layout import PROFILE
from .rgb import BLACK, Rgb

MAX_FRAMES = 64
MAX_CUES = 32
DEFAULT_FPS = 8.0

# Canonical layout names are mixed-case ("Logo"). Lookup is case-insensitive.
_CANONICAL_BY_UPPER: dict[str, str] = {}
for _key in PROFILE.keys:
    _CANONICAL_BY_UPPER.setdefault(_key.name.upper(), _key.name)

_ALIASES: dict[str, str] = {
    "ESC": "ESCAPE",
    "ENTER": "ANSI_ENTER",
    "RETURN": "ANSI_ENTER",
    "CTRL": "LEFT_CONTROL",
    "CONTROL": "LEFT_CONTROL",
    "LEFT_CTRL": "LEFT_CONTROL",
    "RCTRL": "RIGHT_CONTROL",
    "RIGHT_CTRL": "RIGHT_CONTROL",
    "ALT": "LEFT_ALT",
    "OPTION": "LEFT_ALT",
    "RALT": "RIGHT_ALT",
    "RIGHT_OPTION": "RIGHT_ALT",
    "SHIFT": "LEFT_SHIFT",
    "RSHIFT": "RIGHT_SHIFT",
    "WIN": "LEFT_WINDOWS",
    "WINDOWS": "LEFT_WINDOWS",
    "SUPER": "LEFT_WINDOWS",
    "CMD": "LEFT_WINDOWS",
    "COMMAND": "LEFT_WINDOWS",
    "BKSP": "BACKSPACE",
    "BKSPC": "BACKSPACE",
    "DEL": "DELETE",
    "INS": "INSERT",
    "PGUP": "PAGE_UP",
    "PGDN": "PAGE_DOWN",
    "SPC": "SPACE",
    "SPACEBAR": "SPACE",
    "BACKSLASH": "ANSI_BACK_SLASH",
    "SLASH": "FORWARD_SLASH",
    "HYPHEN": "MINUS",
    "DASH": "MINUS",
    "EQUAL": "EQUALS",
    "GRAVE": "BACK_TICK",
    "BTICK": "BACK_TICK",
    "CAPS": "CAPS_LOCK",
    "PRNT": "PRINT_SCREEN",
    "SCRLK": "SCROLL_LOCK",
    "PAUSE": "PAUSE_BREAK",
    "NUMLK": "NUMPAD_LOCK",
    "NUMLOCK": "NUMPAD_LOCK",
    "UP": "UP_ARROW",
    "DOWN": "DOWN_ARROW",
    "LEFT": "LEFT_ARROW",
    "RIGHT": "RIGHT_ARROW",
    "FN": "RIGHT_FUNCTION",
    "LOGO": "Logo",
}


class OverlayError(ValueError):
    def __init__(
        self,
        message: str,
        *,
        unknown: list[str] | None = None,
        keys: list[str] | None = None,
    ) -> None:
        super().__init__(message)
        self.unknown = unknown or []
        self.keys = keys or []


def unique_key_names() -> list[str]:
    seen: set[str] = set()
    names: list[str] = []
    for key in PROFILE.keys:
        if key.name not in seen:
            seen.add(key.name)
            names.append(key.name)
    return names


def aliases() -> dict[str, str]:
    return dict(_ALIASES)


def layout_payload() -> dict[str, Any]:
    return {
        "ledCount": LED_COUNT,
        "rows": PROFILE.rows,
        "cols": PROFILE.cols,
        "keys": [
            {"name": key.name, "row": key.row, "col": key.col, "index": key.index}
            for key in PROFILE.keys
        ],
        "aliases": aliases(),
    }


def resolve_key_name(raw: str) -> str | None:
    token = raw.strip().replace("-", "_").replace(" ", "_")
    if not token:
        return None
    upper = token.upper()
    mapped = _ALIASES.get(upper, upper)
    if mapped in _CANONICAL_BY_UPPER:
        mapped = _CANONICAL_BY_UPPER[mapped]
    return _CANONICAL_BY_UPPER.get(mapped.upper())


def parse_color(value: Any, *, brightness: float = 1.0) -> Rgb:
    extra = 1.0
    payload = value
    if isinstance(value, dict):
        extra = float(value.get("brightness", 1))
        if "color" in value:
            payload = value["color"]
        elif all(k in value for k in ("r", "g", "b")):
            payload = [value["r"], value["g"], value["b"]]
        else:
            raise OverlayError("invalid color object")
    scale = max(0.0, min(1.0, brightness)) * max(0.0, min(1.0, extra))
    rgb = _parse_color_value(payload)
    return rgb if scale >= 0.999 else rgb.scale(scale)


def _parse_color_value(value: Any) -> Rgb:
    if isinstance(value, str):
        text = value.strip().lstrip("#")
        if len(text) == 3:
            text = "".join(ch * 2 for ch in text)
        if len(text) != 6:
            raise OverlayError(f"invalid color: {value!r}")
        try:
            return Rgb(int(text[0:2], 16), int(text[2:4], 16), int(text[4:6], 16))
        except ValueError as exc:
            raise OverlayError(f"invalid color: {value!r}") from exc
    if isinstance(value, (list, tuple)) and len(value) >= 3:
        return Rgb(int(value[0]), int(value[1]), int(value[2]))
    raise OverlayError(f"invalid color: {value!r}")


def parse_duration(payload: dict[str, Any]) -> tuple[float, bool]:
    if "duration" not in payload or payload["duration"] is None:
        raise OverlayError("duration is required")
    try:
        requested = float(payload["duration"])
    except (TypeError, ValueError) as exc:
        raise OverlayError("duration is required") from exc
    if requested <= 0:
        raise OverlayError("duration must be greater than 0")
    clamped = min(requested, MCP_OVERLAY_MAX_SECONDS)
    return clamped, requested > MCP_OVERLAY_MAX_SECONDS


def parse_mode(payload: dict[str, Any]) -> str:
    raw = str(payload.get("mode") or "overlay").strip().lower()
    if raw not in {"overlay", "replace"}:
        raise OverlayError("mode must be overlay or replace")
    return raw


def parse_brightness(payload: dict[str, Any]) -> float:
    if "brightness" not in payload or payload["brightness"] is None:
        return 1.0
    try:
        value = float(payload["brightness"])
    except (TypeError, ValueError) as exc:
        raise OverlayError("brightness must be a number between 0 and 1") from exc
    return max(0.0, min(1.0, value))


def keys_to_pixels(keys: Any) -> dict[int, Rgb]:
    if not isinstance(keys, dict) or not keys:
        raise OverlayError("keys must be a non-empty object of key name to color")
    unknown: list[str] = []
    pixels: dict[int, Rgb] = {}
    for raw_name, raw_color in keys.items():
        name = resolve_key_name(str(raw_name))
        if name is None:
            unknown.append(str(raw_name))
            continue
        color = parse_color(raw_color)
        for index in PROFILE.indices(name):
            pixels[index] = color
    if unknown:
        valid = unique_key_names()
        raise OverlayError(
            f"unknown keys: {', '.join(unknown)}. valid names: {', '.join(valid)}",
            unknown=unknown,
            keys=valid,
        )
    if not pixels:
        raise OverlayError("keys must be a non-empty object of key name to color")
    return pixels


@dataclass(frozen=True, slots=True)
class OverlayCue:
    at: float
    pixels: dict[int, Rgb]


@dataclass
class OverlayLease:
    mode: str
    duration: float
    started_at: float
    loop: bool
    cues: list[OverlayCue]
    period: float
    requested_duration: float
    clamped: bool
    brightness: float = 1.0
    names: tuple[str, ...] = field(default_factory=tuple)

    def expired(self, now: float) -> bool:
        return now - self.started_at >= self.duration

    def remaining(self, now: float) -> float:
        left = self.duration - (now - self.started_at)
        return 0.0 if left < 0 else left

    def pixels_at(self, now: float) -> dict[int, Rgb]:
        elapsed = max(0.0, now - self.started_at)
        if self.loop and self.period > 0:
            t = elapsed % self.period
        else:
            t = elapsed
        chosen = self.cues[0]
        for cue in self.cues:
            if cue.at <= t:
                chosen = cue
            else:
                break
        if self.brightness >= 0.999:
            return chosen.pixels
        return {index: color.scale(self.brightness) for index, color in chosen.pixels.items()}

    def snapshot(self, now: float) -> dict[str, Any]:
        if self.expired(now):
            return {"active": False}
        current = self.pixels_at(now)
        return {
            "active": True,
            "mode": self.mode,
            "keyCount": len(current),
            "remaining": round(self.remaining(now), 3),
            "duration": self.duration,
            "loop": self.loop,
            "clamped": self.clamped,
            "brightness": self.brightness,
            "keys": list(self.names),
        }

    def composite(self, base: list[Rgb], now: float) -> list[Rgb]:
        if self.expired(now):
            return base
        if self.mode == "replace":
            out = [BLACK] * len(base)
        else:
            out = list(base)
        for index, color in self.pixels_at(now).items():
            if 0 <= index < len(out):
                out[index] = color
        return out


def _period_for_cues(cues: list[OverlayCue], duration: float) -> float:
    if len(cues) <= 1:
        return duration
    last = cues[-1].at
    gap = cues[1].at - cues[0].at
    if gap <= 0:
        gap = duration - last if duration > last else duration
    end = last + gap
    return end if end > 0 else duration


def _cues_from_frames(frames: list[Any], fps: float, duration: float) -> list[OverlayCue]:
    if fps <= 0:
        raise OverlayError("fps must be greater than 0")
    if not frames:
        raise OverlayError("frames must be a non-empty array")
    if len(frames) > MAX_FRAMES:
        raise OverlayError(f"too many frames (max {MAX_FRAMES})")
    interval = 1.0 / fps
    cues: list[OverlayCue] = []
    for index, frame in enumerate(frames):
        at = index * interval
        if at >= duration:
            break
        if not isinstance(frame, dict):
            raise OverlayError("each frame must be a key-to-color object")
        cues.append(OverlayCue(at=at, pixels=keys_to_pixels(frame)))
    if not cues:
        raise OverlayError("all frames fall outside duration")
    return cues


def _cues_from_payload(cues_raw: Any, duration: float) -> list[OverlayCue]:
    if not isinstance(cues_raw, list) or not cues_raw:
        raise OverlayError("cues must be a non-empty array")
    if len(cues_raw) > MAX_CUES:
        raise OverlayError(f"too many cues (max {MAX_CUES})")
    built: list[OverlayCue] = []
    for item in cues_raw:
        if not isinstance(item, dict):
            raise OverlayError("each cue must be an object with at and keys")
        if "at" not in item:
            raise OverlayError("each cue needs at")
        try:
            at = float(item["at"])
        except (TypeError, ValueError) as exc:
            raise OverlayError("cue.at must be a number") from exc
        if at < 0 or at >= duration:
            raise OverlayError("cue.at must be in [0, duration)")
        keys = item.get("keys")
        if not isinstance(keys, dict):
            raise OverlayError("each cue needs keys")
        built.append(OverlayCue(at=at, pixels=keys_to_pixels(keys)))
    built.sort(key=lambda cue: cue.at)
    return built


def parse_keys_lease(payload: dict[str, Any], *, now: float) -> OverlayLease:
    duration, clamped = parse_duration(payload)
    pixels = keys_to_pixels(payload.get("keys"))
    names = tuple(
        unique
        for unique in unique_key_names()
        if any(index in pixels for index in PROFILE.indices(unique))
    )
    cues = [OverlayCue(at=0.0, pixels=pixels)]
    return OverlayLease(
        mode=parse_mode(payload),
        duration=duration,
        started_at=now,
        loop=False,
        cues=cues,
        period=duration,
        requested_duration=float(payload["duration"]),
        clamped=clamped,
        brightness=parse_brightness(payload),
        names=names,
    )


def parse_frames_lease(payload: dict[str, Any], *, now: float) -> OverlayLease:
    duration, clamped = parse_duration(payload)
    loop = bool(payload.get("loop", False))
    if payload.get("cues") is not None:
        cues = _cues_from_payload(payload["cues"], duration)
        period = _period_for_cues(cues, duration)
    elif payload.get("frames") is not None:
        try:
            fps = float(payload["fps"]) if payload.get("fps") is not None else DEFAULT_FPS
        except (TypeError, ValueError) as exc:
            raise OverlayError("fps must be a number") from exc
        cues = _cues_from_frames(payload["frames"], fps, duration)
        period = len(payload["frames"]) / fps if fps > 0 else duration
        if period <= 0:
            period = duration
    else:
        raise OverlayError("frames or cues is required")
    names: list[str] = []
    occupied: set[int] = set()
    for cue in cues:
        occupied.update(cue.pixels)
    for name in unique_key_names():
        if any(index in occupied for index in PROFILE.indices(name)):
            names.append(name)
    return OverlayLease(
        mode=parse_mode(payload),
        duration=duration,
        started_at=now,
        loop=loop,
        cues=cues,
        period=period,
        requested_duration=float(payload["duration"]),
        clamped=clamped,
        brightness=parse_brightness(payload),
        names=tuple(names),
    )


def apply_overlay(base: list[Rgb], lease: OverlayLease | None, now: float) -> list[Rgb]:
    if lease is None or lease.expired(now):
        return base
    return lease.composite(base, now)


def inactive_overlay_snapshot() -> dict[str, Any]:
    return {"active": False}
