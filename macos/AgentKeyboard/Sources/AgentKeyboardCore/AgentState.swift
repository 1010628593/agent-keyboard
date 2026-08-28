import Foundation

public enum AgentStatus: String, CaseIterable, Sendable, Equatable, Identifiable {
    case idle
    case running
    case tool
    case approval
    case done
    case error

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .idle: "Idle"
        case .running: "Running"
        case .tool: "Tool"
        case .approval: "Approval"
        case .done: "Done"
        case .error: "Error"
        }
    }

    public var displayTitle: String {
        switch self {
        case .running: "Thinking"
        default: title
        }
    }

    public var symbol: String {
        switch self {
        case .idle: "circle"
        case .running: "ellipsis.circle.fill"
        case .tool: "wrench.and.screwdriver.fill"
        case .approval: "hand.raised.fill"
        case .done: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    public static func parse(_ raw: String) -> AgentStatus? {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
        switch key {
        case "idle": return .idle
        case "thinking", "running": return .running
        case "tool", "tool_calling", "tool-calling": return .tool
        case "approval", "waiting_approval", "waiting-approval": return .approval
        case "done", "completed", "complete": return .done
        case "error", "failed": return .error
        default: return nil
        }
    }
}

public struct AgentSpec: Hashable, Sendable, Identifiable, Equatable {
    public var id: String { slot }
    public var slot: String
    public var agentID: String
    public var name: String
    public var keyName: String

    public init(slot: String, agentID: String, name: String, keyName: String) {
        self.slot = slot
        self.agentID = agentID
        self.name = name
        self.keyName = keyName
    }

    public static let defaults: [AgentSpec] = [
        .init(slot: "f1", agentID: "codex", name: "Codex", keyName: "F1"),
        .init(slot: "f2", agentID: "claude", name: "Claude Code", keyName: "F2"),
        .init(slot: "f3", agentID: "hermes", name: "Hermes", keyName: "F3"),
        .init(slot: "f4", agentID: "cursor", name: "Cursor", keyName: "F4"),
        .init(slot: "f5", agentID: "pi", name: "Pi", keyName: "F5"),
        .init(slot: "f6", agentID: "workbuddy", name: "Workbuddy", keyName: "F6"),
    ]

    public static let legacyIDs: [String: String] = [
        "spring": "hermes",
        "data": "cursor",
        "browser": "pi",
        "local": "workbuddy",
    ]
}

public struct AgentSlot: Hashable, Sendable, Identifiable, Equatable {
    public var id: String { spec.slot }
    public var spec: AgentSpec
    public var status: AgentStatus = .idle
    public var context: Double = 0
    public var progress: Double?
    public var message: String = ""
    public var doneUntil: TimeInterval?
    public var lastEventAt: TimeInterval?
    public var glyphUntil: TimeInterval?

    public init(spec: AgentSpec) {
        self.spec = spec
    }

    public var fill: Double {
        clamp01(progress ?? context)
    }

    public var isAssigned: Bool { !spec.agentID.isEmpty }

    public var estimatedTokens: Int {
        Int((context * Double(AK.tokenBudget)).rounded())
    }

    public var profile: AgentProfile {
        spec.profile
    }
}

public struct AgentEvent: Equatable, Sendable {
    public var agent: String
    public var status: AgentStatus?
    public var context: Double?
    public var progress: Double?
    public var message: String?

    public init(
        agent: String,
        status: AgentStatus? = nil,
        context: Double? = nil,
        progress: Double? = nil,
        message: String? = nil
    ) {
        self.agent = agent
        self.status = status
        self.context = context
        self.progress = progress
        self.message = message
    }
}

public struct Dashboard: Equatable, Sendable {
    public var slots: [AgentSlot]

    public init(specs: [AgentSpec] = AgentSpec.defaults) {
        slots = specs.map(AgentSlot.init)
    }

    public mutating func apply(_ event: AgentEvent, now: TimeInterval) throws {
        guard let index = resolveIndex(event.agent) else {
            throw DashboardError.unknownAgent(event.agent)
        }
        if let status = event.status {
            let previous = slots[index].status
            slots[index].status = status
            slots[index].doneUntil = status == .done ? now + AK.doneHoldSeconds : nil
            if status == .running, previous != .running {
                slots[index].glyphUntil = now + AK.glyphHoldSeconds
            } else if status != .running {
                slots[index].glyphUntil = nil
            }
        }
        if let context = event.context {
            slots[index].context = clamp01(context)
        }
        if let progress = event.progress {
            slots[index].progress = clamp01(progress)
        }
        if let message = event.message {
            slots[index].message = message
        }
        slots[index].lastEventAt = now
    }

    public mutating func tick(now: TimeInterval, idleTimeout: TimeInterval = AK.defaultIdleTimeout) {
        for i in slots.indices {
            if slots[i].status == .done,
               let until = slots[i].doneUntil,
               now >= until
            {
                slots[i].status = .idle
                slots[i].doneUntil = nil
                slots[i].glyphUntil = nil
                slots[i].message = ""
            } else if idleTimeout > 0,
                      slots[i].status != .idle,
                      slots[i].status != .done,
                      let last = slots[i].lastEventAt,
                      now - last >= idleTimeout
            {
                slots[i].status = .idle
                slots[i].glyphUntil = nil
                slots[i].message = ""
            }
        }
    }

    public mutating func assign(agentID: String, to slotID: String) {
        guard let dest = slots.firstIndex(where: { $0.spec.slot == slotID }) else { return }
        guard let profile = AgentProfile.named(agentID) else { return }
        if let src = slots.firstIndex(where: { $0.spec.agentID == agentID && $0.spec.slot != slotID }) {
            clearAssignment(at: src)
        }
        slots[dest].spec.agentID = profile.id
        slots[dest].spec.name = profile.name
        slots[dest].status = .idle
        slots[dest].context = 0
        slots[dest].progress = nil
        slots[dest].message = ""
    }

    /// Swap the agents occupying two slots (F1–F6). Slot identity and key names stay put.
    public mutating func swapAssignments(slotA: String, slotB: String) {
        guard slotA != slotB,
              let a = slots.firstIndex(where: { $0.spec.slot == slotA }),
              let b = slots.firstIndex(where: { $0.spec.slot == slotB })
        else { return }
        let agentID = slots[a].spec.agentID
        let name = slots[a].spec.name
        slots[a].spec.agentID = slots[b].spec.agentID
        slots[a].spec.name = slots[b].spec.name
        slots[b].spec.agentID = agentID
        slots[b].spec.name = name
        for index in [a, b] {
            slots[index].status = .idle
            slots[index].context = 0
            slots[index].progress = nil
            slots[index].message = ""
            slots[index].lastEventAt = nil
            slots[index].glyphUntil = nil
            slots[index].doneUntil = nil
        }
    }

    public mutating func unassign(slotID: String) {
        guard let index = slots.firstIndex(where: { $0.spec.slot == slotID }) else { return }
        clearAssignment(at: index)
    }

    public mutating func resetAssignments() {
        slots = AgentSpec.defaults.map(AgentSlot.init)
    }

    public func slot(forAgentID agentID: String) -> AgentSlot? {
        slots.first { $0.spec.agentID == agentID }
    }

    public func resolve(_ agent: String) -> AgentSlot? {
        guard let index = resolveIndex(agent) else { return nil }
        return slots[index]
    }

    public func any(_ statuses: AgentStatus...) -> Bool {
        slots.contains { statuses.contains($0.status) }
    }

    public var onlineKeyNames: Set<String> {
        Set(slots.filter { $0.isAssigned && $0.status != .idle }.map(\.spec.keyName))
    }

    public var primary: AgentSlot? {
        let rank: [AgentStatus: Int] = [
            .error: 0, .approval: 1, .tool: 2, .running: 3, .done: 4, .idle: 5,
        ]
        return slots
            .filter { $0.status != .idle }
            .min { a, b in
                let ra = rank[a.status] ?? 9
                let rb = rank[b.status] ?? 9
                if ra != rb { return ra < rb }
                return a.spec.keyName < b.spec.keyName
            }
    }

    private func resolveIndex(_ agent: String) -> Int? {
        var key = agent.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if key.hasPrefix("f"), let n = Int(key.dropFirst()) {
            key = "f\(n)"
        }
        if let mapped = AgentSpec.legacyIDs[key] {
            key = mapped
        }
        return slots.firstIndex {
            $0.spec.slot == key
                || (!$0.spec.agentID.isEmpty && $0.spec.agentID.lowercased() == key)
                || $0.spec.keyName.lowercased() == key
        }
    }

    private mutating func clearAssignment(at index: Int) {
        slots[index].spec.agentID = ""
        slots[index].spec.name = "Unassigned"
        slots[index].status = .idle
        slots[index].context = 0
        slots[index].progress = nil
        slots[index].message = ""
        slots[index].lastEventAt = nil
        slots[index].glyphUntil = nil
    }
}

public struct AgentProfile: Hashable, Sendable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var summary: String
    public var provider: String
    public var symbol: String
    public var modelName: String
    public var version: String
    public var prompt: String

    public static func named(_ id: String) -> AgentProfile? {
        catalog.first { $0.id == id }
    }

    public static let libraryIDs = ["codex", "claude", "hermes", "cursor", "workbuddy"]

    public static var library: [AgentProfile] {
        catalog.filter { libraryIDs.contains($0.id) }
    }

    public static let catalog: [AgentProfile] = [
        .init(
            id: "codex",
            name: "Codex",
            summary: "Writes, refactors, and explains code.",
            provider: "OpenAI",
            symbol: "chevron.left.forwardslash.chevron.right",
            modelName: "Codex",
            version: "GPT",
            prompt: "You are Codex, a precise coding assistant."
        ),
        .init(
            id: "claude",
            name: "Claude Code",
            summary: "Reasoning and code collaboration.",
            provider: "Anthropic",
            symbol: "bubble.left.and.bubble.right",
            modelName: "Claude",
            version: "Sonnet",
            prompt: "You are Claude Code, a careful software engineering agent."
        ),
        .init(
            id: "hermes",
            name: "Hermes",
            summary: "Fast actions and task automation.",
            provider: "Custom",
            symbol: "shield.fill",
            modelName: "Hermes 2.1",
            version: "v2.1.3",
            prompt: "You are Hermes, a helpful, reliable assistant. Be concise, accurate, and action-oriented."
        ),
        .init(
            id: "cursor",
            name: "Cursor",
            summary: "Editor-native AI pair programmer.",
            provider: "Cursor",
            symbol: "rectangle.and.pencil.and.ellipsis",
            modelName: "Cursor Agent",
            version: "Composer",
            prompt: "You are Cursor, an IDE agent that edits the current workspace."
        ),
        .init(
            id: "pi",
            name: "Pi",
            summary: "Personal productivity",
            provider: "Pi",
            symbol: "circle.grid.cross",
            modelName: "Pi",
            version: "Agent",
            prompt: "You are Pi, a personal productivity agent."
        ),
        .init(
            id: "workbuddy",
            name: "Workbuddy",
            summary: "Focus sessions and smart reminders.",
            provider: "Workbuddy",
            symbol: "checklist",
            modelName: "Workbuddy",
            version: "Agent",
            prompt: "You are Workbuddy, a task and workflow helper."
        ),
        .init(
            id: "browser",
            name: "Browser",
            summary: "Web research assistant",
            provider: "Research",
            symbol: "safari",
            modelName: "Browser",
            version: "—",
            prompt: "You are a web research assistant."
        ),
        .init(
            id: "local",
            name: "Local Model",
            summary: "On-device model",
            provider: "On-device",
            symbol: "cpu",
            modelName: "Local",
            version: "—",
            prompt: "You are a local on-device model."
        ),
    ]
}

public extension AgentSpec {
    var profile: AgentProfile {
        AgentProfile.named(agentID) ?? AgentProfile(
            id: agentID,
            name: name,
            summary: "Custom agent",
            provider: "Custom",
            symbol: "person.crop.circle",
            modelName: name,
            version: "—",
            prompt: "You are \(name)."
        )
    }
}

public enum DashboardError: Error, Equatable {
    case unknownAgent(String)
}

func clamp01(_ value: Double) -> Double {
    Swift.min(1, Swift.max(0, value))
}
