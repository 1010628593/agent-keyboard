import AgentKeyboardCore
import AppKit
import SwiftUI

struct KeyboardPreview: View {
    @Environment(\.colorScheme) private var scheme
    var pixels: [RGB]
    var map: LightingMap = .scopeII
    var highlight: Set<String> = []
    var locked: Set<String> = []

    var body: some View {
        Canvas { context, size in
            let (scale, origin) = Self.layout(in: size)
            let boardRect = CGRect(origin: origin, size: Self.boardSize.scaled(by: scale))
            drawChassis(in: &context, rect: boardRect, scale: scale)
            drawFrontLightReflection(in: &context, origin: origin, scale: scale)

            for key in Self.keys {
                drawKey(key, in: &context, origin: origin, scale: scale)
            }

            drawStatusStrip(in: &context, origin: origin, scale: scale)
            drawMultifunctionControls(in: &context, origin: origin, scale: scale)
        }
        .aspectRatio(Self.boardSize.width / Self.boardSize.height, contentMode: .fit)
        .accessibilityLabel(AKL("Keyboard lighting preview"))
        .accessibilityAddTraits(.isImage)
    }

    private func drawChassis(in context: inout GraphicsContext, rect: CGRect, scale: CGFloat) {
        let radius = 0.22 * scale
        let outer = Path(roundedRect: rect, cornerRadius: radius)
        context.fill(
            outer,
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.30, green: 0.305, blue: 0.315),
                    Color(red: 0.15, green: 0.153, blue: 0.162),
                    Color(red: 0.045, green: 0.046, blue: 0.052),
                ]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            )
        )
        context.stroke(
            outer,
            with: .color(scheme == .dark ? .white.opacity(0.23) : .black.opacity(0.42)),
            lineWidth: max(0.8, scale * 0.026)
        )

        let deck = rect.insetBy(dx: 0.10 * scale, dy: 0.10 * scale)
        context.fill(
            Path(roundedRect: deck, cornerRadius: 0.16 * scale),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.285, green: 0.29, blue: 0.302),
                    Color(red: 0.155, green: 0.158, blue: 0.17),
                ]),
                startPoint: CGPoint(x: deck.midX, y: deck.minY),
                endPoint: CGPoint(x: deck.midX, y: deck.maxY)
            )
        )
        context.stroke(
            Path(roundedRect: deck, cornerRadius: 0.16 * scale),
            with: .color(.white.opacity(0.075)),
            lineWidth: max(0.5, scale * 0.012)
        )

        for index in 0..<10 {
            let y = deck.minY + (0.28 + CGFloat(index) * 0.63) * scale
            var brush = Path()
            brush.move(to: CGPoint(x: deck.minX + 0.12 * scale, y: y))
            brush.addLine(to: CGPoint(x: deck.maxX - 0.12 * scale, y: y))
            context.stroke(
                brush,
                with: .color(.white.opacity(index.isMultiple(of: 2) ? 0.018 : 0.010)),
                lineWidth: max(0.35, scale * 0.006)
            )
        }

        let controlPlate = CGRect(x: 19.10, y: 0.20, width: 4.25, height: 1.16)
            .scaled(by: scale)
            .offsetBy(dx: rect.minX, dy: rect.minY)
        context.fill(
            Path(roundedRect: controlPlate, cornerRadius: 0.16 * scale),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.335, green: 0.34, blue: 0.35),
                    Color(red: 0.175, green: 0.178, blue: 0.19),
                ]),
                startPoint: CGPoint(x: controlPlate.midX, y: controlPlate.minY),
                endPoint: CGPoint(x: controlPlate.midX, y: controlPlate.maxY)
            )
        )
        context.stroke(
            Path(roundedRect: controlPlate, cornerRadius: 0.16 * scale),
            with: .color(.white.opacity(0.12)),
            lineWidth: max(0.55, scale * 0.014)
        )

        for index in 0..<5 {
            let y = controlPlate.minY + (0.21 + CGFloat(index) * 0.17) * scale
            var brush = Path()
            brush.move(to: CGPoint(x: controlPlate.minX + 0.18 * scale, y: y))
            brush.addLine(to: CGPoint(x: controlPlate.maxX - 0.16 * scale, y: y))
            context.stroke(
                brush,
                with: .color(.white.opacity(index.isMultiple(of: 2) ? 0.025 : 0.014)),
                lineWidth: max(0.35, scale * 0.006)
            )
        }

        let frontLip = CGRect(
            x: rect.minX + 0.11 * scale,
            y: rect.maxY - 0.27 * scale,
            width: rect.width - 0.22 * scale,
            height: 0.17 * scale
        )
        context.fill(
            Path(roundedRect: frontLip, cornerRadius: 0.075 * scale),
            with: .linearGradient(
                Gradient(colors: [.white.opacity(0.055), .black.opacity(0.62)]),
                startPoint: CGPoint(x: frontLip.midX, y: frontLip.minY),
                endPoint: CGPoint(x: frontLip.midX, y: frontLip.maxY)
            )
        )

        var frontEdge = Path()
        frontEdge.move(to: CGPoint(x: rect.minX + 0.24 * scale, y: rect.maxY - 0.25 * scale))
        frontEdge.addLine(to: CGPoint(x: rect.maxX - 0.24 * scale, y: rect.maxY - 0.25 * scale))
        context.stroke(frontEdge, with: .color(.white.opacity(0.13)), lineWidth: max(0.65, scale * 0.016))

        let cablePort = CGRect(x: 11.52, y: 0.015, width: 0.62, height: 0.11)
            .scaled(by: scale)
            .offsetBy(dx: rect.minX, dy: rect.minY)
        context.fill(
            Path(roundedRect: cablePort, cornerRadius: cablePort.height * 0.32),
            with: .color(.black.opacity(0.82))
        )
        var portHighlight = Path()
        portHighlight.move(to: CGPoint(x: cablePort.minX + 0.10 * scale, y: cablePort.maxY))
        portHighlight.addLine(to: CGPoint(x: cablePort.maxX - 0.10 * scale, y: cablePort.maxY))
        context.stroke(
            portHighlight,
            with: .color(.white.opacity(0.16)),
            lineWidth: max(0.45, scale * 0.01)
        )
    }

    private func drawFrontLightReflection(
        in context: inout GraphicsContext,
        origin: CGPoint,
        scale: CGFloat
    ) {
        let bottomKeys = Self.bottomGlowKeys
        guard !bottomKeys.isEmpty else { return }

        let stops = bottomKeys.map { key -> Gradient.Stop in
            let pixel = pixel(named: key.name)
            let brightness = min(1, Double(pixel.luminance) / 420)
            let opacity = pixel.luminance > 18 ? 0.12 + brightness * 0.42 : 0
            return Gradient.Stop(
                color: pixel.color.opacity(opacity),
                location: min(1, max(0, key.frame.midX / Self.boardSize.width))
            )
        }
        let gradient = Gradient(stops: stops)
        let reflection = CGRect(x: 0.20, y: 6.58, width: 23.15, height: 0.20)
            .scaled(by: scale)
            .offsetBy(dx: origin.x, dy: origin.y)
        context.fill(
            Path(roundedRect: reflection, cornerRadius: reflection.height / 2),
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: reflection.minX, y: reflection.midY),
                endPoint: CGPoint(x: reflection.maxX, y: reflection.midY)
            )
        )

        let seam = CGRect(x: 0.23, y: 6.59, width: 23.09, height: 0.035)
            .scaled(by: scale)
            .offsetBy(dx: origin.x, dy: origin.y)
        context.fill(
            Path(roundedRect: seam, cornerRadius: seam.height / 2),
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: seam.minX, y: seam.midY),
                endPoint: CGPoint(x: seam.maxX, y: seam.midY)
            )
        )
    }

    private func drawKey(
        _ key: KeyboardKeyGeometry,
        in context: inout GraphicsContext,
        origin: CGPoint,
        scale: CGFloat
    ) {
        let frame = key.frame.scaled(by: scale).offsetBy(dx: origin.x, dy: origin.y)
        let pixel = pixel(named: key.name)
        let lit = pixel.luminance > 18
        let bodyInset = max(0.7, 0.022 * scale)
        let body = frame
            .insetBy(dx: bodyInset, dy: bodyInset)
            .offsetBy(dx: 0, dy: 0.020 * scale)
        let sideInset = max(1.15, 0.042 * scale)
        let topBevel = max(0.7, 0.025 * scale)
        let frontDepth = max(1.25, 0.052 * scale)
        let face = CGRect(
            x: body.minX + sideInset,
            y: body.minY + topBevel,
            width: body.width - sideInset * 2,
            height: body.height - topBevel - frontDepth
        )
        let bodyRadius = max(2.1, 0.088 * scale)
        let faceRadius = max(1.5, 0.055 * scale)

        let socket = frame.insetBy(dx: max(0.45, 0.014 * scale), dy: max(0.45, 0.014 * scale))
        context.fill(
            Path(roundedRect: socket.offsetBy(dx: 0, dy: 0.055 * scale), cornerRadius: bodyRadius),
            with: .color(.black.opacity(0.88))
        )
        if lit {
            let lightWell = socket.insetBy(dx: 0.018 * scale, dy: 0.018 * scale)
            context.fill(
                Path(roundedRect: lightWell, cornerRadius: bodyRadius * 0.92),
                with: .linearGradient(
                    Gradient(colors: [pixel.color.opacity(0.78), pixel.color.opacity(0.26)]),
                    startPoint: CGPoint(x: lightWell.midX, y: lightWell.minY),
                    endPoint: CGPoint(x: lightWell.midX, y: lightWell.maxY)
                )
            )
        }

        let shadow = body.offsetBy(dx: 0, dy: 0.065 * scale)
        context.fill(
            Path(roundedRect: shadow, cornerRadius: bodyRadius),
            with: .color(.black.opacity(0.92))
        )

        context.fill(
            Path(roundedRect: body, cornerRadius: bodyRadius),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.135, green: 0.138, blue: 0.15),
                    Color(red: 0.035, green: 0.036, blue: 0.042),
                ]),
                startPoint: CGPoint(x: body.midX, y: body.minY),
                endPoint: CGPoint(x: body.midX, y: body.maxY)
            )
        )
        context.stroke(
            Path(roundedRect: body, cornerRadius: bodyRadius),
            with: .color(.black.opacity(0.88)),
            lineWidth: max(0.55, scale * 0.016)
        )

        var upperWall = Path()
        upperWall.move(to: CGPoint(x: body.minX + bodyRadius * 0.58, y: body.minY))
        upperWall.addLine(to: CGPoint(x: body.maxX - bodyRadius * 0.58, y: body.minY))
        upperWall.addLine(to: CGPoint(x: face.maxX - faceRadius * 0.25, y: face.minY))
        upperWall.addLine(to: CGPoint(x: face.minX + faceRadius * 0.25, y: face.minY))
        upperWall.closeSubpath()
        context.fill(upperWall, with: .color(Color(red: 0.17, green: 0.174, blue: 0.188)))

        var leftWall = Path()
        leftWall.move(to: CGPoint(x: body.minX, y: body.minY + bodyRadius * 0.55))
        leftWall.addLine(to: CGPoint(x: face.minX, y: face.minY + faceRadius * 0.25))
        leftWall.addLine(to: CGPoint(x: face.minX, y: face.maxY - faceRadius * 0.20))
        leftWall.addLine(to: CGPoint(x: body.minX, y: body.maxY - bodyRadius * 0.55))
        leftWall.closeSubpath()
        context.fill(
            leftWall,
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.14, green: 0.143, blue: 0.155),
                    Color(red: 0.065, green: 0.066, blue: 0.075),
                ]),
                startPoint: CGPoint(x: body.minX, y: body.minY),
                endPoint: CGPoint(x: body.minX, y: body.maxY)
            )
        )

        var rightWall = Path()
        rightWall.move(to: CGPoint(x: body.maxX, y: body.minY + bodyRadius * 0.55))
        rightWall.addLine(to: CGPoint(x: face.maxX, y: face.minY + faceRadius * 0.25))
        rightWall.addLine(to: CGPoint(x: face.maxX, y: face.maxY - faceRadius * 0.20))
        rightWall.addLine(to: CGPoint(x: body.maxX, y: body.maxY - bodyRadius * 0.55))
        rightWall.closeSubpath()
        context.fill(
            rightWall,
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.105, green: 0.108, blue: 0.118),
                    Color(red: 0.042, green: 0.043, blue: 0.05),
                ]),
                startPoint: CGPoint(x: body.maxX, y: body.minY),
                endPoint: CGPoint(x: body.maxX, y: body.maxY)
            )
        )

        var frontWall = Path()
        frontWall.move(to: CGPoint(x: face.minX + faceRadius * 0.20, y: face.maxY))
        frontWall.addLine(to: CGPoint(x: face.maxX - faceRadius * 0.20, y: face.maxY))
        frontWall.addLine(to: CGPoint(x: body.maxX - bodyRadius * 0.55, y: body.maxY))
        frontWall.addLine(to: CGPoint(x: body.minX + bodyRadius * 0.55, y: body.maxY))
        frontWall.closeSubpath()
        context.fill(
            frontWall,
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.09, green: 0.092, blue: 0.102),
                    Color(red: 0.025, green: 0.026, blue: 0.031),
                ]),
                startPoint: CGPoint(x: body.midX, y: face.maxY),
                endPoint: CGPoint(x: body.midX, y: body.maxY)
            )
        )

        context.fill(
            Path(roundedRect: face, cornerRadius: faceRadius),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.205, green: 0.21, blue: 0.225),
                    Color(red: 0.115, green: 0.118, blue: 0.13),
                ]),
                startPoint: CGPoint(x: face.midX, y: face.minY),
                endPoint: CGPoint(x: face.midX, y: face.maxY)
            )
        )
        if lit {
            context.fill(
                Path(roundedRect: face, cornerRadius: faceRadius),
                with: .color(pixel.color.opacity(0.075))
            )
        }
        context.stroke(
            Path(roundedRect: face, cornerRadius: faceRadius),
            with: .color(.white.opacity(0.17)),
            lineWidth: max(0.5, scale * 0.012)
        )

        if lit {
            context.stroke(
                Path(roundedRect: body.insetBy(dx: 0.022 * scale, dy: 0.022 * scale), cornerRadius: bodyRadius * 0.88),
                with: .color(pixel.color.opacity(0.48)),
                lineWidth: max(0.7, scale * 0.022)
            )
        }

        var faceHighlight = Path()
        faceHighlight.move(to: CGPoint(x: face.minX + faceRadius * 0.65, y: face.minY + 0.025 * scale))
        faceHighlight.addLine(to: CGPoint(x: face.maxX - faceRadius * 0.65, y: face.minY + 0.025 * scale))
        context.stroke(
            faceHighlight,
            with: .color(.white.opacity(0.13)),
            lineWidth: max(0.4, scale * 0.009)
        )

        if highlight.contains(key.name) {
            context.stroke(
                Path(roundedRect: body.insetBy(dx: -0.018 * scale, dy: -0.018 * scale), cornerRadius: bodyRadius),
                with: .color(AKTheme.accent),
                lineWidth: max(1.2, scale * 0.05)
            )
        }
        if locked.contains(key.name) {
            context.stroke(
                Path(roundedRect: body.insetBy(dx: -0.012 * scale, dy: -0.012 * scale), cornerRadius: bodyRadius),
                with: .color(Color.white.opacity(0.42)),
                lineWidth: max(1, scale * 0.036)
            )
            var lock = context.resolve(Image(systemName: "lock.fill"))
            lock.shading = .color(Color.white.opacity(0.68))
            let size = max(4.8, scale * 0.13)
            context.draw(
                lock,
                in: CGRect(
                    x: face.maxX - size - 0.06 * scale,
                    y: face.minY + 0.06 * scale,
                    width: size,
                    height: size
                )
            )
        }

        drawLegend(
            Self.legend(for: key.name),
            key: key,
            pixel: pixel,
            lit: lit,
            cap: face,
            scale: scale,
            in: &context
        )
    }

    private func drawLegend(
        _ legend: KeyboardLegend,
        key: KeyboardKeyGeometry,
        pixel: RGB,
        lit: Bool,
        cap: CGRect,
        scale: CGFloat,
        in context: inout GraphicsContext
    ) {
        let compact = key.width < 1.18 || key.height > 1.3 || legend.compact
        let ratio: CGFloat = compact ? 0.205 : 0.235
        let fontSize = min(compact ? 9.6 : 11.6, max(6, scale * ratio)) * legend.scale
        let color = legendColor(for: pixel, lit: lit)

        if key.name == "SPACE" {
            let barWidth = min(cap.width * 0.18, 0.62 * scale)
            let barHeight = max(0.8, 0.028 * scale)
            let bar = CGRect(
                x: cap.midX - barWidth / 2,
                y: cap.midY - barHeight / 2,
                width: barWidth,
                height: barHeight
            )
            if lit {
                context.fill(
                    Path(roundedRect: bar.insetBy(dx: -0.035 * scale, dy: -0.025 * scale), cornerRadius: barHeight),
                    with: .color(pixel.color.opacity(0.22))
                )
            }
            context.fill(
                Path(roundedRect: bar, cornerRadius: barHeight / 2),
                with: .color(color)
            )
            return
        }

        switch legend.layout {
        case .centered:
            let point = CGPoint(x: cap.midX, y: cap.midY - 0.01 * scale)
            if let symbolName = legend.symbolName {
                drawLegendSymbol(
                    symbolName,
                    at: point,
                    size: fontSize * 1.1,
                    color: color,
                    lit: lit,
                    in: &context
                )
            } else if !legend.primary.isEmpty {
                drawLegendText(
                    legend.primary,
                    at: point,
                    size: fontSize,
                    weight: legend.weight,
                    color: color,
                    lit: lit,
                    in: &context
                )
            }

        case .paired:
            drawLegendText(
                legend.secondary ?? "",
                at: CGPoint(x: cap.midX, y: cap.midY - 0.17 * scale),
                size: max(4.4, fontSize * 0.62),
                weight: .medium,
                color: color.opacity(lit ? 0.78 : 0.70),
                lit: lit,
                in: &context
            )
            drawLegendText(
                legend.primary,
                at: CGPoint(x: cap.midX, y: cap.midY + 0.13 * scale),
                size: fontSize,
                weight: legend.weight,
                color: color,
                lit: lit,
                in: &context
            )

        case .numpad:
            drawLegendText(
                legend.primary,
                at: CGPoint(x: cap.midX, y: cap.midY - 0.06 * scale),
                size: fontSize,
                weight: legend.weight,
                color: color,
                lit: lit,
                in: &context
            )
            if let secondary = legend.secondary {
                drawLegendText(
                    secondary,
                    at: CGPoint(x: cap.midX, y: cap.maxY - 0.16 * scale),
                    size: max(4.2, fontSize * 0.48),
                    weight: .medium,
                    color: color.opacity(lit ? 0.76 : 0.66),
                    lit: false,
                    in: &context
                )
            }
        }
    }

    private func drawLegendText(
        _ value: String,
        at point: CGPoint,
        size: CGFloat,
        weight: Font.Weight,
        color: Color,
        lit: Bool,
        in context: inout GraphicsContext
    ) {
        guard !value.isEmpty else { return }
        let text = Text(verbatim: value)
            .font(.system(size: size, weight: weight, design: .monospaced))
            .tracking(max(0.1, size * 0.035))
            .foregroundStyle(color)
        if lit {
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: color.opacity(0.62), radius: max(0.7, size * 0.16)))
                layer.draw(text, at: point, anchor: .center)
            }
        } else {
            context.draw(text, at: point, anchor: .center)
        }
    }

    private func drawLegendSymbol(
        _ name: String,
        at point: CGPoint,
        size: CGFloat,
        color: Color,
        lit: Bool,
        in context: inout GraphicsContext
    ) {
        var symbol = context.resolve(Image(systemName: name))
        symbol.shading = .color(color)
        let rect = CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
        if lit {
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: color.opacity(0.62), radius: max(0.7, size * 0.14)))
                layer.draw(symbol, in: rect)
            }
        } else {
            context.draw(symbol, in: rect)
        }
    }

    private func legendColor(for pixel: RGB, lit: Bool) -> Color {
        guard lit else {
            return Color.white.opacity(scheme == .dark ? 0.62 : 0.56)
        }
        let peak = max(Double(pixel.r), Double(pixel.g), Double(pixel.b))
        guard peak > 0 else { return Color.white.opacity(0.52) }
        let multiplier = max(1, 214 / peak)
        return Color(
            red: min(1, Double(pixel.r) * multiplier / 255),
            green: min(1, Double(pixel.g) * multiplier / 255),
            blue: min(1, Double(pixel.b) * multiplier / 255)
        )
    }

    private func drawStatusStrip(
        in context: inout GraphicsContext,
        origin: CGPoint,
        scale: CGFloat
    ) {
        let strip = CGRect(x: 15.93, y: 3.70, width: 2.63, height: 0.34)
            .scaled(by: scale)
            .offsetBy(dx: origin.x, dy: origin.y)
        context.fill(
            Path(roundedRect: strip, cornerRadius: strip.height / 2),
            with: .linearGradient(
                Gradient(colors: [.black.opacity(0.90), .black.opacity(0.56)]),
                startPoint: CGPoint(x: strip.midX, y: strip.minY),
                endPoint: CGPoint(x: strip.midX, y: strip.maxY)
            )
        )
        context.stroke(
            Path(roundedRect: strip, cornerRadius: strip.height / 2),
            with: .color(.white.opacity(0.10)),
            lineWidth: max(0.55, scale * 0.014)
        )

        let legends = ["1", "A", "S", "F", "W"]
        for (index, legend) in legends.enumerated() {
            let x = strip.minX + (0.24 + CGFloat(index) * 0.27) * scale
            context.draw(
                Text(verbatim: legend)
                    .font(.system(size: max(4.5, scale * 0.105), weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.56)),
                at: CGPoint(x: x, y: strip.midY),
                anchor: .center
            )
        }

        let media = ["speaker.wave.2.fill", "playpause.fill", "sun.max.fill"]
        for (index, symbolName) in media.enumerated() {
            let x = strip.minX + (1.67 + CGFloat(index) * 0.25) * scale
            drawLegendSymbol(
                symbolName,
                at: CGPoint(x: x, y: strip.midY),
                size: max(4.2, scale * 0.12),
                color: Color.white.opacity(index == 0 ? 0.88 : 0.62),
                lit: false,
                in: &context
            )
        }
        context.draw(
            Text(verbatim: "M")
                .font(.system(size: max(4.5, scale * 0.105), weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.62)),
            at: CGPoint(x: strip.minX + 2.45 * scale, y: strip.midY),
            anchor: .center
        )
    }

    private func drawMultifunctionControls(
        in context: inout GraphicsContext,
        origin: CGPoint,
        scale: CGFloat
    ) {
        let logoPixel = pixel(named: "Logo")
        let lit = logoPixel.luminance > 18
        let button = Self.logoFrame
            .scaled(by: scale)
            .offsetBy(dx: origin.x, dy: origin.y)
        context.fill(
            Path(roundedRect: button.offsetBy(dx: 0, dy: 0.055 * scale), cornerRadius: 0.22 * scale),
            with: .color(.black.opacity(0.86))
        )
        if lit {
            context.fill(
                Path(roundedRect: button.insetBy(dx: -0.02 * scale, dy: -0.02 * scale), cornerRadius: 0.23 * scale),
                with: .color(logoPixel.color.opacity(0.30))
            )
        }
        context.fill(
            Path(roundedRect: button.insetBy(dx: 0.055 * scale, dy: 0.055 * scale), cornerRadius: 0.18 * scale),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.19, green: 0.195, blue: 0.205),
                    Color(red: 0.075, green: 0.077, blue: 0.085),
                ]),
                startPoint: CGPoint(x: button.midX, y: button.minY),
                endPoint: CGPoint(x: button.midX, y: button.maxY)
            )
        )
        context.stroke(
            Path(roundedRect: button.insetBy(dx: 0.055 * scale, dy: 0.055 * scale), cornerRadius: 0.18 * scale),
            with: .color(.white.opacity(0.14)),
            lineWidth: max(0.55, scale * 0.014)
        )
        if let image = Self.rogMarkImage {
            var resolved = context.resolve(image)
            resolved.shading = .color(lit ? logoPixel.color : Color.white.opacity(0.58))
            let markHeight = button.height * 0.48
            let markWidth = markHeight * (68 / 37)
            context.draw(
                resolved,
                in: CGRect(
                    x: button.midX - markWidth / 2,
                    y: button.midY - markHeight / 2,
                    width: markWidth,
                    height: markHeight
                )
            )
        }
        if highlight.contains("Logo") {
            context.stroke(
                Path(roundedRect: button.insetBy(dx: -0.02 * scale, dy: -0.02 * scale), cornerRadius: 0.15 * scale),
                with: .color(AKTheme.accent),
                lineWidth: max(1.2, scale * 0.05)
            )
        }

        let wheel = CGRect(x: 22.27, y: 0.26, width: 0.98, height: 0.90)
            .scaled(by: scale)
            .offsetBy(dx: origin.x, dy: origin.y)
        context.fill(
            Path(roundedRect: wheel.offsetBy(dx: 0, dy: 0.05 * scale), cornerRadius: 0.12 * scale),
            with: .color(.black.opacity(0.88))
        )
        context.fill(
            Path(roundedRect: wheel, cornerRadius: 0.12 * scale),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.16, green: 0.163, blue: 0.175),
                    Color(red: 0.055, green: 0.056, blue: 0.064),
                    Color(red: 0.11, green: 0.112, blue: 0.122),
                ]),
                startPoint: CGPoint(x: wheel.minX, y: wheel.midY),
                endPoint: CGPoint(x: wheel.maxX, y: wheel.midY)
            )
        )
        context.stroke(
            Path(roundedRect: wheel, cornerRadius: 0.12 * scale),
            with: .color(.white.opacity(0.14)),
            lineWidth: max(0.55, scale * 0.014)
        )
        for index in 0..<10 {
            let x = wheel.minX + (0.11 + CGFloat(index) * 0.083) * scale
            var groove = Path()
            groove.move(to: CGPoint(x: x, y: wheel.minY + 0.10 * scale))
            groove.addLine(to: CGPoint(x: x, y: wheel.maxY - 0.10 * scale))
            context.stroke(
                groove,
                with: .color(index.isMultiple(of: 2) ? .black.opacity(0.62) : .white.opacity(0.11)),
                lineWidth: max(0.48, scale * 0.012)
            )
        }

        var wheelHighlight = Path()
        wheelHighlight.move(to: CGPoint(x: wheel.minX + 0.12 * scale, y: wheel.minY + 0.08 * scale))
        wheelHighlight.addLine(to: CGPoint(x: wheel.maxX - 0.12 * scale, y: wheel.minY + 0.08 * scale))
        context.stroke(
            wheelHighlight,
            with: .color(.white.opacity(0.16)),
            lineWidth: max(0.45, scale * 0.01)
        )
    }

    private func pixel(named name: String) -> RGB {
        map.profile.indices(named: name).reduce(.black) { result, index in
            guard pixels.indices.contains(index) else { return result }
            return result.max(with: pixels[index])
        }
    }

}

