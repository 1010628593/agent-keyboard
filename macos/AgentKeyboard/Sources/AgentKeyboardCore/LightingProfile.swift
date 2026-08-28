import Foundation

public enum LightingEffect: String, CaseIterable, Sendable, Equatable, Identifiable {
    case staticFill = "static"
    case breathing
    case wave
    case ripple
    case comet
    case meteor
    case flow
    case rain
    case scanner
    case sparkle
    case aurora
    case gradient
    case rainbow
    case heartbeat
    case reactive
    case off

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .staticFill: "Static"
        case .breathing: "Breathing"
        case .wave: "Wave"
        case .ripple: "Ripple"
        case .comet: "Comet"
        case .meteor: "Meteor"
        case .flow: "Flow"
        case .rain: "Rain"
        case .scanner: "Scanner"
        case .sparkle: "Sparkle"
        case .aurora: "Aurora"
        case .gradient: "Gradient"
        case .rainbow: "Rainbow"
        case .heartbeat: "Heartbeat"
        case .reactive: "Reactive"
        case .off: "Off"
        }
    }

    public var symbol: String {
        switch self {
        case .staticFill: "circle.fill"
        case .breathing: "water.waves"
        case .wave: "waveform.path"
        case .ripple: "dot.radiowaves.right"
        case .comet: "sparkle"
        case .meteor: "sparkles"
        case .flow: "humidity.fill"
        case .rain: "cloud.rain.fill"
        case .scanner: "dot.scope"
        case .sparkle: "moon.stars.fill"
        case .aurora: "rays"
        case .gradient: "paintpalette.fill"
        case .rainbow: "rainbow"
        case .heartbeat: "waveform.path.ecg"
        case .reactive: "sun.max"
        case .off: "circle.slash"
        }
    }

    /// Spatial effects need a multi-key span to read correctly; on a single-key
    /// zone (e.g. an F1–F6 identity lamp) they fall back to breathing.
    public var needsSpatialSpan: Bool {
        switch self {
        case .wave, .ripple, .comet, .meteor, .flow, .rain, .scanner, .aurora, .gradient, .rainbow: true
        case .staticFill, .breathing, .sparkle, .heartbeat, .reactive, .off: false
        }
    }
}

public struct StateLook: Equatable, Sendable {
    public var effect: LightingEffect
    public var color: RGB
    public var brightness: Double
    public var speed: Double

    public init(
        effect: LightingEffect,
        color: RGB,
        brightness: Double = 0.7,
        speed: Double = 1
    ) {
        self.effect = effect
        self.color = color
        self.brightness = brightness
        self.speed = speed
    }

    public var paletteName: String {
        switch (color.r, color.g, color.b) {
        case (16, 185, 129): "Green"
        case (40, 90, 255): "Blue"
        case (139, 92, 246): "Purple"
        case (245, 158, 11): "Amber"
        case (20, 184, 166): "Teal"
        case (239, 68, 68): "Red"
        default: "Custom"
        }
    }

    public static let defaults: [AgentStatus: StateLook] = [
        .idle: .init(effect: .staticFill, color: RGB(40, 90, 255), brightness: 0.35, speed: 1),
        .running: .init(effect: .comet, color: RGB(139, 92, 246), brightness: 0.72, speed: 1.1),
        .tool: .init(effect: .ripple, color: RGB(245, 158, 11), brightness: 0.72, speed: 1.3),
        .approval: .init(effect: .heartbeat, color: RGB(20, 184, 166), brightness: 0.78, speed: 1),
        .done: .init(effect: .staticFill, color: RGB(16, 185, 129), brightness: 0.8, speed: 1),
        .error: .init(effect: .reactive, color: RGB(239, 68, 68), brightness: 0.9, speed: 2),
    ]

    public func dictionary() -> [String: Any] {
        [
            "effect": effect.rawValue,
            "r": Int(color.r),
            "g": Int(color.g),
            "b": Int(color.b),
            "brightness": brightness,
            "speed": speed,
        ]
    }

    public init?(dictionary row: [String: Any]) {
        guard let effectRaw = row["effect"] as? String,
              let effect = LightingEffect(rawValue: effectRaw)
        else { return nil }
        let r = UInt8(clamping: Self.intValue(row["r"]) ?? 139)
        let g = UInt8(clamping: Self.intValue(row["g"]) ?? 92)
        let b = UInt8(clamping: Self.intValue(row["b"]) ?? 246)
        self.init(
            effect: effect,
            color: RGB(r, g, b),
            brightness: Self.doubleValue(row["brightness"]) ?? 0.7,
            speed: Self.doubleValue(row["speed"]) ?? 1
        )
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }
}

public enum AgentLookBook {
    public static func seeded(
        overlay: [AgentStatus: StateLook]? = nil
    ) -> [String: [AgentStatus: StateLook]] {
        var book: [String: [AgentStatus: StateLook]] = [:]
        for spec in AgentSpec.defaults {
            var looks = defaults(for: spec.agentID)
            if let overlay {
                for (status, look) in overlay {
                    looks[status] = look
                }
            }
            book[spec.agentID] = looks
        }
        return book
    }

    public static func defaults(for agentID: String) -> [AgentStatus: StateLook] {
        let ink = signature(for: agentID)
        return [
            .idle: .init(effect: .staticFill, color: ink, brightness: 0.28, speed: 1),
            .running: .init(effect: .comet, color: ink, brightness: 0.75, speed: 1.1),
            .tool: .init(effect: .ripple, color: ink, brightness: 0.72, speed: 1.3),
            .approval: .init(effect: .heartbeat, color: ink, brightness: 0.8, speed: 1),
            .done: .init(effect: .staticFill, color: RGB(16, 185, 129), brightness: 0.8, speed: 1),
            .error: .init(effect: .reactive, color: RGB(239, 68, 68), brightness: 0.9, speed: 2),
        ]
    }

    public static func signature(for agentID: String) -> RGB {
        switch agentID {
        case "codex": RGB(139, 92, 246)
        case "claude": RGB(40, 90, 255)
        case "hermes": RGB(20, 184, 166)
        case "cursor": RGB(245, 158, 11)
        case "workbuddy": RGB(16, 185, 129)
        case "pi": RGB(236, 72, 153)
        default: RGB(139, 92, 246)
        }
    }

    public static func look(
        agentID: String,
        status: AgentStatus,
        book: [String: [AgentStatus: StateLook]]
    ) -> StateLook {
        book[agentID]?[status]
            ?? defaults(for: agentID)[status]
            ?? StateLook.defaults[status]
            ?? StateLook.defaults[.idle]!
    }
}
