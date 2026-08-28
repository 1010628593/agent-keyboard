import Foundation

public enum RenderStyle: String, CaseIterable, Sendable, Equatable, Identifiable {
    case dashboard
    case cinematic

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .cinematic: "Cinematic"
        }
    }
}

public enum LightingScene: String, CaseIterable, Sendable, Equatable, Identifiable {
    case dashboard
    case wave
    case spectrum
    case breathing
    case cyber

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .wave: "Wave"
        case .spectrum: "Spectrum"
        case .breathing: "Breathing"
        case .cyber: "Cyber"
        }
    }

    public var symbol: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .wave: "water.waves"
        case .spectrum: "rainbow"
        case .breathing: "circle.dotted"
        case .cyber: "sparkles"
        }
    }
}

public enum LightingPreset: String, CaseIterable, Sendable, Equatable, Identifiable {
    case dashboard
    case focus
    case pulse
    case approval
    case error

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .focus: "Focus"
        case .pulse: "Pulse"
        case .approval: "Approval"
        case .error: "Error"
        }
    }

    public var symbol: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .focus: "scope"
        case .pulse: "waveform.path"
        case .approval: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }
}

public struct ZoneWash: Equatable, Sendable {
    public var target: LightingTarget
    public var color: RGB
    public var intensity: Double

    public init(target: LightingTarget, color: RGB, intensity: Double = 1) {
        self.target = target
        self.color = color
        self.intensity = intensity
    }
}

public enum SceneRenderer {
    public static func render(
        _ dashboard: Dashboard,
        now: TimeInterval,
        style: RenderStyle = .dashboard,
        idleWhite: Double = AK.defaultIdleWhite,
        map: LightingMap = .scopeII,
        scene: LightingScene = .dashboard,
        brightness: Double = 1,
        speed: Double = 1,
        wash: ZoneWash? = nil
    ) -> [RGB] {
        let t = now * Swift.max(0.25, speed)
        var fb = Framebuffer(map: map)
        switch scene {
        case .dashboard:
            fb.fill(RGB.white.scaled(idleWhite))
            paintClassic(fb: &fb, dashboard: dashboard, now: now, style: style)
        case .wave:
            paintWave(fb: &fb, now: t, idleWhite: idleWhite)
            paintAgentLamps(fb: &fb, dashboard: dashboard, now: t)
        case .spectrum:
            paintSpectrum(fb: &fb, now: t)
            paintAgentLamps(fb: &fb, dashboard: dashboard, now: t)
        case .breathing:
            let level = idleWhite * (0.45 + 0.55 * breath(t, period: 3.2))
            fb.fill(RGB.white.scaled(level))
            paintAgentLamps(fb: &fb, dashboard: dashboard, now: t)
        case .cyber:
            paintCyber(fb: &fb, now: t)
            paintAgentLamps(fb: &fb, dashboard: dashboard, now: t)
        }
        if let wash {
            apply(wash: wash, to: &fb)
        }
        if brightness < 0.999 {
            fb.pixels = fb.pixels.map { $0.scaled(brightness) }
        }
        return fb.pixels
    }

    public enum BoardPreview: Equatable, Sendable {
        case canvas(StateLook)
        case glyph(agentID: String, color: RGB)
    }

    public static func renderBoard(
        _ dashboard: Dashboard,
        looks: [String: [AgentStatus: StateLook]] = [:],
        now: TimeInterval,
        map: LightingMap = .scopeII,
        idleWhite: Double = AK.defaultIdleWhite,
        globalBrightness: Double = 1,
        pinnedCanvas: StateLook? = nil,
        preview: BoardPreview? = nil
    ) -> [RGB] {
        var fb = Framebuffer(map: map)
        fb.fill(RGB.white.scaled(idleWhite))
        let canvas = map.canvasNames
        let dim = RGB.white.scaled(idleWhite * 0.35)

        if case let .glyph(agentID, color) = preview {
            dimCanvas(&fb, names: canvas, dim: dim)
            paintGlyph(&fb, agentID: agentID, color: color)
        } else if case let .canvas(look) = preview {
            paintZone(&fb, names: canvas, look: look, now: now)
        } else if let primary = dashboard.primary,
                  let until = primary.glyphUntil,
                  now < until
        {
            dimCanvas(&fb, names: canvas, dim: dim)
            let color = AgentLookBook.look(
                agentID: primary.spec.agentID,
                status: .running,
                book: looks
            ).color.scaled(0.95)
            paintGlyph(&fb, agentID: primary.spec.agentID, color: color)
        } else if let pinnedCanvas {
            paintZone(&fb, names: canvas, look: pinnedCanvas, now: now)
        } else if let primary = dashboard.primary {
            let look = AgentLookBook.look(
                agentID: primary.spec.agentID,
                status: primary.status,
                book: looks
            )
            paintZone(&fb, names: canvas, look: look, now: now)
        }

        for slot in dashboard.slots where slot.isAssigned {
            var look = AgentLookBook.look(
                agentID: slot.spec.agentID,
                status: slot.status,
                book: looks
            )
            if slot.status == .idle {
                look.effect = .staticFill
                look.brightness = min(look.brightness, 0.08)
            }
            paintZone(&fb, names: [slot.spec.keyName], look: look, now: now)
        }

        if globalBrightness < 0.999 {
            fb.pixels = fb.pixels.map { $0.scaled(globalBrightness) }
        }
        return fb.pixels
    }

