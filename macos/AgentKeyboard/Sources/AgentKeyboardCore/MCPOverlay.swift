import Foundation

public enum OverlayMode: String, Sendable, Equatable {
    case overlay
    case replace
}

public enum OverlayError: Error, Equatable, LocalizedError, Sendable {
    case durationRequired
    case invalidDuration
    case invalidJSON
    case unknownKeys([String])
    case invalidColor(String)
    case emptyKeys
    case invalidMode
    case missingTimeline
    case invalidCue
    case invalidBrightness
    case invalidFPS
    case tooManyFrames
    case tooManyCues

    public var errorDescription: String? {
        switch self {
        case .durationRequired: "duration is required"
        case .invalidDuration: "duration must be greater than 0"
        case .invalidJSON: "invalid json"
        case .unknownKeys(let names):
            "unknown keys: \(names.joined(separator: ", ")). valid names: \(KeyName.uniqueNames.joined(separator: ", "))"
        case .invalidColor(let value): "invalid color: \(value)"
        case .emptyKeys: "keys must be a non-empty object of key name to color"
        case .invalidMode: "mode must be overlay or replace"
        case .missingTimeline: "frames or cues is required"
        case .invalidCue: "each cue needs at in [0, duration) and keys"
        case .invalidBrightness: "brightness must be a number between 0 and 1"
        case .invalidFPS: "fps must be greater than 0"
        case .tooManyFrames: "too many frames (max 64)"
        case .tooManyCues: "too many cues (max 32)"
        }
    }
}

public struct OverlayCue: Equatable, Sendable {
    public var at: TimeInterval
    public var pixels: [Int: RGB]
}

public struct MCPOverlay: Equatable, Sendable {
    public var mode: OverlayMode
    public var duration: TimeInterval
    public var startedAt: TimeInterval
    public var loop: Bool
    public var cues: [OverlayCue]
    public var period: TimeInterval
    public var requestedDuration: TimeInterval
    public var clamped: Bool
    public var brightness: Double
    public var names: [String]

    public func expired(now: TimeInterval) -> Bool {
        now - startedAt >= duration
    }

    public func remaining(now: TimeInterval) -> TimeInterval {
        max(0, duration - (now - startedAt))
    }

    public func pixels(at now: TimeInterval) -> [Int: RGB] {
        let elapsed = max(0, now - startedAt)
        let t = loop && period > 0 ? elapsed.truncatingRemainder(dividingBy: period) : elapsed
        var chosen = cues[0]
        for cue in cues {
            if cue.at <= t {
                chosen = cue
            } else {
                break
            }
        }
        guard brightness < 0.999 else { return chosen.pixels }
        return chosen.pixels.mapValues { $0.scaled(brightness) }
    }

    public func snapshot(now: TimeInterval) -> [String: Any] {
        if expired(now: now) {
            return ["active": false]
        }
        let current = pixels(at: now)
        return [
            "active": true,
            "mode": mode.rawValue,
            "keyCount": current.count,
            "remaining": (remaining(now: now) * 1000).rounded() / 1000,
            "duration": duration,
            "loop": loop,
            "clamped": clamped,
            "brightness": brightness,
            "keys": names,
        ]
    }

    public func composite(base: [RGB], now: TimeInterval) -> [RGB] {
        if expired(now: now) { return base }
        var out = mode == .replace ? Array(repeating: RGB.black, count: base.count) : base
        for (index, color) in pixels(at: now) where index >= 0 && index < out.count {
            out[index] = color
        }
        return out
    }

    public static func inactiveSnapshot() -> [String: Any] {
        ["active": false]
    }
}

public enum KeyName {
    private static let aliases: [String: String] = [
        "ESC": "ESCAPE",
        "ENTER": "ANSI_ENTER",
        "RETURN": "ANSI_ENTER",
        "CTRL": "LEFT_CONTROL",
        "CONTROL": "LEFT_CONTROL",
        "LEFT_CTRL": "LEFT_CONTROL",
        "RCTRL": "RIGHT_CONTROL",
        "RIGHT_CTRL": "RIGHT_CONTROL",
        "ALT": "LEFT_ALT",
        "OPTION": "LEFT_ALT",
        "RALT": "RIGHT_ALT",
        "RIGHT_OPTION": "RIGHT_ALT",
        "SHIFT": "LEFT_SHIFT",
        "RSHIFT": "RIGHT_SHIFT",
        "WIN": "LEFT_WINDOWS",
        "WINDOWS": "LEFT_WINDOWS",
        "SUPER": "LEFT_WINDOWS",
        "CMD": "LEFT_WINDOWS",
        "COMMAND": "LEFT_WINDOWS",
        "BKSP": "BACKSPACE",
        "BKSPC": "BACKSPACE",
        "DEL": "DELETE",
        "INS": "INSERT",
        "PGUP": "PAGE_UP",
        "PGDN": "PAGE_DOWN",
        "SPC": "SPACE",
        "SPACEBAR": "SPACE",
        "BACKSLASH": "ANSI_BACK_SLASH",
        "SLASH": "FORWARD_SLASH",
        "HYPHEN": "MINUS",
        "DASH": "MINUS",
        "EQUAL": "EQUALS",
        "GRAVE": "BACK_TICK",
        "BTICK": "BACK_TICK",
        "CAPS": "CAPS_LOCK",
        "PRNT": "PRINT_SCREEN",
        "SCRLK": "SCROLL_LOCK",
        "PAUSE": "PAUSE_BREAK",
        "NUMLK": "NUMPAD_LOCK",
        "NUMLOCK": "NUMPAD_LOCK",
        "UP": "UP_ARROW",
        "DOWN": "DOWN_ARROW",
        "LEFT": "LEFT_ARROW",
        "RIGHT": "RIGHT_ARROW",
        "FN": "RIGHT_FUNCTION",
        "LOGO": "Logo",
    ]