struct KeyboardLegend {
    enum Layout {
        case centered
        case paired
        case numpad
    }

    let primary: String
    var secondary: String? = nil
    var symbolName: String? = nil
    var layout: Layout = .centered
    var compact = false
    var scale: CGFloat = 1
    var weight: Font.Weight = .semibold
}

struct KeyboardKeyGeometry {
    let name: String
    let frame: CGRect

    var width: CGFloat { frame.width }
    var height: CGFloat { frame.height }
}

extension KeyboardPreview {
    static let boardSize = CGSize(width: 23.55, height: 6.97)
    static let logoFrame = CGRect(x: 20.30, y: 0.27, width: 1.95, height: 0.88)

    static func layout(in size: CGSize) -> (scale: CGFloat, origin: CGPoint) {
        let scale = min(size.width / boardSize.width, size.height / boardSize.height)
        let origin = CGPoint(
            x: (size.width - boardSize.width * scale) / 2,
            y: (size.height - boardSize.height * scale) / 2
        )
        return (scale, origin)
    }

    static func keyName(at point: CGPoint, in size: CGSize) -> String? {
        let (scale, origin) = layout(in: size)
        let logo = logoFrame.scaled(by: scale).offsetBy(dx: origin.x, dy: origin.y)
        if logo.contains(point) { return "Logo" }
        return keys.first { key in
            key.frame.scaled(by: scale).offsetBy(dx: origin.x, dy: origin.y).contains(point)
        }?.name
    }

