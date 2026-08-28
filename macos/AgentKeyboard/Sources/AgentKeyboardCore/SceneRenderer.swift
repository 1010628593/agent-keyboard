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
        let keys = names.flatMap { name in
            fb.map.profile.indices(named: name).map { fb.map.profile.key(at: $0) }
        }
        guard !keys.isEmpty else { return }

        // Spatial effects read poorly on a single-key zone (F1–F6 lamps);
        // downgrade them to a smooth breathing pulse there.
        var effect = look.effect
        let loCol = keys.map(\.col).min() ?? 0
        let hiCol = keys.map(\.col).max() ?? 0
        if effect.needsSpatialSpan, hiCol - loCol < 2 {
            effect = .breathing
        }

        switch effect {
        case .off:
            for key in keys {
                fb.set(key.index, RGB.white.scaled(0.03))
            }
        case .staticFill:
            for key in keys {
                fb.overlay(key.index, base)
            }
        case .breathing:
            let k = 0.30 + 0.70 * easeBreath(t, period: 2.6)
            for key in keys {
                fb.overlay(key.index, base.scaled(k))
            }
        case .wave:
            paintZoneWave(&fb, keys: keys, base: base, t: t, loCol: loCol, hiCol: hiCol)
        case .ripple:
            paintZoneRipple(&fb, keys: keys, base: base, t: t)
        case .comet:
            paintZoneComet(&fb, keys: keys, base: base, t: t, loCol: loCol, hiCol: hiCol)
        case .meteor:
            paintZoneMeteor(&fb, keys: keys, base: base, t: t, loCol: loCol, hiCol: hiCol)
        case .flow:
            paintZoneFlow(&fb, keys: keys, base: base, t: t, loCol: loCol, hiCol: hiCol)
        case .rain:
            paintZoneRain(&fb, keys: keys, base: base, t: t, loCol: loCol, hiCol: hiCol)
        case .scanner:
            paintZoneScanner(&fb, keys: keys, base: base, t: t, loCol: loCol, hiCol: hiCol)
        case .sparkle:
            for key in keys {
                let h = hash01(key.index)
                let twinkle = pow(Swift.max(0, sin(t * (1.1 + h * 2.4) + h * 6.283)), 6)
                let color = RGB.lerp(base, .white, twinkle * 0.35)
                fb.overlay(key.index, color.scaled(0.14 + 0.86 * twinkle))
            }
        case .aurora:
            let hueBase = look.color.hue
            for key in keys {
                let hue = hueBase
                    + 0.10 * sin(Double(key.col) * 0.35 + t * 0.9)
                    + 0.05 * sin(Double(key.row) * 1.1 - t * 0.5)
                let curtain = 0.5 + 0.5 * sin(Double(key.col) * 0.22 - t * 0.7 + Double(key.row) * 0.5)
                let value = look.brightness * (0.30 + 0.70 * curtain)
                fb.set(key.index, RGB.hsv(hue, saturation: 0.75, value: value))
            }
        case .gradient:
            let hueBase = look.color.hue
            let span = Double(Swift.max(1, hiCol - loCol))
            let flow = easeBreath(t, period: 3.2)
            for key in keys {
                let u = Double(key.col - loCol) / span
                let hue = hueBase + (u - 0.5) * 0.22 + t * 0.03
                let value = look.brightness * (0.55 + 0.45 * flow)
                fb.set(key.index, RGB.hsv(hue, saturation: 0.8, value: value))
            }
        case .rainbow:
            for key in keys {
                let hue = Double(key.col) / Double(Swift.max(1, fb.map.cols))
                    + Double(key.row) * 0.03 + t * 0.07
                let value = look.brightness * (0.72 + 0.28 * easeBreath(t + Double(key.row) * 0.3, period: 3.4))
                fb.set(key.index, RGB.hsv(hue, saturation: 0.85, value: value))
            }
        case .heartbeat:
            let ph = t.truncatingRemainder(dividingBy: 1.7)
            let env = Swift.min(1, gauss(ph, 0.07) + 0.65 * gauss(ph - 0.26, 0.08))
            let k = 0.18 + 0.82 * env
            for key in keys {
                fb.overlay(key.index, base.scaled(k))
            }
        case .reactive:
            let ph = t.truncatingRemainder(dividingBy: 0.7) / 0.7
            let k = 0.12 + 0.88 * exp(-ph * 5.5)
            for key in keys {
                fb.overlay(key.index, base.scaled(k))
            }
        }
    }

    /// Diagonal double wave: a bright front sweeping left→right plus a fainter
    /// counter-wave, both with soft gaussian tails.
    private static func paintZoneWave(
        _ fb: inout Framebuffer,
        keys: [LedKey],
        base: RGB,
        t: TimeInterval,
        loCol: Int,
        hiCol: Int
    ) {
        let span = Double(Swift.max(1, hiCol - loCol)) + 2.7
        let p1 = (t * 0.22).truncatingRemainder(dividingBy: 1)
        let p2 = (0.5 - t * 0.13).truncatingRemainder(dividingBy: 1)
        for key in keys {
            let u = (Double(key.col - loCol) + Double(key.row) * 0.45) / span
            let glow = Swift.max(gauss(wrapDist(u, p1), 0.07), 0.7 * gauss(wrapDist(u, p2), 0.09))
            fb.overlay(key.index, base.scaled(Swift.max(0.10, glow)))
        }
    }

    /// Rings expanding from the zone center, fading as they reach the edge.
    private static func paintZoneRipple(
        _ fb: inout Framebuffer,
        keys: [LedKey],
        base: RGB,
        t: TimeInterval
    ) {
        let rows = keys.map(\.row)
        let cols = keys.map(\.col)
        let centerRow = Double((rows.min() ?? 0) + (rows.max() ?? 0)) / 2
        let centerCol = Double((cols.min() ?? 0) + (cols.max() ?? 0)) / 2
        let maxD = hypot(centerCol - Double(cols.min() ?? 0), centerRow - Double(rows.min() ?? 0))
        let phase = (t / 2.8).truncatingRemainder(dividingBy: 1)
        let radius = phase * (maxD + 2.5)
        let fade = 1 - phase * 0.75
        for key in keys {
            let d = hypot(Double(key.col) - centerCol, Double(key.row) - centerRow)
            let ring = gauss(d - radius, 0.9) * fade
            fb.overlay(key.index, base.scaled(Swift.max(0.12, ring)))
        }
    }

    /// A bright head sweeping left→right with a long exponential tail,
    /// then a dark gap before the next pass.
    private static func paintZoneComet(
        _ fb: inout Framebuffer,
        keys: [LedKey],
        base: RGB,
        t: TimeInterval,
        loCol: Int,
        hiCol: Int
    ) {
        let span = Double(Swift.max(1, hiCol - loCol))
        let tail = span * 0.45
        let travel = span + tail * 2
        let x = (t * 0.30).truncatingRemainder(dividingBy: 1) * travel - tail
        for key in keys {
            let d = Double(key.col - loCol) - x
            let glow = d >= 0 ? gauss(d, 0.55) : gauss(d, tail / 2.2)
            fb.overlay(key.index, base.scaled(Swift.max(0.15, glow)))
        }
    }

    /// KITT-style beam bouncing between the zone edges.
    private static func paintZoneScanner(
        _ fb: inout Framebuffer,
        keys: [LedKey],
        base: RGB,
        t: TimeInterval,
        loCol: Int,
        hiCol: Int
    ) {
        let span = Double(Swift.max(1, hiCol - loCol))
        let cycle = (t * 0.5).truncatingRemainder(dividingBy: 2)
        let pos = cycle <= 1 ? cycle : 2 - cycle
        let x = Double(loCol) + pos * span
        for key in keys {
            let glow = gauss(Double(key.col) - x, 1.3)
            fb.overlay(key.index, base.scaled(Swift.max(0.12, glow)))
        }
    }

    /// Meteor shower: several meteors fall diagonally (top-right → bottom-left)
    /// at once, each with its own period, track, and slope. Fully deterministic
    /// per meteor index, so the pattern is stable frame-to-frame.
    private static func paintZoneMeteor(
        _ fb: inout Framebuffer,
        keys: [LedKey],
        base: RGB,
        t: TimeInterval,
        loCol: Int,
        hiCol: Int
    ) {
        let rows = keys.map(\.row)
        let loRow = rows.min() ?? 0
        let hiRow = rows.max() ?? 0
        let span = Double(Swift.max(1, hiCol - loCol))
        let rowSpan = Double(Swift.max(1, hiRow - loRow))
        let track = span + 10
        let meteorCount = 3
        var glowAt = [Int: Double](minimumCapacity: keys.count)
        for m in 0..<meteorCount {
            let h1 = hash01(m &* 7919 &+ 11)
            let h2 = hash01(m &* 7919 &+ 137)
            let h3 = hash01(m &* 7919 &+ 521)
            let period = 2.0 + h1 * 1.8
            let phase = ((t / period) + h2).truncatingRemainder(dividingBy: 1)
            let x = span + 5 - phase * track
            let progress = (span + 5 - x) / track
            let headRow = Double(loRow) + progress * rowSpan * (0.45 + h3 * 0.55)
            for key in keys {
                let dx = Double(key.col - loCol) - x
                let dy = (Double(key.row) - headRow) * 2.2
                let along = dx > 0 ? gauss(hypot(dx, dy), 2.6) : gauss(hypot(dx, dy), 0.8)
                let fade = sin(.pi * Swift.min(1, Swift.max(0, progress)))
                let glow = along * (0.35 + 0.65 * fade)
                if glow > (glowAt[key.index] ?? 0) {
                    glowAt[key.index] = glow
                }
            }
        }
        for key in keys {
            fb.overlay(key.index, base.scaled(Swift.max(0.10, glowAt[key.index] ?? 0)))
        }
    }

    /// Water flow: two traveling sine layers interfere into drifting crests.
    /// Crest tips pick up a white highlight, troughs stay dim — reads as a
    /// moving water surface rather than a uniform wash.
    private static func paintZoneFlow(
        _ fb: inout Framebuffer,
        keys: [LedKey],
        base: RGB,
        t: TimeInterval,
        loCol: Int,
        hiCol: Int
    ) {
        let rows = keys.map(\.row)
        let loRow = rows.min() ?? 0
        let hiRow = rows.max() ?? 0
        let span = Double(Swift.max(1, hiCol - loCol))
        let rowSpan = Double(Swift.max(1, hiRow - loRow))
        for key in keys {
            let u = Double(key.col - loCol) / span
            let v = Double(key.row - loRow) / rowSpan
            let w1 = sin(u * 6.0 - t * 2.2 + v * 2.5)
            let w2 = sin(u * 11.0 - t * 3.1 + v * 5.0 + 1.7)
            let wave = (w1 * 0.6 + w2 * 0.4) * 0.5 + 0.5
            let crest = wave * wave * wave
            let color = RGB.lerp(base, .white, crest * 0.30)
            fb.overlay(key.index, color.scaled(0.20 + 0.80 * crest))
        }
    }

    /// Rain: drops fall down random columns with a short tail, fading out as
    /// they reach the bottom row. Deterministic per drop index.
    private static func paintZoneRain(
        _ fb: inout Framebuffer,
        keys: [LedKey],
        base: RGB,
        t: TimeInterval,
        loCol: Int,
        hiCol: Int
    ) {
        let rows = keys.map(\.row)
        let loRow = rows.min() ?? 0
        let hiRow = rows.max() ?? 0
        let span = Double(Swift.max(1, hiCol - loCol))
        let rowSpan = Double(Swift.max(1, hiRow - loRow))
        let dropCount = Swift.max(3, Int(span / 3))
        var glowAt = [Int: Double](minimumCapacity: keys.count)
        for d in 0..<dropCount {
            let h1 = hash01(d &* 104729 &+ 7)
            let h2 = hash01(d &* 104729 &+ 199)
            let h3 = hash01(d &* 104729 &+ 307)
            let col = Double(loCol) + h1 * span
            let period = 1.4 + h2 * 1.4
            let phase = ((t / period) + h3).truncatingRemainder(dividingBy: 1)
            let y = Double(loRow) - 1.5 + phase * (rowSpan + 3)
            let fade = 1 - phase * 0.6
            for key in keys {
                guard abs(Double(key.col) - col) < 0.6 else { continue }
                let dy = Double(key.row) - y
                let glow = (dy <= 0 ? gauss(dy, 1.1) : gauss(dy, 0.35)) * fade
                if glow > (glowAt[key.index] ?? 0) {
                    glowAt[key.index] = glow
                }
            }
        }
        for key in keys {
            fb.overlay(key.index, base.scaled(Swift.max(0.10, glowAt[key.index] ?? 0)))
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

/// Smoothstep-shaped breath: lingers at the bright/dark extremes instead of
/// sweeping through them, which reads as a more organic "inhale/hold/exhale".
private func easeBreath(_ now: TimeInterval, period: Double) -> Double {
    let x = 0.5 + 0.5 * sin(now * (2 * .pi / period))
    return x * x * (3 - 2 * x)
}

private func gauss(_ x: Double, _ sigma: Double) -> Double {
    let s = x / sigma
    return exp(-0.5 * s * s)
}

/// Distance on a 0..1 ring (wrap-around), used by sweeping effects.
private func wrapDist(_ a: Double, _ b: Double) -> Double {
    let d = abs(a - b)
    return Swift.min(d, 1 - d)
}

/// Deterministic pseudo-random in 0..1 per key, so sparkle patterns are
/// stable frame-to-frame without storing state.
private func hash01(_ n: Int) -> Double {
    let x = sin(Double(n) * 12.9898) * 43758.5453
    return x - x.rounded(.down)
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