    private static let canonicalByUpper: [String: String] = {
        var map: [String: String] = [:]
        for key in KeyboardProfile.scopeII.keys {
            if map[key.name.uppercased()] == nil {
                map[key.name.uppercased()] = key.name
            }
        }
        return map
    }()

    public static var uniqueNames: [String] {
        var seen = Set<String>()
        var names: [String] = []
        for key in KeyboardProfile.scopeII.keys where seen.insert(key.name).inserted {
            names.append(key.name)
        }
        return names
    }

    public static var aliasMap: [String: String] { aliases }

    public static func resolve(_ raw: String) -> String? {
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        guard !token.isEmpty else { return nil }
        let upper = token.uppercased()
        let mapped = aliases[upper] ?? upper
        return canonicalByUpper[mapped.uppercased()]
    }
}

public enum OverlayParser {
    public static func layoutPayload() -> [String: Any] {
        [
            "ledCount": AK.ledCount,
            "rows": AK.matrixRows,
            "cols": AK.matrixCols,
            "keys": KeyboardProfile.scopeII.keys.map { key in
                [
                    "name": key.name,
                    "row": key.row,
                    "col": key.col,
                    "index": key.index,
                ] as [String: Any]
            },
            "aliases": KeyName.aliasMap,
        ]
    }

    public static func parseKeys(_ object: [String: Any], now: TimeInterval) throws -> MCPOverlay {
        let (duration, requested, clamped) = try parseDuration(object)
        let brightness = try parseBrightness(object)
        let pixels = try pixelsFromKeys(object["keys"])
        return MCPOverlay(
            mode: try parseMode(object),
            duration: duration,
            startedAt: now,
            loop: false,
            cues: [OverlayCue(at: 0, pixels: pixels)],
            period: duration,
            requestedDuration: requested,
            clamped: clamped,
            brightness: brightness,
            names: occupiedNames(in: pixels)
        )
    }

    public static func parseFrames(_ object: [String: Any], now: TimeInterval) throws -> MCPOverlay {
        let (duration, requested, clamped) = try parseDuration(object)
        let brightness = try parseBrightness(object)
        let loop = object["loop"] as? Bool ?? false
        let cues: [OverlayCue]
        let period: TimeInterval
        if object["cues"] != nil {
            cues = try parseCueList(from: object["cues"], duration: duration)
            period = periodForCues(cues, duration: duration)
        } else if let frames = object["frames"] as? [Any] {
            let fps = try parseFPS(object)
            cues = try cuesFromFrames(frames, fps: fps, duration: duration)
            period = fps > 0 ? TimeInterval(frames.count) / fps : duration
        } else {
            throw OverlayError.missingTimeline
        }
        var occupied: [Int: RGB] = [:]
        for cue in cues {
            occupied.merge(cue.pixels) { _, new in new }
        }
        return MCPOverlay(
            mode: try parseMode(object),
            duration: duration,
            startedAt: now,
            loop: loop,
            cues: cues,
            period: period > 0 ? period : duration,
            requestedDuration: requested,
            clamped: clamped,
            brightness: brightness,
            names: occupiedNames(in: occupied)
        )
    }

    public static func parseJSON(_ data: Data) throws -> [String: Any] {
        let obj = try JSONSerialization.jsonObject(with: data.isEmpty ? Data("{}".utf8) : data)
        guard let dict = obj as? [String: Any] else { throw OverlayError.invalidJSON }
        return dict
    }

    private static func parseDuration(_ object: [String: Any]) throws -> (TimeInterval, TimeInterval, Bool) {
        guard object["duration"] != nil else { throw OverlayError.durationRequired }
        let requested = double(object["duration"])
        guard let requested, requested > 0 else { throw OverlayError.invalidDuration }
        let duration = min(requested, AK.mcpOverlayMaxSeconds)
        return (duration, requested, requested > AK.mcpOverlayMaxSeconds)
    }

    private static func parseBrightness(_ object: [String: Any]) throws -> Double {
        guard object["brightness"] != nil else { return 1 }
        guard let value = double(object["brightness"]) else { throw OverlayError.invalidBrightness }
        return min(1, max(0, value))
    }