    static let rogMarkImage: Image? = {
        guard let url = Bundle.module.url(forResource: "ROGFearlessEye", withExtension: "svg"),
              let image = NSImage(contentsOf: url)
        else { return nil }
        image.isTemplate = true
        return Image(nsImage: image)
    }()

    static func legend(for name: String) -> KeyboardLegend {
        switch name {
        case "ESCAPE":
            KeyboardLegend(primary: "ESC", compact: true, scale: 0.86)
        case "BACK_TICK":
            KeyboardLegend(primary: "`", secondary: "~", layout: .paired)
        case "1":
            KeyboardLegend(primary: "1", secondary: "!", layout: .paired)
        case "2":
            KeyboardLegend(primary: "2", secondary: "@", layout: .paired)
        case "3":
            KeyboardLegend(primary: "3", secondary: "#", layout: .paired)
        case "4":
            KeyboardLegend(primary: "4", secondary: "$", layout: .paired)
        case "5":
            KeyboardLegend(primary: "5", secondary: "%", layout: .paired)
        case "6":
            KeyboardLegend(primary: "6", secondary: "^", layout: .paired)
        case "7":
            KeyboardLegend(primary: "7", secondary: "&", layout: .paired)
        case "8":
            KeyboardLegend(primary: "8", secondary: "*", layout: .paired)
        case "9":
            KeyboardLegend(primary: "9", secondary: "(", layout: .paired)
        case "0":
            KeyboardLegend(primary: "0", secondary: ")", layout: .paired)
        case "MINUS":
            KeyboardLegend(primary: "−", secondary: "_", layout: .paired)
        case "EQUALS":
            KeyboardLegend(primary: "=", secondary: "+", layout: .paired)
        case "LEFT_BRACKET":
            KeyboardLegend(primary: "[", secondary: "{", layout: .paired)
        case "RIGHT_BRACKET":
            KeyboardLegend(primary: "]", secondary: "}", layout: .paired)
        case "ANSI_BACK_SLASH":
            KeyboardLegend(primary: "\\", secondary: "|", layout: .paired)
        case "SEMICOLON":
            KeyboardLegend(primary: ";", secondary: ":", layout: .paired)
        case "QUOTE":
            KeyboardLegend(primary: "'", secondary: "\"", layout: .paired)
        case "COMMA":
            KeyboardLegend(primary: ",", secondary: "<", layout: .paired)
        case "PERIOD":
            KeyboardLegend(primary: ".", secondary: ">", layout: .paired)
        case "FORWARD_SLASH":
            KeyboardLegend(primary: "/", secondary: "?", layout: .paired)

        case "TAB":
            KeyboardLegend(primary: "", symbolName: "arrow.right.to.line.compact", scale: 0.95)
        case "CAPS_LOCK":
            KeyboardLegend(primary: "CAPS", scale: 0.88)
        case "LEFT_SHIFT", "RIGHT_SHIFT":
            KeyboardLegend(primary: "", symbolName: "shift", scale: 1.04)
        case "LEFT_CONTROL", "RIGHT_CONTROL":
            KeyboardLegend(primary: "CTRL", scale: 0.88)
        case "LEFT_ALT", "RIGHT_ALT":
            KeyboardLegend(primary: "ALT", scale: 0.92)
        case "LEFT_WINDOWS":
            KeyboardLegend(primary: "", symbolName: "squareshape.split.2x2", scale: 0.92)
        case "BACKSPACE":
            KeyboardLegend(primary: "", symbolName: "arrow.left", scale: 1.05)
        case "ANSI_ENTER", "NUMPAD_ENTER":
            KeyboardLegend(primary: "", symbolName: "return", scale: 1.05)
        case "LEFT_ARROW":
            KeyboardLegend(primary: "", symbolName: "arrow.left", scale: 0.96)
        case "RIGHT_ARROW":
            KeyboardLegend(primary: "", symbolName: "arrow.right", scale: 0.96)
        case "UP_ARROW":
            KeyboardLegend(primary: "", symbolName: "arrow.up", scale: 0.96)
        case "DOWN_ARROW":
            KeyboardLegend(primary: "", symbolName: "arrow.down", scale: 0.96)
        case "SPACE":
            KeyboardLegend(primary: "", symbolName: "minus", scale: 1.08)
        case "RIGHT_FUNCTION":
            KeyboardLegend(primary: "FN", scale: 0.94)
        case "MENU":
            KeyboardLegend(primary: "", symbolName: "list.bullet.rectangle", scale: 0.90)

        case "PRINT_SCREEN":
            KeyboardLegend(primary: "PRTSC", compact: true, scale: 0.70)
        case "SCROLL_LOCK":
            KeyboardLegend(primary: "SCRLK", compact: true, scale: 0.70)
        case "PAUSE_BREAK":
            KeyboardLegend(primary: "PAUSE", compact: true, scale: 0.70)
        case "INSERT":
            KeyboardLegend(primary: "INS", compact: true, scale: 0.82)
        case "DELETE":
            KeyboardLegend(primary: "DEL", compact: true, scale: 0.82)
        case "HOME":
            KeyboardLegend(primary: "HOME", compact: true, scale: 0.72)
        case "END":
            KeyboardLegend(primary: "END", compact: true, scale: 0.82)
        case "PAGE_UP":
            KeyboardLegend(primary: "PGUP", compact: true, scale: 0.72)
        case "PAGE_DOWN":
            KeyboardLegend(primary: "PGDN", compact: true, scale: 0.72)

        case "NUMPAD_LOCK":
            KeyboardLegend(primary: "NUM", compact: true, scale: 0.78)
        case "NUMPAD_DIVIDE":
            KeyboardLegend(primary: "/")
        case "NUMPAD_TIMES":
            KeyboardLegend(primary: "×")
        case "NUMPAD_MINUS":
            KeyboardLegend(primary: "−")
        case "NUMPAD_PLUS":
            KeyboardLegend(primary: "+", scale: 1.06)
        case "NUMPAD_7":
            KeyboardLegend(primary: "7", secondary: "HOME", layout: .numpad)
        case "NUMPAD_8":
            KeyboardLegend(primary: "8", secondary: "↑", layout: .numpad)
        case "NUMPAD_9":
            KeyboardLegend(primary: "9", secondary: "PGUP", layout: .numpad)
        case "NUMPAD_4":
            KeyboardLegend(primary: "4", secondary: "←", layout: .numpad)
        case "NUMPAD_5":
            KeyboardLegend(primary: "5", secondary: "—", layout: .numpad)
        case "NUMPAD_6":
            KeyboardLegend(primary: "6", secondary: "→", layout: .numpad)
        case "NUMPAD_1":
            KeyboardLegend(primary: "1", secondary: "END", layout: .numpad)
        case "NUMPAD_2":
            KeyboardLegend(primary: "2", secondary: "↓", layout: .numpad)
        case "NUMPAD_3":
            KeyboardLegend(primary: "3", secondary: "PGDN", layout: .numpad)
        case "NUMPAD_0":
            KeyboardLegend(primary: "0", secondary: "INS", layout: .numpad)
        case "NUMPAD_PERIOD":
            KeyboardLegend(primary: ".", secondary: "DEL", layout: .numpad)
        default:
            KeyboardLegend(primary: name)
        }
    }