    private static func dimCanvas(_ fb: inout Framebuffer, names: [String], dim: RGB) {
        for name in names {
            fb.paint(name, dim, overlay: false)
        }
    }

    private static func paintGlyph(_ fb: inout Framebuffer, agentID: String, color: RGB) {
        let glyph = KeyGlyph.forAgent(agentID)
        for y in 0..<KeyGlyph.size {
            for x in 0..<KeyGlyph.size {
                guard glyph.lit(x: x, y: y) else { continue }
                let row = KeyGlyph.originRow + y
                let col = KeyGlyph.originCol + x
                for key in fb.map.profile.keys where key.row == row && key.col == col {
                    fb.set(key.index, color)
                }
            }
        }
    }

    private static func paintZone(
        _ fb: inout Framebuffer,
        names: [String],
        look: StateLook,
        now: TimeInterval
    ) {
        guard !names.isEmpty else { return }
        let t = now * Swift.max(0.25, look.speed)
        let base = look.color.scaled(look.brightness)
        switch look.effect {
        case .off:
            for name in names {
                fb.paint(name, RGB.white.scaled(0.03), overlay: false)
            }
        case .staticFill:
            for name in names {
                fb.paint(name, base)
            }
        case .breathing:
            let k = 0.35 + 0.65 * breath(t, period: 2.4)
            for name in names {
                fb.paint(name, base.scaled(k))
            }
        case .wave:
            let keys = names.flatMap { name in
                fb.map.profile.indices(named: name).map { fb.map.profile.key(at: $0) }
            }
            guard let lo = keys.map(\.col).min(), let hi = keys.map(\.col).max(), hi > lo else {
                for name in names { fb.paint(name, base) }
                return
            }
            let phase = (t * 0.28).truncatingRemainder(dividingBy: 1)
            for key in keys {
                let u = Double(key.col - lo) / Double(hi - lo)
                let dist = Swift.min(abs(u - phase), 1 - abs(u - phase))
                fb.overlay(key.index, base.scaled(Swift.max(0.12, 1 - dist * 3.2)))
            }
        case .reactive:
            let lit = Blink.isOn(t, period: 0.4)
            for name in names {
                fb.paint(name, lit ? base : base.scaled(0.14))
            }
        case .rainbow:
            for name in names {
                for index in fb.map.profile.indices(named: name) {
                    let key = fb.map.profile.key(at: index)
                    let hue = Double(key.col) / Double(Swift.max(1, fb.map.cols)) + t * 0.08
                    fb.set(key.index, RGB.hsv(hue).scaled(look.brightness))
                }
            }
        }
    }

    private static func paintClassic(
        fb: inout Framebuffer,
        dashboard: Dashboard,
        now: TimeInterval,
        style: RenderStyle
    ) {
        let map = fb.map
        let primary = dashboard.primary
        let doneSlots = dashboard.slots.filter { $0.status == .done }
        let error = dashboard.any(.error)
        let approval = dashboard.any(.approval)
        let running = dashboard.any(.running, .tool)
        let tool = dashboard.any(.tool)

        if style == .cinematic {
            renderCinematic(
                fb: &fb,
                dashboard: dashboard,
                now: now,
                primary: primary,
                doneSlots: doneSlots,
                error: error,
                approval: approval,
                running: running,
                tool: tool
            )
            return
        }

        paintAgentLamps(fb: &fb, dashboard: dashboard, now: now)
        if error {
            fb.paint(map.escape, Blink.isOn(now) ? RGB.error : RGB.error.scaled(0.12))
        }
        if approval {
            fb.paint(map.enter, RGB.approval.scaled(0.35 + 0.65 * breath(now, period: 1.8)))
        }
        if !doneSlots.isEmpty {
            let newest = doneSlots.max { ($0.doneUntil ?? 0) < ($1.doneUntil ?? 0) }!
            let remaining = (newest.doneUntil ?? now) - now
            let since = Swift.max(0, AK.doneHoldSeconds - remaining)
            paintSpaceFlow(&fb, color: .done, now: now, speed: 1.4)
            paintGreenSweep(&fb, since: since)
        } else if tool {
            paintSpaceFlow(&fb, color: .tool, now: now, speed: 0.9)
        } else if running {
            paintSpaceFlow(&fb, color: .running, now: now)
        }
        if running {
            paintArrows(&fb, color: tool ? .tool : .running, now: now)
        }
        if let source = primary ?? dashboard.slots.max(by: { $0.context < $1.context }),
           source.fill > 0 || source.context >= 0.80
        {
            let level = source.context >= 0.80 ? source.context : source.fill
            paintNumpad(&fb, level: level)
        }
    }

