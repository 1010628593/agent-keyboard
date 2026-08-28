import AgentKeyboardCore
import Foundation
import Testing

@Test func idleFKeysAreOff() {
    let pixels = SceneRenderer.render(Dashboard(), now: 1)
    let f1 = KeyboardProfile.scopeII.index(named: "F1")
    #expect(pixels[f1].isBlack)
}

@Test func runningLightsF1Blue() throws {
    var dashboard = Dashboard()
    try dashboard.apply(AgentEvent(agent: "codex", status: .running), now: 0)
    let pixels = SceneRenderer.render(dashboard, now: 1)
    let f1 = pixels[KeyboardProfile.scopeII.index(named: "F1")]
    #expect(f1.b > f1.r)
    #expect(f1.b > f1.g)
}

@Test func doneReturnsToIdleAfterHold() throws {
    var dashboard = Dashboard()
    try dashboard.apply(AgentEvent(agent: "codex", status: .done), now: 10)
    dashboard.tick(now: 10.5)
    #expect(dashboard.slots[0].status == .done)
    dashboard.tick(now: 10 + AK.doneHoldSeconds + 0.01)
    #expect(dashboard.slots[0].status == .idle)
}

@Test func statusAliases() {
    #expect(AgentStatus.parse("thinking") == .running)
    #expect(AgentStatus.parse("waiting-approval") == .approval)
}

@Test func idleKeysAreDimWhite() {
    let pixels = SceneRenderer.render(Dashboard(), now: 1)
    let space = pixels[KeyboardProfile.scopeII.index(named: "SPACE")]
    #expect(space.r > 0 && space.r < 40)
    #expect(space.r == space.g && space.g == space.b)
}

@Test func toolIsPurpleOnAgentKey() throws {
    var dashboard = Dashboard()
    try dashboard.apply(AgentEvent(agent: "f2", status: .tool), now: 0)
    let f2 = SceneRenderer.render(dashboard, now: 0.2)[KeyboardProfile.scopeII.index(named: "F2")]
    #expect(f2.r > 20 && f2.b > 40 && f2.g < f2.b)
}

@Test func approvalLightsEnterOrange() throws {
    var dashboard = Dashboard()
    try dashboard.apply(AgentEvent(agent: "claude", status: .approval), now: 0)
    let pixels = SceneRenderer.render(dashboard, now: 0.4)
    let enter = pixels[KeyboardProfile.scopeII.index(named: "ANSI_ENTER")]
    #expect(enter.r > enter.b && enter.g > 10)
}

@Test func errorBlinksEscape() throws {
    var dashboard = Dashboard()
    try dashboard.apply(AgentEvent(agent: "codex", status: .error), now: 0)
    let on = SceneRenderer.render(dashboard, now: 0.05)[KeyboardProfile.scopeII.index(named: "ESCAPE")]
    let off = SceneRenderer.render(dashboard, now: 0.30)[KeyboardProfile.scopeII.index(named: "ESCAPE")]
    #expect(on.r > 100)
    #expect(off.r < on.r)
}

@Test func contextHotGoesRed() throws {
    var dashboard = Dashboard()
    try dashboard.apply(AgentEvent(agent: "codex", status: .running, context: 0.97), now: 0)
    let zero = SceneRenderer.render(dashboard, now: 1)[KeyboardProfile.scopeII.index(named: "NUMPAD_0")]
    #expect(zero.r > zero.g && zero.r > zero.b)
}

@Test func waveSceneKeepsRunningLamp() throws {
    var dashboard = Dashboard()
    try dashboard.apply(AgentEvent(agent: "codex", status: .running), now: 0)
    let f1 = SceneRenderer.render(dashboard, now: 1, scene: .wave)[KeyboardProfile.scopeII.index(named: "F1")]
    #expect(f1.b > 20)
}

@Test func hsvProducesPrimaryHues() {
    let red = RGB.hsv(0)
    #expect(red.r > red.g && red.r > red.b)
    let green = RGB.hsv(1.0 / 3.0)
    #expect(green.g > green.r && green.g > green.b)
}

@Test func idleHermesKeepsDimF3AndIdleCanvas() {
    let pixels = SceneRenderer.renderBoard(
        Dashboard(),
        looks: AgentLookBook.seeded(),
        now: 1
    )
    let f3 = pixels[KeyboardProfile.scopeII.index(named: "F3")]
    #expect(f3.luminance > 0)
    #expect(f3.luminance < 50)
    let zero = pixels[KeyboardProfile.scopeII.index(named: "NUMPAD_0")]
    #expect(zero.r == zero.g && zero.g == zero.b)
}