    static let keys: [KeyboardKeyGeometry] = {
        var keys: [KeyboardKeyGeometry] = []
        let deckYOffset: CGFloat = -0.08

        func add(_ name: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat = 1, _ height: CGFloat = 0.92) {
            keys.append(
                KeyboardKeyGeometry(
                    name: name,
                    frame: CGRect(x: x, y: y + deckYOffset, width: width, height: height)
                )
            )
        }

        func addRow(_ items: [(String, CGFloat)], x: CGFloat, y: CGFloat) {
            var cursor = x
            for (name, width) in items {
                add(name, cursor, y, width)
                cursor += width
            }
        }

        add("ESCAPE", 0.28, 0.35, 1, 0.88)
        for (index, name) in ["F1", "F2", "F3", "F4"].enumerated() {
            add(name, 2.10 + CGFloat(index), 0.35, 1, 0.88)
        }
        for (index, name) in ["F5", "F6", "F7", "F8"].enumerated() {
            add(name, 6.42 + CGFloat(index), 0.35, 1, 0.88)
        }
        for (index, name) in ["F9", "F10", "F11", "F12"].enumerated() {
            add(name, 10.74 + CGFloat(index), 0.35, 1, 0.88)
        }
        for (index, name) in ["PRINT_SCREEN", "SCROLL_LOCK", "PAUSE_BREAK"].enumerated() {
            add(name, 15.75 + CGFloat(index), 0.35, 1, 0.88)
        }

        addRow([
            ("BACK_TICK", 1), ("1", 1), ("2", 1), ("3", 1), ("4", 1), ("5", 1),
            ("6", 1), ("7", 1), ("8", 1), ("9", 1), ("0", 1), ("MINUS", 1),
            ("EQUALS", 1), ("BACKSPACE", 2),
        ], x: 0.28, y: 1.65)
        for (index, name) in ["INSERT", "HOME", "PAGE_UP"].enumerated() {
            add(name, 15.75 + CGFloat(index), 1.65)
        }
        for (index, name) in ["NUMPAD_LOCK", "NUMPAD_DIVIDE", "NUMPAD_TIMES", "NUMPAD_MINUS"].enumerated() {
            add(name, 19.25 + CGFloat(index), 1.65)
        }

        addRow([
            ("TAB", 1.5), ("Q", 1), ("W", 1), ("E", 1), ("R", 1), ("T", 1),
            ("Y", 1), ("U", 1), ("I", 1), ("O", 1), ("P", 1), ("LEFT_BRACKET", 1),
            ("RIGHT_BRACKET", 1), ("ANSI_BACK_SLASH", 1.5),
        ], x: 0.28, y: 2.66)
        for (index, name) in ["DELETE", "END", "PAGE_DOWN"].enumerated() {
            add(name, 15.75 + CGFloat(index), 2.66)
        }
        for (index, name) in ["NUMPAD_7", "NUMPAD_8", "NUMPAD_9"].enumerated() {
            add(name, 19.25 + CGFloat(index), 2.66)
        }
        add("NUMPAD_PLUS", 22.25, 2.66, 1, 1.93)

        addRow([
            ("CAPS_LOCK", 1.75), ("A", 1), ("S", 1), ("D", 1), ("F", 1), ("G", 1),
            ("H", 1), ("J", 1), ("K", 1), ("L", 1), ("SEMICOLON", 1), ("QUOTE", 1),
            ("ANSI_ENTER", 2.25),
        ], x: 0.28, y: 3.67)
        for (index, name) in ["NUMPAD_4", "NUMPAD_5", "NUMPAD_6"].enumerated() {
            add(name, 19.25 + CGFloat(index), 3.67)
        }

        addRow([
            ("LEFT_SHIFT", 2.25), ("Z", 1), ("X", 1), ("C", 1), ("V", 1), ("B", 1),
            ("N", 1), ("M", 1), ("COMMA", 1), ("PERIOD", 1), ("FORWARD_SLASH", 1),
            ("RIGHT_SHIFT", 2.75),
        ], x: 0.28, y: 4.68)
        add("UP_ARROW", 16.75, 4.68)
        for (index, name) in ["NUMPAD_1", "NUMPAD_2", "NUMPAD_3"].enumerated() {
            add(name, 19.25 + CGFloat(index), 4.68)
        }
        add("NUMPAD_ENTER", 22.25, 4.68, 1, 1.93)

        addRow([
            ("LEFT_CONTROL", 1.25), ("LEFT_WINDOWS", 1.25), ("LEFT_ALT", 1.25), ("SPACE", 6.25),
            ("RIGHT_ALT", 1.25), ("RIGHT_FUNCTION", 1.25), ("MENU", 1.25), ("RIGHT_CONTROL", 1.25),
        ], x: 0.28, y: 5.69)
        for (index, name) in ["LEFT_ARROW", "DOWN_ARROW", "RIGHT_ARROW"].enumerated() {
            add(name, 15.75 + CGFloat(index), 5.69)
        }
        add("NUMPAD_0", 19.25, 5.69, 2)
        add("NUMPAD_PERIOD", 21.25, 5.69)

        return keys
    }()

