import AgentKeyboardCore
import SwiftUI

struct KeyboardPreview: View {
    @Environment(\.colorScheme) private var scheme
    var pixels: [RGB]
    var map: LightingMap = .scopeII
    var highlight: Set<String> = []

    var body: some View {
        Canvas { context, size in
            let cellW = size.width / CGFloat(map.cols)
            let cellH = size.height / CGFloat(map.rows)
            let idle = scheme == .dark ? Color(white: 0.13) : Color(white: 0.78)
            for key in map.profile.keys {
                let pixel = pixels.indices.contains(key.index) ? pixels[key.index] : .black
                let lit = pixel.luminance > 18
                let rect = CGRect(
                    x: CGFloat(key.col) * cellW + 1.2,
                    y: CGFloat(key.row) * cellH + 1.2,
                    width: cellW - 2.4,
                    height: cellH - 2.8
                )
                if lit {
                    let glow = rect.insetBy(dx: -1.2, dy: -1.2)
                    context.fill(
                        Path(roundedRect: glow, cornerRadius: 3),
                        with: .color(pixel.color.opacity(0.35))
                    )
                }
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 2.6),
                    with: .color(lit ? pixel.color : idle)
                )
                if highlight.contains(key.name) {
                    context.stroke(
                        Path(roundedRect: rect, cornerRadius: 2.6),
                        with: .color(AKTheme.accent.opacity(0.95)),
                        lineWidth: 1.2
                    )
                }
            }
        }
        .aspectRatio(CGFloat(map.cols) / (CGFloat(map.rows) + 0.4), contentMode: .fit)
        .accessibilityLabel(AKL("Keyboard lighting preview"))
        .accessibilityAddTraits(.isImage)
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