    private static func parseMode(_ object: [String: Any]) throws -> OverlayMode {
        let raw = (object["mode"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "overlay"
        guard let mode = OverlayMode(rawValue: raw) else { throw OverlayError.invalidMode }
        return mode
    }

    private static func parseFPS(_ object: [String: Any]) throws -> Double {
        if object["fps"] == nil { return 8 }
        guard let fps = double(object["fps"]), fps > 0 else { throw OverlayError.invalidFPS }
        return fps
    }

    private static func pixelsFromKeys(_ raw: Any?) throws -> [Int: RGB] {
        guard let keys = raw as? [String: Any], !keys.isEmpty else { throw OverlayError.emptyKeys }
        var unknown: [String] = []
        var pixels: [Int: RGB] = [:]
        for (rawName, rawColor) in keys {
            guard let name = KeyName.resolve(rawName) else {
                unknown.append(rawName)
                continue
            }
            let color = try parseColor(rawColor)
            for index in KeyboardProfile.scopeII.indices(named: name) {
                pixels[index] = color
            }
        }
        if !unknown.isEmpty { throw OverlayError.unknownKeys(unknown) }
        if pixels.isEmpty { throw OverlayError.emptyKeys }
        return pixels
    }

    private static func parseColor(_ value: Any) throws -> RGB {
        var extra = 1.0
        var payload: Any = value
        if let object = value as? [String: Any] {
            extra = double(object["brightness"]) ?? 1
            if let color = object["color"] {
                payload = color
            } else if object["r"] != nil {
                payload = [object["r"] as Any, object["g"] as Any, object["b"] as Any]
            } else {
                throw OverlayError.invalidColor("object")
            }
        }
        let rgb = try parseColorValue(payload)
        let scale = min(1, max(0, extra))
        return scale >= 0.999 ? rgb : rgb.scaled(scale)
    }

    private static func parseColorValue(_ value: Any) throws -> RGB {
        if let text = value as? String {
            var hex = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if hex.hasPrefix("#") { hex.removeFirst() }
            if hex.count == 3 {
                hex = hex.map { "\($0)\($0)" }.joined()
            }
            guard hex.count == 6, let packed = UInt32(hex, radix: 16) else {
                throw OverlayError.invalidColor(text)
            }
            return RGB(
                UInt8((packed >> 16) & 0xFF),
                UInt8((packed >> 8) & 0xFF),
                UInt8(packed & 0xFF)
            )
        }
        if let list = value as? [Any], list.count >= 3,
           let r = intByte(list[0]), let g = intByte(list[1]), let b = intByte(list[2])
        {
            return RGB(r, g, b)
        }
        throw OverlayError.invalidColor(String(describing: value))
    }

    private static func parseCueList(from raw: Any?, duration: TimeInterval) throws -> [OverlayCue] {
        guard let items = raw as? [Any], !items.isEmpty else { throw OverlayError.invalidCue }
        if items.count > 32 { throw OverlayError.tooManyCues }
        var built: [OverlayCue] = []
        for item in items {
            guard let object = item as? [String: Any], object["at"] != nil,
                  let at = double(object["at"]), at >= 0, at < duration
            else { throw OverlayError.invalidCue }
            let pixels = try pixelsFromKeys(object["keys"])
            built.append(OverlayCue(at: at, pixels: pixels))
        }
        return built.sorted { $0.at < $1.at }
    }

    private static func cuesFromFrames(_ frames: [Any], fps: Double, duration: TimeInterval) throws -> [OverlayCue] {
        if frames.isEmpty { throw OverlayError.missingTimeline }
        if frames.count > 64 { throw OverlayError.tooManyFrames }
        let interval = 1 / fps
        var cues: [OverlayCue] = []
        for (index, frame) in frames.enumerated() {
            let at = TimeInterval(index) * interval
            if at >= duration { break }
            guard let object = frame as? [String: Any] else { throw OverlayError.emptyKeys }
            cues.append(OverlayCue(at: at, pixels: try pixelsFromKeys(object)))
        }
        if cues.isEmpty { throw OverlayError.missingTimeline }
        return cues
    }

    private static func periodForCues(_ cues: [OverlayCue], duration: TimeInterval) -> TimeInterval {
        guard cues.count > 1 else { return duration }
        let last = cues[cues.count - 1].at
        var gap = cues[1].at - cues[0].at
        if gap <= 0 {
            gap = duration > last ? duration - last : duration
        }
        let end = last + gap
        return end > 0 ? end : duration
    }

    private static func occupiedNames(in pixels: [Int: RGB]) -> [String] {
        KeyName.uniqueNames.filter { name in
            KeyboardProfile.scopeII.indices(named: name).contains { pixels[$0] != nil }
        }
    }

    private static func double(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let number = value as? Double { return number }
        if let number = value as? Int { return Double(number) }
        if let text = value as? String { return Double(text) }
        return nil
    }

    private static func intByte(_ value: Any?) -> UInt8? {
        guard let number = double(value) else { return nil }
        return UInt8(clamping: Int(number.rounded()))
    }
}
