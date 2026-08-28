"""24-bit RGB. Channel math matches RSS_II_RGB.Core.Rendering.Rgb (byte truncation)."""

from __future__ import annotations

from dataclasses import dataclass
from math import floor


def _clamp_byte(value: int) -> int:
    if value < 0:
        return 0
    if value > 255:
        return 255
    return value


@dataclass(frozen=True, slots=True)
class Rgb:
    r: int
    g: int
    b: int

    def __post_init__(self) -> None:
        object.__setattr__(self, "r", _clamp_byte(int(self.r)))
        object.__setattr__(self, "g", _clamp_byte(int(self.g)))
        object.__setattr__(self, "b", _clamp_byte(int(self.b)))

    def scale(self, k: float) -> Rgb:
        return Rgb(
            int(round(self.r * k)),
            int(round(self.g * k)),
            int(round(self.b * k)),
        )

    def max_with(self, other: Rgb) -> Rgb:
        return Rgb(max(self.r, other.r), max(self.g, other.g), max(self.b, other.b))

    def is_black(self) -> bool:
        return self.r == 0 and self.g == 0 and self.b == 0

    @staticmethod
    def lerp(a: Rgb, b: Rgb, t: float) -> Rgb:
        if t < 0:
            t = 0.0
        elif t > 1:
            t = 1.0
        return Rgb(
            int(a.r + (b.r - a.r) * t),
            int(a.g + (b.g - a.g) * t),
            int(a.b + (b.b - a.b) * t),
        )

    @staticmethod
    def from_hsv(h: float, s: float, v: float) -> Rgb:
        h -= floor(h)
        i = int(h * 6) % 6
        f = h * 6 - floor(h * 6)
        p = v * (1 - s)
        q = v * (1 - f * s)
        t = v * (1 - (1 - f) * s)
        if i == 0:
            r, g, b = v, t, p
        elif i == 1:
            r, g, b = q, v, p
        elif i == 2:
            r, g, b = p, v, t
        elif i == 3:
            r, g, b = p, q, v
        elif i == 4:
            r, g, b = t, p, v
        else:
            r, g, b = v, p, q
        return Rgb(int(r * 255), int(g * 255), int(b * 255))


BLACK = Rgb(0, 0, 0)
WHITE = Rgb(255, 255, 255)

# Restrained Agent Mode palette — not esports rainbow.
IDLE_WHITE = Rgb(255, 255, 255)
RUNNING = Rgb(40, 120, 255)
TOOL = Rgb(160, 70, 255)
APPROVAL = Rgb(255, 140, 30)
DONE = Rgb(40, 210, 90)
ERROR = Rgb(255, 40, 40)
CONTEXT_OK = Rgb(40, 160, 90)
CONTEXT_WARN = Rgb(255, 200, 40)
CONTEXT_HOT = Rgb(255, 40, 40)
