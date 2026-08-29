from agent_keyboard.layout import PROFILE
from agent_keyboard.overlay import (
    OverlayError,
    apply_overlay,
    parse_frames_lease,
    parse_keys_lease,
    resolve_key_name,
)
from agent_keyboard.rgb import Rgb


def test_esc_alias_and_space_multi_led():
    assert resolve_key_name("esc") == "ESCAPE"
    assert resolve_key_name("SPACEBAR") == "SPACE"
    lease = parse_keys_lease(
        {"keys": {"ESC": "#ff0000", "spc": "#00ff00"}, "duration": 5, "brightness": 1},
        now=0,
    )
    assert PROFILE.index("ESCAPE") in lease.pixels_at(0)
    space = PROFILE.indices("SPACE")
    assert len(space) == 3
    assert all(index in lease.pixels_at(0) for index in space)


def test_unknown_key_lists_name():
    try:
        parse_keys_lease({"keys": {"NOPE": "#fff"}, "duration": 1, "brightness": 1}, now=0)
    except OverlayError as exc:
        assert "NOPE" in str(exc)
        assert "NOPE" in exc.unknown
        assert "ESCAPE" in exc.keys
        assert "W" in exc.keys
    else:
        raise AssertionError("expected OverlayError")


def test_duration_required_and_clamp():
    try:
        parse_keys_lease({"keys": {"W": "#ffffff"}}, now=0)
    except OverlayError as exc:
        assert "duration" in str(exc)
    else:
        raise AssertionError("expected OverlayError")
    lease = parse_keys_lease(
        {"keys": {"W": "#ffffff"}, "duration": 30, "brightness": 1},
        now=10,
    )
    assert lease.duration == 15
    assert lease.clamped is True
    assert lease.expired(10 + 15)
    assert not lease.expired(10 + 14.9)


def test_brightness_scales_lease_and_per_key():
    full = parse_keys_lease(
        {"keys": {"W": "#ffffff"}, "duration": 4, "brightness": 1},
        now=0,
    )
    half = parse_keys_lease(
        {"keys": {"W": "#ffffff"}, "duration": 4, "brightness": 0.5},
        now=0,
    )
    keyed = parse_keys_lease(
        {
            "keys": {"W": {"color": "#ffffff", "brightness": 0.5}},
            "duration": 4,
            "brightness": 0.5,
        },
        now=0,
    )
    w = PROFILE.index("W")
    assert full.pixels_at(0)[w] == Rgb(255, 255, 255)
    assert half.pixels_at(0)[w] == Rgb(128, 128, 128)
    assert keyed.pixels_at(0)[w].r < half.pixels_at(0)[w].r
    assert half.snapshot(0)["brightness"] == 0.5
    assert "W" in half.snapshot(0)["keys"]


def test_overlay_covers_cookbook_replace_blacks_rest():
    w = PROFILE.index("W")
    f4 = PROFILE.index("F4")
    base = [Rgb(10, 20, 30)] * PROFILE.led_count
    lease = parse_keys_lease(
        {"keys": {"W": "#ff00aa"}, "duration": 8, "brightness": 1, "mode": "overlay"},
        now=0,
    )
    out = apply_overlay(base, lease, 1)
    assert out[w] == Rgb(255, 0, 170)
    assert out[f4] == Rgb(10, 20, 30)
    replace = parse_keys_lease(
        {"keys": {"W": "#ff00aa"}, "duration": 8, "brightness": 1, "mode": "replace"},
        now=0,
    )
    replaced = apply_overlay(base, replace, 1)
    assert replaced[w] == Rgb(255, 0, 170)
    assert replaced[f4].is_black()


def test_loop_and_cues_and_expiry_returns_base():
    frames = parse_frames_lease(
        {
            "duration": 10,
            "brightness": 1,
            "loop": True,
            "fps": 2,
            "frames": [{"W": "#ff0000"}, {"W": "#0000ff"}],
        },
        now=0,
    )
    w = PROFILE.index("W")
    assert frames.pixels_at(0.1)[w].r > 200
    assert frames.pixels_at(0.6)[w].b > 200
    assert frames.pixels_at(1.1)[w].r > 200
    narrative = parse_frames_lease(
        {
            "duration": 12,
            "brightness": 1,
            "loop": False,
            "cues": [
                {"at": 0, "keys": {"W": "#ff0000"}},
                {"at": 3, "keys": {"W": "#00ff00"}},
                {"at": 9, "keys": {"W": "#0000ff"}},
            ],
        },
        now=0,
    )
    assert narrative.pixels_at(1)[w].r > 200
    assert narrative.pixels_at(4)[w].g > 200
    assert narrative.pixels_at(11)[w].b > 200
    base = [Rgb(1, 2, 3)] * PROFILE.led_count
    assert apply_overlay(base, narrative, 12.01)[w] == Rgb(1, 2, 3)
