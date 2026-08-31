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

public enum LightingColorMode: String, Sendable, Equatable {
    case none
    case single
    case dual
    case gradient
    case spectrum
}

public enum LightingParameterKind: String, CaseIterable, Sendable, Equatable, Hashable, Identifiable {
    case speed
    case angle
    case width
    case density
    case tail
    case decay
    case minimumBrightness
    case randomColors
    case animated

    public var id: String { rawValue }
}

public struct LightingColorStop: Identifiable, Equatable, Sendable {
    public var id: String
    public var location: Double
    public var color: RGB

    public init(id: String = UUID().uuidString.lowercased(), location: Double, color: RGB) {
        self.id = id
        self.location = Self.clamp(location)
        self.color = color
    }

    public func dictionary() -> [String: Any] {
        [
            "id": id,
            "location": location,
            "r": Int(color.r),
            "g": Int(color.g),
            "b": Int(color.b),
        ]
    }

    public init?(dictionary row: [String: Any]) {
        guard let location = Self.doubleValue(row["location"]) else { return nil }
        let r = UInt8(clamping: Self.intValue(row["r"]) ?? 139)
        let g = UInt8(clamping: Self.intValue(row["g"]) ?? 92)
        let b = UInt8(clamping: Self.intValue(row["b"]) ?? 246)
        self.init(
            id: (row["id"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? UUID().uuidString.lowercased(),
            location: location,
            color: RGB(r, g, b)
        )
    }

    private static func clamp(_ value: Double) -> Double {
        Swift.min(1, Swift.max(0, value))
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

public struct LightingPalette: Equatable, Sendable {
    public var stops: [LightingColorStop]
    public var background: RGB?

    public init(stops: [LightingColorStop], background: RGB? = nil) {
        self.stops = Self.normalizedStops(stops)
        self.background = background
    }

    public init(color: RGB, background: RGB? = nil) {
        self.init(
            stops: [LightingColorStop(id: "primary", location: 0, color: color)],
            background: background
        )
    }

    public var primary: RGB {
        get { stops.first?.color ?? .white }
        set {
            if stops.isEmpty {
                stops = [LightingColorStop(id: "primary", location: 0, color: newValue)]
            } else {
                stops[0].color = newValue
            }
        }
    }

    public func color(at rawLocation: Double) -> RGB {
        guard let first = stops.first else { return .white }
        guard stops.count > 1 else { return first.color }
        let location = Swift.min(1, Swift.max(0, rawLocation))
        if location <= first.location { return first.color }
        if let last = stops.last, location >= last.location { return last.color }
        for pair in zip(stops, stops.dropFirst()) {
            let (left, right) = pair
            guard location >= left.location, location <= right.location else { continue }
            let span = Swift.max(0.0001, right.location - left.location)
            return RGB.lerp(left.color, right.color, (location - left.location) / span)
        }
        return stops.last?.color ?? first.color
    }

    public func dictionary() -> [String: Any] {
        var row: [String: Any] = [
            "stops": stops.map { $0.dictionary() },
        ]
        if let background {
            row["background"] = [
                "r": Int(background.r),
                "g": Int(background.g),
                "b": Int(background.b),
            ]
        }
        return row
    }

    public init?(dictionary row: [String: Any]) {
        guard let rawStops = row["stops"] as? [[String: Any]] else { return nil }
        let stops = rawStops.compactMap(LightingColorStop.init(dictionary:))
        guard !stops.isEmpty else { return nil }
        let background: RGB?
        if let raw = row["background"] as? [String: Any] {
            background = RGB(
                UInt8(clamping: Self.intValue(raw["r"]) ?? 0),
                UInt8(clamping: Self.intValue(raw["g"]) ?? 0),
                UInt8(clamping: Self.intValue(raw["b"]) ?? 0)
            )
        } else {
            background = nil
        }
        self.init(stops: stops, background: background)
    }

    public func normalized(for descriptor: LightingEffectDescriptor) -> LightingPalette {
        var result = self
        var uniqueIDs = Set<String>()
        result.stops = Self.normalizedStops(result.stops).map { stop in
            var stop = stop
            if stop.id.isEmpty || !uniqueIDs.insert(stop.id).inserted {
                stop.id = UUID().uuidString.lowercased()
                uniqueIDs.insert(stop.id)
            }
            return stop
        }
        if result.stops.isEmpty {
            result.stops = [LightingColorStop(id: "primary", location: 0, color: RGB(139, 92, 246))]
        }
        if result.stops.count > descriptor.maximumColorStops {
            result.stops = Array(result.stops.prefix(descriptor.maximumColorStops))
        }
        while result.stops.count < descriptor.minimumColorStops {
            let index = result.stops.count
            let hue = result.primary.hue + 0.16 * Double(index)
            result.stops.append(
                LightingColorStop(
                    id: UUID().uuidString.lowercased(),
                    location: Double(index) / Double(Swift.max(1, descriptor.minimumColorStops - 1)),
                    color: RGB.hsv(hue)
                )
            )
        }
        if result.stops.count > 1 {
            result.stops[0].location = 0
            result.stops[result.stops.count - 1].location = 1
        }
        if !descriptor.allowsBackground {
            result.background = nil
        } else if result.background == nil {
            result.background = .black
        }
        return result
    }

    private static func normalizedStops(_ stops: [LightingColorStop]) -> [LightingColorStop] {
        Array(stops.prefix(5)).map { stop in
            var stop = stop
            stop.location = Swift.min(1, Swift.max(0, stop.location))
            return stop
        }.sorted { lhs, rhs in
            if lhs.location == rhs.location { return lhs.id < rhs.id }
            return lhs.location < rhs.location
        }
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }
}

public struct LightingEffectParameters: Equatable, Sendable {
    public var angleDegrees: Double
    public var width: Double
    public var density: Double
    public var tail: Double
    public var decay: Double
    public var minimumBrightness: Double
    public var randomColors: Bool
    public var animated: Bool

    public init(
        angleDegrees: Double = 0,
        width: Double = 0.42,
        density: Double = 0.5,
        tail: Double = 0.45,
        decay: Double = 0.6,
        minimumBrightness: Double = 0.18,
        randomColors: Bool = false,
        animated: Bool = true
    ) {
        self.angleDegrees = angleDegrees
        self.width = width
        self.density = density
        self.tail = tail
        self.decay = decay
        self.minimumBrightness = minimumBrightness
        self.randomColors = randomColors
        self.animated = animated
        normalize()
    }

    public static func defaults(for effect: LightingEffect) -> LightingEffectParameters {
        effect.descriptor.defaultParameters
    }

    public mutating func normalize() {
        angleDegrees = angleDegrees.truncatingRemainder(dividingBy: 360)
        if angleDegrees < 0 { angleDegrees += 360 }
        width = Self.clamp(width)
        density = Self.clamp(density)
        tail = Self.clamp(tail)
        decay = Self.clamp(decay)
        minimumBrightness = Swift.min(0.8, Swift.max(0, minimumBrightness))
    }

    public func dictionary() -> [String: Any] {
        [
            "angleDegrees": angleDegrees,
            "width": width,
            "density": density,
            "tail": tail,
            "decay": decay,
            "minimumBrightness": minimumBrightness,
            "randomColors": randomColors,
            "animated": animated,
        ]
    }

    public init(dictionary row: [String: Any], effect: LightingEffect) {
        let defaults = Self.defaults(for: effect)
        self.init(
            angleDegrees: Self.doubleValue(row["angleDegrees"]) ?? defaults.angleDegrees,
            width: Self.doubleValue(row["width"]) ?? defaults.width,
            density: Self.doubleValue(row["density"]) ?? defaults.density,
            tail: Self.doubleValue(row["tail"]) ?? defaults.tail,
            decay: Self.doubleValue(row["decay"]) ?? defaults.decay,
            minimumBrightness: Self.doubleValue(row["minimumBrightness"]) ?? defaults.minimumBrightness,
            randomColors: Self.boolValue(row["randomColors"]) ?? defaults.randomColors,
            animated: Self.boolValue(row["animated"]) ?? defaults.animated
        )
    }

    private static func clamp(_ value: Double) -> Double {
        Swift.min(1, Swift.max(0, value))
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        return nil
    }
}

public struct LightingEffectDescriptor: Equatable, Sendable {
    public let colorMode: LightingColorMode
    public let minimumColorStops: Int
    public let maximumColorStops: Int
    public let allowsBackground: Bool
    public let defaultParameters: LightingEffectParameters
    public let defaultSpeed: Double
    public let parameters: [LightingParameterKind]

    public init(
        colorMode: LightingColorMode,
        minimumColorStops: Int = 1,
        maximumColorStops: Int = 1,
        allowsBackground: Bool = false,
        defaultParameters: LightingEffectParameters = .init(),
        defaultSpeed: Double = 1,
        parameters: [LightingParameterKind] = []
    ) {
        self.colorMode = colorMode
        self.minimumColorStops = Swift.min(5, Swift.max(1, minimumColorStops))
        self.maximumColorStops = Swift.min(5, Swift.max(self.minimumColorStops, maximumColorStops))
        self.allowsBackground = allowsBackground
        self.defaultParameters = defaultParameters
        self.defaultSpeed = Swift.min(2.5, Swift.max(0.4, defaultSpeed))
        self.parameters = parameters
    }

    public func range(for parameter: LightingParameterKind) -> ClosedRange<Double>? {
        guard parameters.contains(parameter) else { return nil }
        return switch parameter {
        case .speed: 0.4...2.5
        case .angle: 0...360
        case .minimumBrightness: 0...0.8
        case .width, .density, .tail, .decay: 0...1
        case .randomColors, .animated: nil
        }
    }
}

public extension LightingEffect {
    var descriptor: LightingEffectDescriptor {
        switch self {
        case .staticFill:
            .init(colorMode: .single, defaultParameters: .init(animated: false))
        case .breathing:
            .init(
                colorMode: .dual,
                maximumColorStops: 2,
                defaultParameters: .init(minimumBrightness: 0.18),
                parameters: [.minimumBrightness, .speed]
            )
        case .wave, .flow:
            .init(
                colorMode: .gradient,
                minimumColorStops: 2,
                maximumColorStops: 5,
                defaultParameters: .init(angleDegrees: 0, width: self == .wave ? 0.34 : 0.55),
                parameters: [.angle, .width, .speed]
            )
        case .ripple:
            .init(
                colorMode: .single,
                allowsBackground: true,
                defaultParameters: .init(width: 0.28, decay: 0.62),
                parameters: [.width, .decay, .speed]
            )
        case .comet:
            .init(
                colorMode: .gradient,
                minimumColorStops: 2,
                maximumColorStops: 5,
                defaultParameters: .init(angleDegrees: 0, width: 0.26, tail: 0.55),
                defaultSpeed: 1.1,
                parameters: [.angle, .tail, .speed]
            )
        case .meteor, .rain:
            .init(
                colorMode: .single,
                allowsBackground: true,
                defaultParameters: self == .meteor
                    ? .init(angleDegrees: 145, density: 0.48, tail: 0.5)
                    : .init(angleDegrees: 90, density: 0.52, tail: 0.38),
                parameters: [.angle, .density, .tail, .speed]
            )
        case .scanner:
            .init(
                colorMode: .single,
                allowsBackground: true,
                defaultParameters: .init(angleDegrees: 0, width: 0.22),
                parameters: [.angle, .width, .speed]
            )
        case .sparkle:
            .init(
                colorMode: .single,
                allowsBackground: true,
                defaultParameters: .init(density: 0.46, randomColors: false),
                parameters: [.density, .randomColors, .speed]
            )
        case .aurora:
            .init(
                colorMode: .gradient,
                minimumColorStops: 2,
                maximumColorStops: 5,
                defaultParameters: .init(angleDegrees: 0, width: 0.62),
                parameters: [.angle, .width, .speed]
            )
        case .gradient:
            .init(
                colorMode: .gradient,
                minimumColorStops: 2,
                maximumColorStops: 5,
                defaultParameters: .init(angleDegrees: 0, width: 1, animated: true),
                parameters: [.angle, .animated, .speed]
            )
        case .rainbow:
            .init(
                colorMode: .spectrum,
                defaultParameters: .init(angleDegrees: 0, width: 0.72),
                parameters: [.angle, .width, .speed]
            )
        case .heartbeat:
            .init(
                colorMode: .dual,
                maximumColorStops: 2,
                defaultParameters: .init(minimumBrightness: 0.14),
                parameters: [.minimumBrightness, .speed]
            )
        case .reactive:
            .init(
                colorMode: .single,
                allowsBackground: true,
                defaultParameters: .init(decay: 0.68),
                defaultSpeed: 2,
                parameters: [.decay, .speed]
            )
        case .off:
            .init(colorMode: .none, defaultParameters: .init(animated: false))
        }
    }
}

public struct StateLook: Equatable, Sendable {
    public var effect: LightingEffect
    public var palette: LightingPalette
    public var parameters: LightingEffectParameters
    public var brightness: Double
    public var speed: Double
    /// `nil` keeps the legacy whole-canvas behavior. An empty set is an
    /// intentional dark canvas; custom sets contain logical key names.
    public var selectedKeys: Set<String>?

    public init(
        effect: LightingEffect,
        color: RGB,
        brightness: Double = 0.7,
        speed: Double = 1,
        selectedKeys: Set<String>? = nil
    ) {
        self.effect = effect
        self.palette = LightingPalette(color: color).normalized(for: effect.descriptor)
        self.parameters = .defaults(for: effect)
        self.brightness = brightness
        self.speed = speed
        self.selectedKeys = selectedKeys
        normalize()
    }

    public init(
        effect: LightingEffect,
        palette: LightingPalette,
        parameters: LightingEffectParameters? = nil,
        brightness: Double = 0.7,
        speed: Double = 1,
        selectedKeys: Set<String>? = nil
    ) {
        self.effect = effect
        self.palette = palette
        self.parameters = parameters ?? .defaults(for: effect)
        self.brightness = brightness
        self.speed = speed
        self.selectedKeys = selectedKeys
        normalize()
    }

    public var color: RGB {
        get { palette.primary }
        set { palette.primary = newValue }
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
        var row: [String: Any] = [
            "effect": effect.rawValue,
            "r": Int(color.r),
            "g": Int(color.g),
            "b": Int(color.b),
            "brightness": brightness,
            "speed": speed,
            "palette": palette.dictionary(),
            "parameters": parameters.dictionary(),
        ]
        if let selectedKeys {
            row["selectedKeys"] = selectedKeys.sorted()
        }
        return row
    }

    public init?(dictionary row: [String: Any]) {
        guard let effectRaw = row["effect"] as? String,
              let effect = LightingEffect(rawValue: effectRaw)
        else { return nil }
        let r = UInt8(clamping: Self.intValue(row["r"]) ?? 139)
        let g = UInt8(clamping: Self.intValue(row["g"]) ?? 92)
        let b = UInt8(clamping: Self.intValue(row["b"]) ?? 246)
        let legacyColor = RGB(r, g, b)
        let palette = (row["palette"] as? [String: Any]).flatMap(LightingPalette.init(dictionary:))
            ?? LightingPalette(color: legacyColor)
        let parameters = (row["parameters"] as? [String: Any]).map {
            LightingEffectParameters(dictionary: $0, effect: effect)
        } ?? .defaults(for: effect)
        self.init(
            effect: effect,
            palette: palette,
            parameters: parameters,
            brightness: Self.doubleValue(row["brightness"]) ?? 0.7,
            speed: Self.doubleValue(row["speed"]) ?? 1,
            selectedKeys: Self.selectedKeysValue(row)
        )
    }

    public mutating func normalize() {
        brightness = Swift.min(1, Swift.max(0, brightness))
        speed = Swift.min(3, Swift.max(0.25, speed))
        parameters.normalize()
        palette = palette.normalized(for: effect.descriptor)
    }

    public func normalized() -> StateLook {
        var result = self
        result.normalize()
        return result
    }

    /// Resolves a stored mask against the active keyboard profile. This is the
    /// final safety boundary for stale names and the reserved F1-F6 lamps.
    public func resolvedCanvasNames(in map: LightingMap) -> [String] {
        guard let selectedKeys else { return map.canvasNames }
        return map.canvasNames.filter { selectedKeys.contains($0) }
    }

    private static func selectedKeysValue(_ row: [String: Any]) -> Set<String>? {
        guard row.keys.contains("selectedKeys") else { return nil }
        guard let names = row["selectedKeys"] as? [String] else { return nil }
        return Set(names)
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

public enum LightingSchemeKind: String, Sendable, Equatable {
    case builtIn
    case custom
}

public struct LightingScheme: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var kind: LightingSchemeKind
    public var look: StateLook

    public init(id: String, name: String, kind: LightingSchemeKind, look: StateLook) {
        self.id = id
        self.name = name
        self.kind = kind
        self.look = look.normalized()
    }

    public var isBuiltIn: Bool { kind == .builtIn }

    public func dictionary() -> [String: Any] {
        [
            "id": id,
            "name": name,
            "kind": kind.rawValue,
            "look": look.dictionary(),
        ]
    }

    public init?(dictionary row: [String: Any]) {
        guard let id = row["id"] as? String,
              !id.isEmpty,
              let name = row["name"] as? String,
              !name.isEmpty,
              let kindRaw = row["kind"] as? String,
              let kind = LightingSchemeKind(rawValue: kindRaw),
              let lookRow = row["look"] as? [String: Any],
              let look = StateLook(dictionary: lookRow)
        else { return nil }
        self.init(id: id, name: name, kind: kind, look: look)
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

public enum LightingSchemeLibrary {
    public static func builtInID(agentID: String, status: AgentStatus) -> String {
        "builtin.\(agentID).\(status.rawValue)"
    }

    public static func builtIns() -> [String: LightingScheme] {
        var schemes: [String: LightingScheme] = [:]
        for spec in AgentSpec.defaults {
            let looks = AgentLookBook.defaults(for: spec.agentID)
            for status in AgentStatus.allCases {
                guard let look = looks[status] else { continue }
                let id = builtInID(agentID: spec.agentID, status: status)
                schemes[id] = LightingScheme(
                    id: id,
                    name: "\(spec.name) · \(status.displayTitle)",
                    kind: .builtIn,
                    look: look
                )
            }
        }
        return schemes
    }

    public static func defaultAssignments() -> [String: [AgentStatus: String]] {
        var assignments: [String: [AgentStatus: String]] = [:]
        for spec in AgentSpec.defaults {
            assignments[spec.agentID] = Dictionary(
                uniqueKeysWithValues: AgentStatus.allCases.map { status in
                    (status, builtInID(agentID: spec.agentID, status: status))
                }
            )
        }
        return assignments
    }
}
