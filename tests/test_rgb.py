from agent_keyboard.rgb import BLACK, WHITE, Rgb


def test_scale_halves_channels():
    assert Rgb(200, 100, 0).scale(0.5) == Rgb(100, 50, 0)


def test_scale_clamps_above_max():
    assert Rgb(200, 200, 200).scale(2) == Rgb(255, 255, 255)


def test_scale_to_zero_is_black():
    assert WHITE.scale(0) == BLACK


def test_lerp_returns_endpoints():
    assert Rgb.lerp(BLACK, WHITE, 0) == BLACK
    assert Rgb.lerp(BLACK, WHITE, 1) == WHITE


def test_lerp_clamps_out_of_range_t():
    assert Rgb.lerp(BLACK, WHITE, 5) == WHITE
    assert Rgb.lerp(BLACK, WHITE, -1) == BLACK


def test_from_hsv_red_at_hue_zero():
    assert Rgb.from_hsv(0, 1, 1) == Rgb(255, 0, 0)


def test_from_hsv_wraps_at_one():
    assert Rgb.from_hsv(0, 1, 1) == Rgb.from_hsv(1, 1, 1)


def test_from_hsv_zero_value_is_black():
    assert Rgb.from_hsv(0.4, 1, 0) == BLACK
