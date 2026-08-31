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
        case glyph(agentID: String, look: StateLook)
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

        if case let .glyph(agentID, look) = preview {
            paintGlyphPreview(&fb, agentID: agentID, look: look, canvas: canvas, dim: dim)
        } else if case let .canvas(look) = preview {
            paintCanvasLook(&fb, look: look, canvas: canvas, now: now)
        } else if let primary = dashboard.primary,
                  let until = primary.glyphUntil,
                  now < until
        {
            let look = AgentLookBook.look(
                agentID: primary.spec.agentID,
                status: .running,
                book: looks
            )
            paintGlyphPreview(&fb, agentID: primary.spec.agentID, look: look, canvas: canvas, dim: dim)
        } else if let pinnedCanvas {
            paintCanvasLook(&fb, look: pinnedCanvas, canvas: canvas, now: now)
        } else if let primary = dashboard.primary {
            let look = AgentLookBook.look(
                agentID: primary.spec.agentID,
                status: primary.status,
                book: looks
            )
            paintCanvasLook(&fb, look: look, canvas: canvas, now: now)
        }

        for slot in dashboard.slots where slot.isAssigned {
            var look = AgentLookBook.look(
                agentID: slot.spec.agentID,
                status: slot.status,
                book: looks
            )
            // Identity lamps inherit the scheme's state effect, brightness,
            // and first color only. Gradient stops/background colors remain
            // exclusive to the editable canvas.
            look.palette = LightingPalette(color: look.color)
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

    private static func paintCanvasLook(
        _ fb: inout Framebuffer,
        look: StateLook,
        canvas: [String],
        now: TimeInterval
    ) {
        dimCanvas(&fb, names: canvas, dim: .black)
        paintZone(&fb, names: look.resolvedCanvasNames(in: fb.map), look: look, now: now)
    }

    private static func paintGlyphPreview(
        _ fb: inout Framebuffer,
        agentID: String,
        look: StateLook,
        canvas: [String],
        dim: RGB
    ) {
        let selected = look.resolvedCanvasNames(in: fb.map)
        dimCanvas(&fb, names: canvas, dim: .black)
        dimCanvas(&fb, names: selected, dim: dim)
        paintGlyph(
            &fb,
            agentID: agentID,
            color: look.color.scaled(0.95),
            allowedNames: Set(selected)
        )
    }

    private static func paintGlyph(
        _ fb: inout Framebuffer,
        agentID: String,
        color: RGB,
        allowedNames: Set<String>
    ) {
        let glyph = KeyGlyph.forAgent(agentID)
        for y in 0..<KeyGlyph.size {
            for x in 0..<KeyGlyph.size {
                guard glyph.lit(x: x, y: y) else { continue }
                let row = KeyGlyph.originRow + y
                let col = KeyGlyph.originCol + x
                for key in fb.map.profile.keys where key.row == row && key.col == col {
                    guard allowedNames.contains(key.name) else { continue }
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
        let keys = names.flatMap { name in
            fb.map.profile.indices(named: name).map { fb.map.profile.key(at: $0) }
        }
        guard !keys.isEmpty else { return }

        // Spatial effects read poorly on a single-key zone (F1–F6 lamps);
        // downgrade them to a smooth breathing pulse there.
        var effect = look.effect
        let colSpan = (keys.map(\.col).max() ?? 0) - (keys.map(\.col).min() ?? 0)
        if effect.needsSpatialSpan, colSpan < 2 {
            effect = .breathing
        }
        let samples = spatialSamples(keys: keys, angleDegrees: look.parameters.angleDegrees)
        let background = (look.palette.background ?? .black).scaled(look.brightness)

        switch effect {
        case .off:
            for sample in samples {
                fb.set(sample.key.index, .black)
            }
        case .staticFill:
            for sample in samples {
                paintSample(&fb, sample: sample, color: look.color, intensity: 1, look: look, background: background)
            }
        case .breathing:
            let breath = easeBreath(t, period: 2.6)
            let intensity = look.parameters.minimumBrightness
                + (1 - look.parameters.minimumBrightness) * breath
            let color = look.palette.color(at: breath)
            for sample in samples {
                paintSample(&fb, sample: sample, color: color, intensity: intensity, look: look, background: background)
            }
        case .wave:
            let phase = fractional(t * 0.18)
            let sigma = 0.025 + look.parameters.width * 0.18
            for sample in samples {
                let glow = Swift.max(
                    gauss(wrapDist(sample.projected, phase), sigma),
                    0.62 * gauss(wrapDist(sample.projected, fractional(phase + 0.52)), sigma * 1.25)
                )
                let color = look.palette.color(at: fractional(sample.projected - phase + 0.5))
                paintSample(&fb, sample: sample, color: color, intensity: 0.06 + glow * 0.94, look: look, background: background)
            }
        case .ripple:
            let phase = fractional(t * 0.32)
            let sigma = 0.018 + look.parameters.width * 0.14
            let fade = 1 - phase * look.parameters.decay
            for sample in samples {
                let distance = hypot(sample.horizontal - 0.5, sample.vertical - 0.5) / 0.71
                let glow = gauss(distance - phase, sigma) * fade
                let color = look.palette.color(at: phase)
                paintSample(&fb, sample: sample, color: color, intensity: glow, look: look, background: background)
            }
        case .comet:
            let head = fractional(t * 0.22)
            let tail = 0.04 + look.parameters.tail * 0.55
            for sample in samples {
                let behind = fractional(head - sample.projected)
                let headGlow = gauss(wrapDist(sample.projected, head), 0.025)
                let tailGlow = behind < tail ? exp(-behind / Swift.max(0.02, tail * 0.35)) : 0
                let glow = Swift.max(headGlow, tailGlow)
                let color = look.palette.color(at: Swift.min(1, behind / tail))
                paintSample(&fb, sample: sample, color: color, intensity: glow, look: look, background: background)
            }
        case .meteor:
            paintParticles(
                &fb,
                samples: samples,
                look: look,
                background: background,
                t: t,
                verticalBias: false
            )
        case .flow:
            let scale = 2.5 + (1 - look.parameters.width) * 7
            for sample in samples {
                let shifted = fractional(sample.projected - t * 0.12)
                let crest = 0.5 + 0.5 * sin((sample.projected * scale + sample.perpendicular * 1.8 - t * 0.42) * 2 * .pi)
                let second = 0.5 + 0.5 * sin((sample.projected * scale * 1.7 - sample.perpendicular * 2.2 - t * 0.58 + 0.35) * 2 * .pi)
                let intensity = 0.12 + 0.88 * pow(crest * 0.65 + second * 0.35, 2)
                let color = look.palette.color(at: shifted)
                paintSample(&fb, sample: sample, color: color, intensity: intensity, look: look, background: background)
            }
        case .rain:
            paintParticles(
                &fb,
                samples: samples,
                look: look,
                background: background,
                t: t,
                verticalBias: true
            )
        case .scanner:
            let cycle = fractional(t * 0.22) * 2
            let head = cycle <= 1 ? cycle : 2 - cycle
            let sigma = 0.02 + look.parameters.width * 0.2
            for sample in samples {
                let glow = gauss(sample.projected - head, sigma)
                paintSample(&fb, sample: sample, color: look.color, intensity: glow, look: look, background: background)
            }
        case .sparkle:
            for sample in samples {
                let seed = hash01(sample.key.index &* 31 &+ 17)
                let active = seed <= 0.18 + look.parameters.density * 0.78
                let twinkle = active
                    ? pow(Swift.max(0, sin(t * (1.2 + seed * 2.8) + seed * 2 * .pi)), 6)
                    : 0
                let color = look.parameters.randomColors
                    ? RGB.hsv(seed + fractional(t * 0.025))
                    : look.palette.color(at: seed)
                paintSample(&fb, sample: sample, color: color, intensity: twinkle, look: look, background: background)
            }
        case .aurora:
            let scale = 1.5 + (1 - look.parameters.width) * 5
            for sample in samples {
                let drift = 0.08 * sin((sample.perpendicular * 2.4 + t * 0.13) * 2 * .pi)
                let location = fractional(sample.projected + drift - t * 0.035)
                let curtain = 0.5 + 0.5 * sin((sample.projected * scale + sample.perpendicular * 1.5 - t * 0.18) * 2 * .pi)
                let color = look.palette.color(at: location)
                paintSample(&fb, sample: sample, color: color, intensity: 0.22 + curtain * 0.78, look: look, background: background)
            }
        case .gradient:
            for sample in samples {
                let location = look.parameters.animated
                    ? fractional(sample.projected - t * 0.035)
                    : sample.projected
                let color = look.palette.color(at: location)
                paintSample(&fb, sample: sample, color: color, intensity: 1, look: look, background: background)
            }
        case .rainbow:
            let span = 0.35 + look.parameters.width * 1.65
            for sample in samples {
                let hue = sample.projected / span - t * 0.045
                paintSample(&fb, sample: sample, color: RGB.hsv(hue), intensity: 1, look: look, background: background)
            }
        case .heartbeat:
            let ph = t.truncatingRemainder(dividingBy: 1.7)
            let env = Swift.min(1, gauss(ph, 0.07) + 0.65 * gauss(ph - 0.26, 0.08))
            let intensity = look.parameters.minimumBrightness
                + (1 - look.parameters.minimumBrightness) * env
            let color = look.palette.color(at: env)
            for sample in samples {
                paintSample(&fb, sample: sample, color: color, intensity: intensity, look: look, background: background)
            }
        case .reactive:
            let ph = t.truncatingRemainder(dividingBy: 0.7) / 0.7
            let falloff = 2 + look.parameters.decay * 8
            let intensity = exp(-ph * falloff)
            for sample in samples {
                paintSample(&fb, sample: sample, color: look.color, intensity: intensity, look: look, background: background)
            }
        }
    }

    private struct LightingSpatialSample {
        let key: LedKey
        let horizontal: Double
        let vertical: Double
        let projected: Double
        let perpendicular: Double
    }

    private static func spatialSamples(keys: [LedKey], angleDegrees: Double) -> [LightingSpatialSample] {
        let loCol = keys.map(\.col).min() ?? 0
        let hiCol = keys.map(\.col).max() ?? loCol
        let loRow = keys.map(\.row).min() ?? 0
        let hiRow = keys.map(\.row).max() ?? loRow
        let colSpan = Double(Swift.max(1, hiCol - loCol))
        let rowSpan = Double(Swift.max(1, hiRow - loRow))
        let radians = angleDegrees * .pi / 180
        let cosine = cos(radians)
        let sine = sin(radians)
        let raw = keys.map { key -> (LedKey, Double, Double, Double, Double) in
            let horizontal = Double(key.col - loCol) / colSpan
            let vertical = Double(key.row - loRow) / rowSpan
            let projected = horizontal * cosine + vertical * sine
            let perpendicular = -horizontal * sine + vertical * cosine
            return (key, horizontal, vertical, projected, perpendicular)
        }
        let loProjected = raw.map { $0.3 }.min() ?? 0
        let hiProjected = raw.map { $0.3 }.max() ?? 1
        let loPerpendicular = raw.map { $0.4 }.min() ?? 0
        let hiPerpendicular = raw.map { $0.4 }.max() ?? 1
        let projectedSpan = Swift.max(0.0001, hiProjected - loProjected)
        let perpendicularSpan = Swift.max(0.0001, hiPerpendicular - loPerpendicular)
        return raw.map { item in
            LightingSpatialSample(
                key: item.0,
                horizontal: item.1,
                vertical: item.2,
                projected: (item.3 - loProjected) / projectedSpan,
                perpendicular: (item.4 - loPerpendicular) / perpendicularSpan
            )
        }
    }

    private static func paintSample(
        _ fb: inout Framebuffer,
        sample: LightingSpatialSample,
        color: RGB,
        intensity rawIntensity: Double,
        look: StateLook,
        background: RGB
    ) {
        let intensity = Swift.min(1, Swift.max(0, rawIntensity))
        let foreground = color.scaled(look.brightness)
        fb.set(sample.key.index, RGB.lerp(background, foreground, intensity))
    }

    private static func paintParticles(
        _ fb: inout Framebuffer,
        samples: [LightingSpatialSample],
        look: StateLook,
        background: RGB,
        t: TimeInterval,
        verticalBias: Bool
    ) {
        let particleCount = Swift.max(2, Int(2 + look.parameters.density * 10))
        let tail = 0.025 + look.parameters.tail * 0.3
        for sample in samples {
            var bestGlow = 0.0
            var bestColor = look.color
            for particle in 0..<particleCount {
                let seed = particle &* 104729 + (verticalBias ? 307 : 137)
                let lane = hash01(seed)
                let phase = fractional(t * (0.12 + hash01(seed + 11) * 0.1) + hash01(seed + 29))
                let along = fractional(phase - sample.projected)
                let laneSigma = verticalBias ? 0.055 : 0.075
                let laneGlow = gauss(sample.perpendicular - lane, laneSigma)
                let trailGlow = along < tail ? exp(-along / Swift.max(0.01, tail * 0.32)) : 0
                let headGlow = gauss(wrapDist(sample.projected, phase), 0.018)
                let glow = laneGlow * Swift.max(headGlow, trailGlow)
                if glow > bestGlow {
                    bestGlow = glow
                    bestColor = look.palette.color(at: hash01(seed + 47))
                }
            }
            paintSample(&fb, sample: sample, color: bestColor, intensity: bestGlow, look: look, background: background)
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

private func fractional(_ value: Double) -> Double {
    let result = value.truncatingRemainder(dividingBy: 1)
    return result < 0 ? result + 1 : result
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