    static let bottomGlowKeys = keys
        .filter { $0.frame.maxY > 6.45 }
        .sorted { $0.frame.midX < $1.frame.midX }
}

private extension CGSize {
    func scaled(by scale: CGFloat) -> CGSize {
        CGSize(width: width * scale, height: height * scale)
    }
}

private extension CGRect {
    func scaled(by scale: CGFloat) -> CGRect {
        CGRect(x: origin.x * scale, y: origin.y * scale, width: width * scale, height: height * scale)
    }
}

struct KeyboardSelectionEditor: View {
    @Environment(AppModel.self) private var model
    @State private var dragMode: DragMode?
    @State private var visitedKeys: Set<String> = []

    var enabled = true

    var body: some View {
        KeyboardPreview(
            pixels: model.lastPixels,
            map: model.lightingMap,
            highlight: model.selectedLightingKeys,
            locked: Set(model.lightingMap.agentKeys)
        )
        .overlay {
            GeometryReader { proxy in
                Color.clear
                    .contentShape(.rect)
                    .gesture(selectionGesture(in: proxy.size), including: enabled ? .all : .none)
            }
        }
        .opacity(enabled ? 1 : 0.5)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AKL("Keyboard key selection"))
        .accessibilityChildren {
            ForEach(model.lightingMap.canvasNames, id: \.self) { name in
                Button {
                    model.toggleLightingKey(name)
                } label: {
                    Text(verbatim: accessibilityName(for: name))
                }
                .disabled(!enabled)
                .accessibilityValue(
                    model.selectedLightingKeys.contains(name)
                        ? Text(AKL("Selected"))
                        : Text(AKL("Not selected"))
                )
            }
            ForEach(model.lightingMap.agentKeys, id: \.self) { name in
                Text(verbatim: name)
                    .accessibilityValue(AKL("Reserved agent identity lamp"))
            }
        }
    }

    private func selectionGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard enabled,
                      let name = KeyboardPreview.keyName(at: value.location, in: size),
                      model.lightingMap.canvasNames.contains(name),
                      visitedKeys.insert(name).inserted
                else { return }

                if dragMode == nil {
                    dragMode = model.selectedLightingKeys.contains(name) ? .remove : .add
                }
                model.setLightingKey(name, selected: dragMode == .add)
            }
            .onEnded { _ in
                dragMode = nil
                visitedKeys.removeAll(keepingCapacity: true)
            }
    }

    private func accessibilityName(for name: String) -> String {
        name.replacingOccurrences(of: "_", with: " ")
    }

    private enum DragMode {
        case add
        case remove
    }
}

