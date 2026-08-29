import AgentKeyboardCore
import Testing

@Test func lerpClampsAndInterpolates() {
    let a = RGB(0, 0, 0)
    let b = RGB(100, 50, 0)
    #expect(RGB.lerp(a, b, 0.5) == RGB(50, 25, 0))
    #expect(RGB.lerp(a, b, -1) == a)
    #expect(RGB.lerp(a, b, 2) == b)
}

@Test func scaledUsesRounding() {
    #expect(RGB.white.scaled(0.05) == RGB(13, 13, 13))
}

@Test func hexRoundTripsAndParsesShorthand() {
    #expect(RGB(239, 68, 68).hexString == "#EF4444")
    #expect(RGB(hex: "#ef4444") == RGB(239, 68, 68))
    #expect(RGB(hex: "0f0") == RGB(0, 255, 0))
    #expect(RGB(hex: "nope") == nil)
}
