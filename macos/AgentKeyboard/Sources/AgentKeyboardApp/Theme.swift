import AgentKeyboardCore
import AppKit
import SwiftUI

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case dark
    case light

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .dark: NSAppearance(named: .darkAqua)
        case .light: NSAppearance(named: .aqua)
        }
    }
}

enum AKTheme {
    static let radiusS: CGFloat = 8
    static let radiusM: CGFloat = 11
    static let radiusL: CGFloat = 14
    static let radiusXL: CGFloat = 18

    static let accent = Color(red: 153 / 255, green: 102 / 255, blue: 1)
    static let accentDeep = Color(red: 101 / 255, green: 88 / 255, blue: 1)
    static let signal = Color(red: 34 / 255, green: 211 / 255, blue: 238 / 255)
    static let success = Color(red: 16 / 255, green: 185 / 255, blue: 129 / 255)
    static let warning = Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255)
    static let danger = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255)
    static let thinking = accent

    static let canvas = Color.adaptive(
        light: NSColor(srgbRed: 0.952, green: 0.960, blue: 0.978, alpha: 1),
        dark: NSColor(srgbRed: 0.025, green: 0.031, blue: 0.055, alpha: 1)
    )
    static let sidebar = Color.adaptive(
        light: NSColor(srgbRed: 0.925, green: 0.940, blue: 0.970, alpha: 0.92),
        dark: NSColor(srgbRed: 0.035, green: 0.043, blue: 0.074, alpha: 0.94)
    )
    static let card = Color.adaptive(
        light: NSColor(srgbRed: 0.985, green: 0.990, blue: 1, alpha: 0.88),
        dark: NSColor(srgbRed: 0.055, green: 0.065, blue: 0.105, alpha: 0.86)
    )
    static let cardBorder = Color.adaptive(
        light: NSColor(srgbRed: 0.18, green: 0.24, blue: 0.38, alpha: 0.10),
        dark: NSColor(srgbRed: 0.68, green: 0.73, blue: 1, alpha: 0.13)
    )
    static let inset = Color.adaptive(
        light: NSColor(srgbRed: 0.925, green: 0.940, blue: 0.968, alpha: 0.90),
        dark: NSColor(srgbRed: 0.070, green: 0.080, blue: 0.125, alpha: 0.86)
    )
    static let keyWell = Color.adaptive(
        light: NSColor(srgbRed: 0.900, green: 0.925, blue: 0.970, alpha: 1),
        dark: NSColor(srgbRed: 0.018, green: 0.024, blue: 0.047, alpha: 1)
    )
    static let keyIdle = Color.adaptive(
        light: NSColor(srgbRed: 0.82, green: 0.83, blue: 0.86, alpha: 1),
        dark: NSColor(srgbRed: 0.118, green: 0.125, blue: 0.141, alpha: 1)
    )
    static let selectionFill = accent.opacity(0.16)
    static let selectionStroke = accent
}

/// Uses the system Liquid Glass renderer where macOS exposes it. Older systems
/// retain the same hierarchy with a native material surface.
struct AKGlassSurface: ViewModifier {
    var radius: CGFloat = AKTheme.radiusL
    var tint: Color?
    var interactive = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            if interactive {
                content
                    .glassEffect(
                        tint.map { Glass.regular.tint($0).interactive() } ?? .regular.interactive(),
                        in: .rect(cornerRadius: radius)
                    )
            } else {
                content
                    .glassEffect(
                        tint.map { Glass.regular.tint($0) } ?? .regular,
                        in: .rect(cornerRadius: radius)
                    )
            }
        } else {
            content
                .background(.thinMaterial, in: .rect(cornerRadius: radius))
                .background(tint ?? .clear, in: .rect(cornerRadius: radius))
                .overlay {
                    RoundedRectangle(cornerRadius: radius)
                        .strokeBorder(AKTheme.cardBorder, lineWidth: 1)
                        .allowsHitTesting(false)
                }
        }
    }
}

extension Color {
    static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}