struct MousePreview: View {
    var active: Bool
    var showCaption = true
    /// Overall capsule height. All inner metrics derive from it so the view
    /// never overflows a fixed-height container (cards use ~38, inspector ~64).
    var height: CGFloat = 88

    var body: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(AKTheme.keyIdle)
                .frame(width: height / 2, height: height)
                .overlay {
                    VStack(spacing: height * 0.11) {
                        Circle()
                            .fill(active ? AKTheme.accent : AKTheme.keyIdle)
                            .frame(width: height * 0.11, height: height * 0.11)
                            .shadow(color: active ? AKTheme.accent.opacity(0.8) : .clear, radius: 6)
                        Capsule()
                            .fill(active ? AKTheme.accent.opacity(0.7) : Color.primary.opacity(0.12))
                            .frame(width: height * 0.2, height: height * 0.07)
                    }
                    .padding(.top, height * 0.16)
                }
            if showCaption {
                Text(AKL("Wheel"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(active ? AKL("Preview") : AKL("Unavailable"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityLabel(AKL("Mouse lighting unavailable"))
    }
}

#Preview("Idle keyboard") {
    KeyboardPreview(pixels: Array(repeating: RGB.white.scaled(0.08), count: AK.ledCount))
        .frame(width: 720)
        .padding()
}
