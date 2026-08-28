"""107-LED ANSI layout for ROG Strix Scope II RX / NX.

Key ids and (row, col) come from OpenRGB AsusROGStrixScopeIILayouts
(LAYOUT_US) as baked by RSS_II_RGB ScopeIILayout. Render order IS the
Direct-packet order.
"""

from __future__ import annotations

from dataclasses import dataclass

from .constants import LED_COUNT, MATRIX_COLS, MATRIX_ROWS

# (key_id, name, row, col) in Direct render order.
KEYS: tuple[tuple[int, str, int, int], ...] = (
    (0x00, "ESCAPE", 0, 0),
    (0x01, "BACK_TICK", 1, 0),
    (0x02, "TAB", 2, 0),
    (0x03, "CAPS_LOCK", 3, 0),
    (0x04, "LEFT_SHIFT", 4, 0),
    (0x05, "LEFT_CONTROL", 5, 0),
    (0x11, "1", 1, 1),
    (0x0D, "LEFT_WINDOWS", 5, 1),
    (0x18, "F1", 0, 2),
    (0x19, "2", 1, 2),
    (0x12, "Q", 2, 2),
    (0x13, "A", 3, 2),
    (0x14, "Z", 4, 2),
    (0x15, "LEFT_ALT", 5, 2),
    (0x20, "F2", 0, 3),
    (0x21, "3", 1, 3),
    (0x1A, "W", 2, 3),
    (0x1B, "S", 3, 3),
    (0x1C, "X", 4, 3),
    (0x28, "F3", 0, 4),
    (0x29, "4", 1, 4),
    (0x22, "E", 2, 4),
    (0x23, "D", 3, 4),
    (0x24, "C", 4, 4),
    (0x30, "F4", 0, 5),
    (0x31, "5", 1, 5),
    (0x2A, "R", 2, 5),
    (0x2B, "F", 3, 5),
    (0x2C, "V", 4, 5),
    (0x2D, "SPACE", 5, 5),
    (0x39, "6", 1, 6),
    (0x32, "T", 2, 6),
    (0x33, "G", 3, 6),
    (0x34, "B", 4, 6),
    (0x35, "SPACE", 5, 6),
    (0x40, "F5", 0, 7),
    (0x41, "7", 1, 7),
    (0x3A, "Y", 2, 7),
    (0x3B, "H", 3, 7),
    (0x3C, "N", 4, 7),
    (0x3D, "SPACE", 5, 7),
    (0x48, "F6", 0, 8),
    (0x49, "8", 1, 8),
    (0x42, "U", 2, 8),
    (0x43, "J", 3, 8),
    (0x44, "M", 4, 8),
    (0x50, "F7", 0, 9),
    (0x51, "9", 1, 9),
    (0x4A, "I", 2, 9),
    (0x4B, "K", 3, 9),
    (0x4C, "COMMA", 4, 9),
    (0x58, "F8", 0, 10),
    (0x59, "0", 1, 10),
    (0x52, "O", 2, 10),
    (0x53, "L", 3, 10),
    (0x54, "PERIOD", 4, 10),
    (0x4D, "RIGHT_ALT", 5, 10),
    (0x60, "F9", 0, 11),
    (0x61, "MINUS", 1, 11),
    (0x5A, "P", 2, 11),
    (0x5B, "SEMICOLON", 3, 11),
    (0x5C, "FORWARD_SLASH", 4, 11),
    (0x5D, "RIGHT_FUNCTION", 5, 11),
    (0x68, "F10", 0, 12),
    (0x69, "EQUALS", 1, 12),
    (0x62, "LEFT_BRACKET", 2, 12),
    (0x63, "QUOTE", 3, 12),
    (0x65, "MENU", 5, 12),
    (0x70, "F11", 0, 13),
    (0x79, "BACKSPACE", 1, 13),
    (0x6A, "RIGHT_BRACKET", 2, 13),
    (0x7C, "RIGHT_SHIFT", 4, 13),
    (0x78, "F12", 0, 14),
    (0x7A, "ANSI_BACK_SLASH", 2, 14),
    (0x7B, "ANSI_ENTER", 3, 14),
    (0x7D, "RIGHT_CONTROL", 5, 14),
    (0x80, "PRINT_SCREEN", 0, 16),
    (0x81, "INSERT", 1, 16),
    (0x82, "DELETE", 2, 16),
    (0x85, "LEFT_ARROW", 5, 16),
    (0x88, "SCROLL_LOCK", 0, 17),
    (0x89, "HOME", 1, 17),
    (0x8A, "END", 2, 17),
    (0x8C, "UP_ARROW", 4, 17),
    (0x8D, "DOWN_ARROW", 5, 17),
    (0x90, "PAUSE_BREAK", 0, 18),
    (0x91, "PAGE_UP", 1, 18),
    (0x92, "PAGE_DOWN", 2, 18),
    (0x95, "RIGHT_ARROW", 5, 18),
    (0x99, "NUMPAD_LOCK", 1, 20),
    (0x9A, "NUMPAD_7", 2, 20),
    (0x9B, "NUMPAD_4", 3, 20),
    (0x9C, "NUMPAD_1", 4, 20),
    (0x9D, "NUMPAD_0", 5, 20),
    (0xA0, "Logo", 0, 21),
    (0xA1, "NUMPAD_DIVIDE", 1, 21),
    (0xA2, "NUMPAD_8", 2, 21),
    (0xA3, "NUMPAD_5", 3, 21),
    (0xA4, "NUMPAD_2", 4, 21),
    (0xA9, "NUMPAD_TIMES", 1, 22),
    (0xAA, "NUMPAD_9", 2, 22),
    (0xAB, "NUMPAD_6", 3, 22),
    (0xAC, "NUMPAD_3", 4, 22),
    (0xAD, "NUMPAD_PERIOD", 5, 22),
    (0xB1, "NUMPAD_MINUS", 1, 23),
    (0xB2, "NUMPAD_PLUS", 2, 23),
    (0xB4, "NUMPAD_ENTER", 4, 23),
)


