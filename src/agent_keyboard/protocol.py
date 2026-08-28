"""ASUS Aura TUF Direct packet builder. No I/O — unit-testable.

One frame = ceil(led_count / 15) reports of 65 bytes:

    [0] = 0x00  report id
    [1] = 0xC0
    [2] = 0x81
    [3] = LED count in this packet
    [4] = 0x00
    then 4 bytes per LED: keyId, R, G, B
"""

from __future__ import annotations

from .constants import (
    DIRECT_HEADER_HI,
    DIRECT_HEADER_LO,
    FRAME_BUFFER_SIZE,
    LEDS_PER_PACKET,
    REPORT_LENGTH,
)
from .layout import PROFILE, KeyboardProfile
from .rgb import Rgb


def build_frame(
    pixels: list[Rgb] | tuple[Rgb, ...],
    profile: KeyboardProfile = PROFILE,
    dest: bytearray | None = None,
) -> bytearray:
    if len(pixels) != profile.led_count:
        raise ValueError(f"expected {profile.led_count} pixels, got {len(pixels)}")
    size = profile.frame_buffer_size
    if dest is None:
        dest = bytearray(size)
    elif len(dest) < size:
        raise ValueError(f"destination needs at least {size} bytes")
    else:
        dest[:] = b"\x00" * len(dest)

    keys = profile.keys
    for packet_index in range(profile.packets_per_frame):
        offset = packet_index * LEDS_PER_PACKET
        count = min(LEDS_PER_PACKET, len(keys) - offset)
        if count <= 0:
            break
        base = packet_index * REPORT_LENGTH
        dest[base + 1] = DIRECT_HEADER_HI
        dest[base + 2] = DIRECT_HEADER_LO
        dest[base + 3] = count
        dest[base + 4] = 0x00
        for j in range(count):
            color = pixels[offset + j]
            b = base + j * 4 + 5
            dest[b] = keys[offset + j].key_id
            dest[b + 1] = color.r
            dest[b + 2] = color.g
            dest[b + 3] = color.b
    return dest


def packet_views(frame: bytes | bytearray, profile: KeyboardProfile = PROFILE) -> list[memoryview]:
    mv = memoryview(frame)
    return [
        mv[p * REPORT_LENGTH : (p + 1) * REPORT_LENGTH]
        for p in range(profile.packets_per_frame)
    ]


# Scope II default size, used by tests.
assert FRAME_BUFFER_SIZE == PROFILE.frame_buffer_size