@Test func idleFKeyIsDimmerThanOnlineFKey() throws {
    var dashboard = Dashboard()
    try dashboard.apply(AgentEvent(agent: "codex", status: .running), now: 0)
    let pixels = SceneRenderer.renderBoard(
        dashboard,
        looks: AgentLookBook.seeded(),
        now: AK.glyphHoldSeconds + 0.2
    )
    let f1 = pixels[KeyboardProfile.scopeII.index(named: "F1")]
    let f3 = pixels[KeyboardProfile.scopeII.index(named: "F3")]
    #expect(f1.luminance > f3.luminance * 2)
}

@Test func canvasFollowsCodexThinkingAfterGlyph() throws {
    var dashboard = Dashboard()
    try dashboard.apply(AgentEvent(agent: "codex", status: .running), now: 0)
    try dashboard.apply(AgentEvent(agent: "hermes", status: .idle), now: 0)
    let pixels = SceneRenderer.renderBoard(
        dashboard,
        looks: AgentLookBook.seeded(),
        now: AK.glyphHoldSeconds + 0.2
    )
    let keyA = pixels[KeyboardProfile.scopeII.index(named: "A")]
    let f1 = pixels[KeyboardProfile.scopeII.index(named: "F1")]
    let f3 = pixels[KeyboardProfile.scopeII.index(named: "F3")]
    #expect(keyA.luminance > 20)
    #expect(f1.luminance > f3.luminance)
}

@Test func errorPriorityWinsCanvasOverThinking() throws {
    var dashboard = Dashboard()
    try dashboard.apply(AgentEvent(agent: "codex", status: .running), now: 0)
    try dashboard.apply(AgentEvent(agent: "hermes", status: .error), now: 0)
    let pixels = SceneRenderer.renderBoard(
        dashboard,
        looks: AgentLookBook.seeded(),
        now: AK.glyphHoldSeconds + 0.2
    )
    let keyA = pixels[KeyboardProfile.scopeII.index(named: "A")]
    #expect(keyA.r > keyA.b)
    let f1 = pixels[KeyboardProfile.scopeII.index(named: "F1")]
    #expect(f1.luminance > 20)
}

@Test func pinnedCanvasLightsMainKeysNotFKeys() {
    let pin = StateLook(effect: .staticFill, color: RGB(239, 68, 68), brightness: 1, speed: 1)
    let pixels = SceneRenderer.renderBoard(
        Dashboard(),
        looks: AgentLookBook.seeded(),
        now: 1,
        pinnedCanvas: pin
    )
    let keyA = pixels[KeyboardProfile.scopeII.index(named: "A")]
    #expect(keyA.r > 150)
    #expect(keyA.r > keyA.b)
    let f1 = pixels[KeyboardProfile.scopeII.index(named: "F1")]
    #expect(keyA.r > f1.r)
}

@Test func agentLooksOverrideDefaultCookbook() throws {
    var dashboard = Dashboard()
    try dashboard.apply(AgentEvent(agent: "hermes", status: .running), now: 0)
    var looks = AgentLookBook.seeded()
    looks["hermes"]?[.running] = StateLook(
        effect: .staticFill,
        color: RGB(239, 68, 68),
        brightness: 1,
        speed: 1
    )
    let pixels = SceneRenderer.renderBoard(
        dashboard,
        looks: looks,
        now: AK.glyphHoldSeconds + 0.2
    )
    let keyA = pixels[KeyboardProfile.scopeII.index(named: "A")]
    #expect(keyA.r > 150)
    #expect(keyA.r > keyA.b)
}

@Test func startGlyphPaintsCodexC() throws {
    var dashboard = Dashboard()
    try dashboard.apply(AgentEvent(agent: "codex", status: .running), now: 0)
    let pixels = SceneRenderer.renderBoard(
        dashboard,
        looks: AgentLookBook.seeded(),
        now: 0.3
    )
    let four = pixels[KeyboardProfile.scopeII.index(named: "4")]
    let q = pixels[KeyboardProfile.scopeII.index(named: "Q")]
    #expect(four.luminance > q.luminance)
    let f1 = pixels[KeyboardProfile.scopeII.index(named: "F1")]
    #expect(f1.luminance > 20)
    let f3 = pixels[KeyboardProfile.scopeII.index(named: "F3")]
    #expect(four.luminance > f3.luminance)
}

@Test func startGlyphEndsAfterHold() throws {
    var dashboard = Dashboard()
    try dashboard.apply(AgentEvent(agent: "codex", status: .running), now: 0)
    let during = SceneRenderer.renderBoard(
        dashboard,
        looks: AgentLookBook.seeded(),
        now: 0.3
    )
    let after = SceneRenderer.renderBoard(
        dashboard,
        looks: AgentLookBook.seeded(),
        now: AK.glyphHoldSeconds + 0.2
    )
    let q = KeyboardProfile.scopeII.index(named: "Q")
    #expect(after[q].luminance > during[q].luminance)
}

