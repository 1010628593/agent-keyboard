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
    static let radiusM: CGFloat = 10
    static let radiusL: CGFloat = 12
    static let radiusXL: CGFloat = 14

    static let accent = Color(red: 139 / 255, green: 92 / 255, blue: 246 / 255)
    static let accentDeep = Color(red: 99 / 255, green: 102 / 255, blue: 241 / 255)
    static let success = Color(red: 16 / 255, green: 185 / 255, blue: 129 / 255)
    static let warning = Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255)
    static let danger = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255)
    static let thinking = accent

    static let canvas = Color.adaptive(
        light: NSColor(srgbRed: 0.961, green: 0.961, blue: 0.969, alpha: 1),
        dark: NSColor(srgbRed: 0.071, green: 0.071, blue: 0.078, alpha: 1)
    )
    static let sidebar = Color.adaptive(
        light: NSColor(srgbRed: 0.941, green: 0.941, blue: 0.949, alpha: 1),
        dark: NSColor(srgbRed: 0.086, green: 0.090, blue: 0.098, alpha: 1)
    )
    static let card = Color.adaptive(
        light: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1),
        dark: NSColor(srgbRed: 0.110, green: 0.114, blue: 0.125, alpha: 1)
    )
    static let cardBorder = Color.adaptive(
        light: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.08),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.08)
    )
    static let inset = Color.adaptive(
        light: NSColor(srgbRed: 0.937, green: 0.941, blue: 0.949, alpha: 1),
        dark: NSColor(srgbRed: 0.086, green: 0.090, blue: 0.102, alpha: 1)
    )
    static let keyWell = Color.adaptive(
        light: NSColor(srgbRed: 0.910, green: 0.918, blue: 0.933, alpha: 1),
        dark: NSColor(srgbRed: 0.043, green: 0.047, blue: 0.055, alpha: 1)
    )
    static let keyIdle = Color.adaptive(
        light: NSColor(srgbRed: 0.82, green: 0.83, blue: 0.86, alpha: 1),
        dark: NSColor(srgbRed: 0.118, green: 0.125, blue: 0.141, alpha: 1)
    )
    static let selectionFill = accent.opacity(0.16)
    static let selectionStroke = accent
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
            .background(AKTheme.card, in: .rect(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(AKTheme.cardBorder, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .compositingGroup()
            .shadow(color: .black.opacity(scheme == .light ? 0.06 : 0), radius: 10, y: 2)
    }
}

struct AKInset: ViewModifier {
    var radius: CGFloat = AKTheme.radiusM

    func body(content: Content) -> some View {
        content
            .background(AKTheme.inset, in: .rect(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(AKTheme.cardBorder, lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

struct AKSelected: ViewModifier {
    var selected: Bool
    var radius: CGFloat = AKTheme.radiusL

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(selected ? AKTheme.selectionStroke : AKTheme.cardBorder, lineWidth: selected ? 1.5 : 1)
                    .allowsHitTesting(false)
            }
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
            .background(AKTheme.inset, in: .rect(cornerRadius: AKTheme.radiusS))
            .overlay {
                RoundedRectangle(cornerRadius: AKTheme.radiusS)
                    .strokeBorder(AKTheme.cardBorder, lineWidth: 1)
                    .allowsHitTesting(false)
            }
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