@dataclass(frozen=True, slots=True)
class LedKey:
    key_id: int
    name: str
    row: int
    col: int
    index: int


class KeyboardProfile:
    def __init__(self, name: str, rows: int, cols: int, keys: tuple[LedKey, ...]) -> None:
        self.name = name
        self.rows = rows
        self.cols = cols
        self.keys = keys
        self.led_count = len(keys)
        self._index_by_key_id = [-1] * 256
        self._indices_by_name: dict[str, list[int]] = {}
        for key in keys:
            self._index_by_key_id[key.key_id] = key.index
            self._indices_by_name.setdefault(key.name, []).append(key.index)

    def by_index(self, index: int) -> LedKey:
        return self.keys[index]

    def index_for_key_id(self, key_id: int) -> int:
        if 0 <= key_id < 256:
            return self._index_by_key_id[key_id]
        return -1

    def indices(self, name: str) -> tuple[int, ...]:
        return tuple(self._indices_by_name.get(name, ()))

    def index(self, name: str) -> int:
        found = self.indices(name)
        if not found:
            raise KeyError(name)
        return found[0]

    @property
    def packets_per_frame(self) -> int:
        from .constants import LEDS_PER_PACKET

        return (self.led_count + LEDS_PER_PACKET - 1) // LEDS_PER_PACKET

    @property
    def frame_buffer_size(self) -> int:
        from .constants import REPORT_LENGTH

        return self.packets_per_frame * REPORT_LENGTH


def _build_profile() -> KeyboardProfile:
    keys = tuple(
        LedKey(key_id, name, row, col, index)
        for index, (key_id, name, row, col) in enumerate(KEYS)
    )
    if len(keys) != LED_COUNT:
        raise RuntimeError(f"expected {LED_COUNT} keys, got {len(keys)}")
    return KeyboardProfile("Strix Scope II", MATRIX_ROWS, MATRIX_COLS, keys)


PROFILE = _build_profile()

AGENT_KEY_NAMES = ("F1", "F2", "F3", "F4", "F5", "F6")
F_ROW_NAMES = ("F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12")
ARROW_NAMES = ("LEFT_ARROW", "DOWN_ARROW", "UP_ARROW", "RIGHT_ARROW")
# Bottom-to-top, left-to-right fill — reads as a progress bar on the numpad.
NUMPAD_BAR_NAMES = (
    "NUMPAD_0",
    "NUMPAD_1",
    "NUMPAD_2",
    "NUMPAD_3",
    "NUMPAD_4",
    "NUMPAD_5",
    "NUMPAD_6",
    "NUMPAD_7",
    "NUMPAD_8",
    "NUMPAD_9",
    "NUMPAD_PERIOD",
    "NUMPAD_ENTER",
    "NUMPAD_PLUS",
    "NUMPAD_MINUS",
    "NUMPAD_TIMES",
    "NUMPAD_DIVIDE",
    "NUMPAD_LOCK",
)


def indices_named(*names: str) -> tuple[int, ...]:
    out: list[int] = []
    for name in names:
        out.extend(PROFILE.indices(name))
    return tuple(out)