    private static func paintAgentLamps(fb: inout Framebuffer, dashboard: Dashboard, now: TimeInterval) {
        for slot in dashboard.slots {
            paintAgentLamp(&fb, slot: slot, now: now)
        }
    }

    private static func paintWave(fb: inout Framebuffer, now: TimeInterval, idleWhite: Double) {
        fb.fill(RGB.white.scaled(idleWhite * 0.6))
        let phase = (now * 0.28).truncatingRemainder(dividingBy: 1)
        for key in fb.map.profile.keys {
            let t = Double(key.col) / Double(Swift.max(1, fb.map.cols - 1))
            let dist = Swift.min(abs(t - phase), 1 - abs(t - phase))
            fb.overlay(key.index, RGB.running.scaled(Swift.max(0.08, 1 - dist * 3.2)))
        }
    }

    private static func paintSpectrum(fb: inout Framebuffer, now: TimeInterval) {
        for key in fb.map.profile.keys {
            let hue = Double(key.col) / Double(Swift.max(1, fb.map.cols)) + now * 0.06
            fb.set(key.index, RGB.hsv(hue).scaled(0.32))
        }
    }

    private static func paintCyber(fb: inout Framebuffer, now: TimeInterval) {
        let pulse = 0.14 + 0.08 * breath(now, period: 2.4)
        let mid = fb.map.cols / 2
        for key in fb.map.profile.keys {
            let color = key.col < mid ? RGB(0, 210, 255) : RGB(210, 40, 255)
            fb.set(key.index, color.scaled(pulse))
        }
    }

    private static func apply(wash: ZoneWash, to fb: inout Framebuffer) {
        let names = fb.map.names(for: wash.target)
        let color = wash.color.scaled(wash.intensity)
        for name in names {
            fb.paint(name, color)
        }
    }

    private static func renderCinematic(
        fb: inout Framebuffer,
        dashboard: Dashboard,
        now: TimeInterval,
        primary: AgentSlot?,
        doneSlots: [AgentSlot],
        error: Bool,
        approval: Bool,
        running: Bool,
        tool: Bool
    ) {
        let map = fb.map
        for name in map.fRow {
            fb.paint(name, .black, overlay: false)
        }
        for slot in dashboard.slots {
            paintAgentLamp(&fb, slot: slot, now: now)
        }
        if !doneSlots.isEmpty {
            let newest = doneSlots.max { ($0.doneUntil ?? 0) < ($1.doneUntil ?? 0) }!
            let remaining = (newest.doneUntil ?? now) - now
            paintGreenSweep(&fb, since: Swift.max(0, AK.doneHoldSeconds - remaining))
            return
        }
        if error {
            fb.paint(map.escape, Blink.isOn(now) ? RGB.error : .black)
            return
        }
        if approval {
            let glow = RGB.approval.scaled(0.35 + 0.65 * breath(now, period: 1.8))
            fb.paint(map.escape, glow)
            fb.paint(map.enter, glow)
            for name in map.fRow {
                fb.paint(name, glow.scaled(0.55))
            }
            return
        }
        if tool {
            paintSpaceFlow(&fb, color: .tool, now: now, speed: 0.9)
            for name in map.toolCluster {
                fb.paint(name, RGB.tool.scaled(pulse(now, period: 1.0) * 0.7))
            }
            return
        }
        if running {
            paintSpaceFlow(&fb, color: .running, now: now)
            let flow = (now * 0.35).truncatingRemainder(dividingBy: 1)
            for (i, name) in map.fRow.enumerated() {
                let t = Double(i) / Double(Swift.max(1, map.fRow.count - 1))
                let dist = Swift.min(abs(t - flow), 1 - abs(t - flow))
                fb.paint(name, RGB.running.scaled(Swift.max(0.12, 1 - dist * 4)))
            }
            return
        }
        if let source = primary ?? dashboard.slots.max(by: { $0.context < $1.context }),
           source.context >= 0.80
        {
            paintNumpad(&fb, level: source.context)
        }
    }
}

