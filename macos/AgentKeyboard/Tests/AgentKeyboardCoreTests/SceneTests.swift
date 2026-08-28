import AgentKeyboardCore
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
