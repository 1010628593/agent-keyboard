from agent_keyboard.constants import (
    DIRECT_HEADER_HI,
    DIRECT_HEADER_LO,
    FRAME_BUFFER_SIZE,
    LED_COUNT,
    LEDS_PER_PACKET,
    PACKETS_PER_FRAME,
    REPORT_LENGTH,
)
from agent_keyboard.layout import PROFILE
from agent_keyboard.protocol import build_frame
from agent_keyboard.rgb import BLACK, WHITE, Rgb


def _pixels(fn):
    return [fn(i) for i in range(LED_COUNT)]


def test_build_frame_has_eight_packets_with_correct_headers():
    dest = build_frame(_pixels(lambda _: BLACK))
    assert len(dest) == FRAME_BUFFER_SIZE
    for p in range(PACKETS_PER_FRAME):
        b = p * REPORT_LENGTH
        assert dest[b + 0] == 0x00
        assert dest[b + 1] == DIRECT_HEADER_HI
        assert dest[b + 2] == DIRECT_HEADER_LO
        expected = 15 if p < 7 else 2
        assert dest[b + 3] == expected
        assert dest[b + 4] == 0x00


def test_build_frame_writes_key_id_and_colour_quads_in_render_order():
    pixels = _pixels(lambda i: Rgb(i, i + 1, i + 2))
    dest = build_frame(pixels)
    for i in range(LED_COUNT):
        p = i // LEDS_PER_PACKET
        j = i % LEDS_PER_PACKET
        b = p * REPORT_LENGTH + j * 4 + 5
        assert dest[b] == PROFILE.keys[i].key_id
        assert dest[b + 1] == i
        assert dest[b + 2] == (i + 1) & 0xFF
        assert dest[b + 3] == (i + 2) & 0xFF


def test_build_frame_last_packet_tail_is_zero_padded():
    dest = build_frame(_pixels(lambda _: WHITE))
    b = 7 * REPORT_LENGTH
    for k in range(13, REPORT_LENGTH):
        assert dest[b + k] == 0


def test_build_frame_rejects_wrong_pixel_count():
    try:
        build_frame([BLACK] * 10)
    except ValueError:
        return
    raise AssertionError("expected ValueError")


def test_build_frame_rejects_too_small_destination():
    try:
        build_frame(_pixels(lambda _: BLACK), dest=bytearray(10))
    except ValueError:
        return
    raise AssertionError("expected ValueError")
