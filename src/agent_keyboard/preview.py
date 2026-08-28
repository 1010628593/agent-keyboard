"""Truecolor ASCII preview of the 6×24 key grid."""

from __future__ import annotations

from .layout import PROFILE
from .rgb import Rgb

RESET = "\033[0m"


def _cell(color: Rgb) -> str:
    if color.r + color.g + color.b < 12:
        return f"\033[38;2;40;40;40m·{RESET}"
    return f"\033[38;2;{color.r};{color.g};{color.b}m█{RESET}"


def render_grid(pixels: list[Rgb]) -> str:
    grid: list[list[str]] = [[" " for _ in range(PROFILE.cols)] for _ in range(PROFILE.rows)]
    for key in PROFILE.keys:
        grid[key.row][key.col] = _cell(pixels[key.index])
    lines = ["  " + "".join(row) for row in grid]
    legend = (
        "  F1–F6 agents   Esc error   Enter approval   Space running   "
        "Arrows activity   NumPad context"
    )
    return "\n".join(lines + ["", legend])