struct Framebuffer {
    let map: LightingMap
    var pixels: [RGB]

    init(map: LightingMap = .scopeII) {
        self.map = map
        pixels = Array(repeating: .black, count: map.ledCount)
    }

    mutating func fill(_ color: RGB) {
        pixels = Array(repeating: color, count: pixels.count)
    }

    mutating func overlay(_ index: Int, _ color: RGB) {
        pixels[index] = pixels[index].max(with: color)
    }

    mutating func set(_ index: Int, _ color: RGB) {
        pixels[index] = color
    }

    mutating func paint(_ name: String, _ color: RGB, overlay: Bool = true) {
        for index in map.profile.indices(named: name) {
            if overlay {
                self.overlay(index, color)
            } else {
                set(index, color)
            }
        }
    }
}

private enum Blink {
    static func isOn(_ now: TimeInterval, period: Double = 0.4) -> Bool {
        now.truncatingRemainder(dividingBy: period) < period * 0.5
    }
}

private func breath(_ now: TimeInterval, period: Double) -> Double {
    0.5 + 0.5 * sin(now * (2 * .pi / period))
}

private func pulse(_ now: TimeInterval, period: Double) -> Double {
    0.35 + 0.65 * breath(now, period: period)
}

private func statusColor(_ status: AgentStatus, now: TimeInterval) -> RGB? {
    switch status {
    case .idle: nil
    case .running: .running
    case .tool: RGB.tool.scaled(pulse(now, period: 1.1))
    case .approval: RGB.approval.scaled(0.35 + 0.65 * breath(now, period: 1.8))
    case .done: .done
    case .error: Blink.isOn(now) ? .error : RGB.error.scaled(0.15)
    }
}

private func contextColor(_ level: Double) -> RGB {
    if level >= 0.95 { return .contextHot }
    if level >= 0.80 { return RGB.lerp(.contextWarn, .contextHot, (level - 0.80) / 0.20) }
    if level >= 0.40 { return RGB.lerp(.contextOK, .contextWarn, (level - 0.40) / 0.40) }
    return RGB.contextOK.scaled(0.55 + 0.45 * level / 0.40)
}

private func paintAgentLamp(_ fb: inout Framebuffer, slot: AgentSlot, now: TimeInterval) {
    if let color = statusColor(slot.status, now: now) {
        fb.paint(slot.spec.keyName, color)
    } else {
        fb.paint(slot.spec.keyName, .black, overlay: false)
    }
}

private func paintSpaceFlow(_ fb: inout Framebuffer, color: RGB, now: TimeInterval, speed: Double = 0.55) {
    let spaces = fb.map.profile.indices(named: fb.map.space).map { fb.map.profile.key(at: $0) }
    guard let lo = spaces.map(\.col).min(), let hi = spaces.map(\.col).max() else { return }
    let span = Swift.max(1, hi - lo)
    let phase = (now * speed).truncatingRemainder(dividingBy: 1)
    for key in spaces {
        let t = Double(key.col - lo) / Double(span)
        let dist = Swift.min(abs(t - phase), 1 - abs(t - phase))
        let intensity = Swift.max(0, 1 - dist * 2.4)
        fb.overlay(key.index, color.scaled(0.18 + 0.82 * intensity))
    }
}

private func paintGreenSweep(_ fb: inout Framebuffer, since: TimeInterval) {
    let t = since / AK.doneHoldSeconds
    guard t < 1 else { return }
    let head = t * Double(fb.map.cols + 4)
    for key in fb.map.profile.keys {
        let dist = abs(Double(key.col) - head)
        if dist < 3.5 {
            fb.overlay(key.index, RGB.done.scaled(Swift.max(0, 1 - dist / 3.5)))
        }
    }
}

private func paintArrows(_ fb: inout Framebuffer, color: RGB, now: TimeInterval) {
    let names = fb.map.arrows
    guard !names.isEmpty else { return }
    let idx = Int(now * 3) % names.count
    for (i, name) in names.enumerated() {
        fb.paint(name, color.scaled(i == idx ? 1 : 0.18))
    }
}

private func paintNumpad(_ fb: inout Framebuffer, level: Double) {
    guard level > 0 else { return }
    let color = contextColor(level)
    let bar = fb.map.numpadBar
    let filled = Swift.min(bar.count, Swift.max(1, Int((level * Double(bar.count)).rounded())))
    for (i, name) in bar.enumerated() {
        if i < filled {
            fb.paint(name, color)
        } else if level >= 0.80 {
            fb.paint(name, color.scaled(0.12))
        }
    }
}
