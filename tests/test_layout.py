from agent_keyboard.constants import LED_COUNT
from agent_keyboard.layout import PROFILE

# Independently verified on Scope II RX hardware by RSS_II_RGB.
EXPECTED_KEY_IDS = bytes(
    [
        0x00,
        0x01,
        0x02,
        0x03,
        0x04,
        0x05,
        0x11,
        0x0D,
        0x18,
        0x19,
        0x12,
        0x13,
        0x14,
        0x15,
        0x20,
        0x21,
        0x1A,
        0x1B,
        0x1C,
        0x28,
        0x29,
        0x22,
        0x23,
        0x24,
        0x30,
        0x31,
        0x2A,
        0x2B,
        0x2C,
        0x2D,
        0x39,
        0x32,
        0x33,
        0x34,
        0x35,
        0x40,
        0x41,
        0x3A,
        0x3B,
        0x3C,
        0x3D,
        0x48,
        0x49,
        0x42,
        0x43,
        0x44,
        0x50,
        0x51,
        0x4A,
        0x4B,
        0x4C,
        0x58,
        0x59,
        0x52,
        0x53,
        0x54,
        0x4D,
        0x60,
        0x61,
        0x5A,
        0x5B,
        0x5C,
        0x5D,
        0x68,
        0x69,
        0x62,
        0x63,
        0x65,
        0x70,
        0x79,
        0x6A,
        0x7C,
        0x78,
        0x7A,
        0x7B,
        0x7D,
        0x80,
        0x81,
        0x82,
        0x85,
        0x88,
        0x89,
        0x8A,
        0x8C,
        0x8D,
        0x90,
        0x91,
        0x92,
        0x95,
        0x99,
        0x9A,
        0x9B,
        0x9C,
        0x9D,
        0xA0,
        0xA1,
        0xA2,
        0xA3,
        0xA4,
        0xA9,
        0xAA,
        0xAB,
        0xAC,
        0xAD,
        0xB1,
        0xB2,
        0xB4,
    ]
)


def test_has_107_keys():
    assert len(PROFILE.keys) == LED_COUNT == 107


def test_key_ids_match_verified_set_in_order():
    assert bytes(k.key_id for k in PROFILE.keys) == EXPECTED_KEY_IDS


def test_index_for_key_id_is_inverse_of_by_index():
    for key in PROFILE.keys:
        assert PROFILE.by_index(key.index).index == key.index
        assert PROFILE.index_for_key_id(key.key_id) == key.index


def test_unknown_key_id_returns_minus_one():
    assert PROFILE.index_for_key_id(0xFF) == -1
    assert PROFILE.index_for_key_id(0x06) == -1


def test_rows_and_cols_in_range():
    for key in PROFILE.keys:
        assert 0 <= key.row < PROFILE.rows
        assert 0 <= key.col < PROFILE.cols


def test_each_grid_cell_used_at_most_once():
    seen: set[tuple[int, int]] = set()
    for key in PROFILE.keys:
        cell = (key.row, key.col)
        assert cell not in seen, f"duplicate {cell} for {key.name}"
        seen.add(cell)


def test_known_keys():
    cases = [
        ("ESCAPE", 0x00, 0, 0),
        ("W", 0x1A, 2, 3),
        ("LEFT_ARROW", 0x85, 5, 16),
        ("Logo", 0xA0, 0, 21),
    ]
    for name, key_id, row, col in cases:
        key = PROFILE.by_index(PROFILE.index_for_key_id(key_id))
        assert key.name == name
        assert key.row == row
        assert key.col == col


def test_spacebar_is_three_leds():
    assert len(PROFILE.indices("SPACE")) == 3