private func canvasPixels(
    effect: LightingEffect,
    now: TimeInterval,
    color: RGB = RGB(40, 90, 255)
) -> [RGB] {
    let pin = StateLook(effect: effect, color: color, brightness: 1, speed: 1)
    return SceneRenderer.renderBoard(
        Dashboard(),
        looks: AgentLookBook.seeded(),
        now: now,
        pinnedCanvas: pin
    )
}

@Test func rgbHueMapsPrimaries() {
    #expect(abs(RGB(255, 0, 0).hue - 0) < 0.01)
    #expect(abs(RGB(0, 255, 0).hue - 1.0 / 3.0) < 0.01)
    #expect(abs(RGB(0, 0, 255).hue - 2.0 / 3.0) < 0.01)
}

@Test func cometSweepsBrightHeadOverDimBase() {
    let pixels = canvasPixels(effect: .comet, now: 2.0)
    let canvas = LightingMap.scopeII.canvasNames
    let lums = canvas.map { name in
        pixels[KeyboardProfile.scopeII.index(named: name)].luminance
    }
    let lo = lums.min() ?? 0
    let hi = lums.max() ?? 0
    #expect(lo > 0)
    #expect(hi > lo * 2)
}

@Test func scannerBouncesFromLeftToRight() {
    let left = KeyboardProfile.scopeII.index(named: "BACK_TICK")
    let right = KeyboardProfile.scopeII.index(named: "NUMPAD_MINUS")
    let atStart = canvasPixels(effect: .scanner, now: 0.01)
    #expect(atStart[left].luminance > atStart[right].luminance * 2)
    let atEnd = canvasPixels(effect: .scanner, now: 2.0)
    #expect(atEnd[right].luminance > atEnd[left].luminance * 2)
}

@Test func rippleStartsBrightAtCenter() {
    let pixels = canvasPixels(effect: .ripple, now: 0.1)
    let center = pixels[KeyboardProfile.scopeII.index(named: "P")]
    let corner = pixels[KeyboardProfile.scopeII.index(named: "ESCAPE")]
    #expect(center.luminance > corner.luminance * 2)
}

@Test func heartbeatPumpsTwicePerCycle() {
    let key = KeyboardProfile.scopeII.index(named: "A")
    let first = canvasPixels(effect: .heartbeat, now: 0.02)[key].luminance
    let dip = canvasPixels(effect: .heartbeat, now: 0.13)[key].luminance
    let second = canvasPixels(effect: .heartbeat, now: 0.26)[key].luminance
    #expect(first > dip)
    #expect(second > dip)
}

@Test func sparkleTwinklesPerKey() {
    let pixels = canvasPixels(effect: .sparkle, now: 1.3)
    let canvas = LightingMap.scopeII.canvasNames
    let lums = canvas.map { name in
        pixels[KeyboardProfile.scopeII.index(named: name)].luminance
    }
    #expect((lums.min() ?? 0) > 0)
    #expect((lums.max() ?? 0) > (lums.min() ?? 0))
}

@Test func meteorShowerKeepsFloorAndShowsHeads() {
    let pixels = canvasPixels(effect: .meteor, now: 1.1)
    let canvas = LightingMap.scopeII.canvasNames
    let lums = canvas.map { name in
        pixels[KeyboardProfile.scopeII.index(named: name)].luminance
    }
    let lo = lums.min() ?? 0
    let hi = lums.max() ?? 0
    #expect(lo > 0)
    #expect(hi > lo * 2)
}

@Test func flowHasDriftingCrests() {
    let pixels = canvasPixels(effect: .flow, now: 0.9)
    let canvas = LightingMap.scopeII.canvasNames
    let lums = canvas.map { name in
        pixels[KeyboardProfile.scopeII.index(named: name)].luminance
    }
    #expect((lums.max() ?? 0) > (lums.min() ?? 0))
}

@Test func rainFallsInColumns() {
    let pixels = canvasPixels(effect: .rain, now: 0.7)
    let canvas = LightingMap.scopeII.canvasNames
    let lums = canvas.map { name in
        pixels[KeyboardProfile.scopeII.index(named: name)].luminance
    }
    let lo = lums.min() ?? 0
    #expect(lo > 0)
    #expect((lums.max() ?? 0) > lo)
}

@Test func spatialEffectFallsBackToBreathingOnSingleKey() {
    var dashboard = Dashboard()
    try? dashboard.apply(AgentEvent(agent: "codex", status: .running), now: 0)
    let pixels = SceneRenderer.renderBoard(
        dashboard,
        looks: AgentLookBook.seeded(),
        now: AK.glyphHoldSeconds + 0.2
    )
    let f1 = pixels[KeyboardProfile.scopeII.index(named: "F1")]
    #expect(f1.luminance > 20)
}