extension RGB {
    var color: Color {
        Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    init(_ color: Color) {
        let ns = NSColor(color)
        if let srgb = Self.sRGBColor(from: ns) {
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            srgb.getRed(&r, green: &g, blue: &b, alpha: &a)
            self.init(
                UInt8(clamping: Int((Swift.min(1, Swift.max(0, r)) * 255).rounded())),
                UInt8(clamping: Int((Swift.min(1, Swift.max(0, g)) * 255).rounded())),
                UInt8(clamping: Int((Swift.min(1, Swift.max(0, b)) * 255).rounded()))
            )
            return
        }
        self.init(0, 0, 0)
    }

    private static func sRGBColor(from color: NSColor) -> NSColor? {
        if let srgb = color.usingColorSpace(.sRGB) { return srgb }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let cg = color.cgColor.converted(to: space, intent: .relativeColorimetric, options: nil)
        else { return nil }
        return NSColor(cgColor: cg)?.usingColorSpace(.sRGB)
    }
}

extension AgentStatus {
    var tint: Color {
        switch self {
        case .idle: .secondary
        case .running: RGB.running.color
        case .tool: RGB.tool.color
        case .approval: RGB.approval.color
        case .done: RGB.done.color
        case .error: RGB.error.color
        }
    }

    var legendTitle: String {
        switch self {
        case .idle: "Idle"
        case .running: "Thinking"
        case .tool: "Tool"
        case .approval: "Warning"
        case .done: "Active"
        case .error: "Error"
        }
    }
}

struct AKCard: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var padding: CGFloat = 14
    var radius: CGFloat = AKTheme.radiusL

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(AKTheme.card)
                        .shadow(
                            color: .black.opacity(scheme == .light ? 0.07 : 0.22),
                            radius: scheme == .light ? 12 : 18,
                            y: scheme == .light ? 3 : 8
                        )
                    RoundedRectangle(cornerRadius: radius)
                        .strokeBorder(AKTheme.cardBorder, lineWidth: 1)
                }
                .allowsHitTesting(false)
            }
    }
}

struct AKInset: ViewModifier {
    var radius: CGFloat = AKTheme.radiusM

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(AKTheme.inset)
                    RoundedRectangle(cornerRadius: radius)
                        .strokeBorder(AKTheme.cardBorder, lineWidth: 1)
                }
                .allowsHitTesting(false)
            }
    }
}

struct AKSelected: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var selected: Bool
    var radius: CGFloat = AKTheme.radiusL

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(selected ? AKTheme.selectionStroke : AKTheme.cardBorder, lineWidth: selected ? 1.5 : 1)
                    .allowsHitTesting(false)
            }
            .shadow(
                color: selected ? AKTheme.accent.opacity(scheme == .dark ? 0.30 : 0.14) : .clear,
                radius: selected ? 16 : 0
            )
            .animation(.snappy, value: selected)
    }
}

struct AKPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [AKTheme.accent, AKTheme.accentDeep], startPoint: .leading, endPoint: .trailing)
                    .opacity(configuration.isPressed ? 0.82 : 1),
                in: .rect(cornerRadius: AKTheme.radiusS)
            )
            .contentShape(.rect)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.snappy, value: configuration.isPressed)
    }
}

struct AKSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: AKTheme.radiusS)
                        .fill(AKTheme.inset)
                    RoundedRectangle(cornerRadius: AKTheme.radiusS)
                        .strokeBorder(AKTheme.cardBorder, lineWidth: 1)
                }
                .allowsHitTesting(false)
            }
            .contentShape(.rect)
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct AKDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(AKTheme.danger.opacity(configuration.isPressed ? 0.82 : 1), in: .rect(cornerRadius: AKTheme.radiusS))
    }
}

extension ButtonStyle where Self == AKPrimaryButtonStyle {
    static var akPrimary: AKPrimaryButtonStyle { .init() }
}

extension ButtonStyle where Self == AKSecondaryButtonStyle {
    static var akSecondary: AKSecondaryButtonStyle { .init() }
}

extension ButtonStyle where Self == AKDangerButtonStyle {
    static var akDanger: AKDangerButtonStyle { .init() }
}

extension View {
    func akGlassSurface(
        radius: CGFloat = AKTheme.radiusL,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        modifier(AKGlassSurface(radius: radius, tint: tint, interactive: interactive))
    }

    func akCard(padding: CGFloat = 14, radius: CGFloat = AKTheme.radiusL) -> some View {
        modifier(AKCard(padding: padding, radius: radius))
    }

    func akInset(radius: CGFloat = AKTheme.radiusM) -> some View {
        modifier(AKInset(radius: radius))
    }

    func akSelected(_ selected: Bool, radius: CGFloat = AKTheme.radiusL) -> some View {
        modifier(AKSelected(selected: selected, radius: radius))
    }
}
