import AgentKeyboardCore
import Foundation
import Testing

@Test func newAgentsResolveOnFKeys() throws {
    var dashboard = Dashboard()
    try dashboard.apply(AgentEvent(agent: "hermes", status: .running), now: 0)
    #expect(dashboard.resolve("f3")?.status == .running)
    try dashboard.apply(AgentEvent(agent: "cursor", status: .tool), now: 0)
    #expect(dashboard.resolve("f4")?.status == .tool)
}

@Test func legacyIdsStillResolve() throws {
    var dashboard = Dashboard()
    try dashboard.apply(AgentEvent(agent: "spring", status: .running), now: 0)
    #expect(dashboard.resolve("hermes")?.status == .running)
    try dashboard.apply(AgentEvent(agent: "local", status: .running), now: 0)
    #expect(dashboard.resolve("workbuddy")?.status == .running)
}

@Test func watchdogReturnsToIdle() throws {
    var dashboard = Dashboard()
    try dashboard.apply(AgentEvent(agent: "codex", status: .running), now: 10)
    dashboard.tick(now: 11, idleTimeout: 5)
    #expect(dashboard.slots[0].status == .running)
    dashboard.tick(now: 16, idleTimeout: 5)
    #expect(dashboard.slots[0].status == .idle)
}

@Test func thinkingStartsGlyphWindow() throws {
    var dashboard = Dashboard()
    try dashboard.apply(AgentEvent(agent: "codex", status: .running), now: 4)
    #expect(dashboard.slots[0].glyphUntil == 4 + AK.glyphHoldSeconds)
    try dashboard.apply(AgentEvent(agent: "codex", status: .running), now: 4.2)
    #expect(dashboard.slots[0].glyphUntil == 4 + AK.glyphHoldSeconds)
    try dashboard.apply(AgentEvent(agent: "codex", status: .idle), now: 5)
    #expect(dashboard.slots[0].glyphUntil == nil)
}

@Test func hookMapperCoversLifecycle() {
    #expect(HookEventMapper.status(fromLifecycle: "SessionStart") == .running)
    #expect(HookEventMapper.status(fromLifecycle: "PreToolUse") == .tool)
    #expect(HookEventMapper.status(fromLifecycle: "PermissionRequest") == .approval)
    #expect(HookEventMapper.status(fromLifecycle: "Stop") == .done)
    #expect(HookEventMapper.status(fromLifecycle: "stop") == .done)
    #expect(HookEventMapper.status(fromLifecycle: "beforeSubmitPrompt") == .running)
    #expect(HookEventMapper.status(fromLifecycle: "afterAgentThought") == .running)
    #expect(HookEventMapper.status(fromLifecycle: "preToolUse") == .tool)
    #expect(HookEventMapper.status(fromLifecycle: "preToolUse", agent: "cursor") == .running)
    #expect(HookEventMapper.status(fromLifecycle: "preToolUse", agent: "codex") == .tool)
    #expect(HookEventMapper.resolvedAgent(declared: "claude", payload: #"{"cursor_version":"3.17.21"}"#) == "cursor")
    #expect(HookEventMapper.resolvedAgent(declared: "claude", payload: "{}") == "claude")
    #expect(HookEventMapper.status(fromLifecycle: "StopFailure") == .error)
}

@Test func parseEventRequiresAgent() {
    #expect(throws: BridgeError.invalidJSON) {
        _ = try EventBridge.parseEvent(Data("{}".utf8))
    }
}

@Test func parseEventMapsStatus() throws {
    let event = try EventBridge.parseEvent(Data(#"{"agent":"pi","status":"thinking"}"#.utf8))
    #expect(event.agent == "pi")
    #expect(event.status == .running)
}

@Test func tomlConfigLoadsSixAgents() throws {
    let text = """
    [[agents]]
    slot = "f1"
    id = "codex"
    name = "Codex"
    key = "F1"
    [[agents]]
    slot = "f6"
    id = "workbuddy"
    name = "Workbuddy"
    key = "F6"
    """
    let config = try AgentKeyboardConfig.parse(text)
    #expect(config.agents.count == 2)
    #expect(config.agents[1].agentID == "workbuddy")
}

@Test func agentCatalogHasEightProfiles() {
    #expect(AgentProfile.catalog.count == 8)
    #expect(AgentProfile.named("hermes")?.provider == "Custom")
    #expect(AgentProfile.named("browser") != nil)
}

@Test func assignMovesAgentBetweenSlots() {
    var dashboard = Dashboard()
    dashboard.assign(agentID: "hermes", to: "f1")
    #expect(dashboard.resolve("f1")?.spec.agentID == "hermes")
    #expect(dashboard.resolve("f3")?.spec.agentID.isEmpty == true)
    dashboard.resetAssignments()
    #expect(dashboard.resolve("f3")?.spec.agentID == "hermes")
}
