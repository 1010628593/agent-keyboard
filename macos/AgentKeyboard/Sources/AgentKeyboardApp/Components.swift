import AgentKeyboardCore
import SwiftUI

struct StatusPill: View {
    let status: AgentStatus

    var body: some View {
        Label {
            Text(status.localizedTitle)
        } icon: {
            Image(systemName: status.symbol)
        }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(status.tint)
            .background(status.tint.opacity(0.15), in: .capsule)
    }
}

struct StatusLiveDot: View {
    var live: Bool

    var body: some View {
        Label {
            Text(live ? AKL("Connected") : AKL("Unavailable"))
        } icon: {
            Image(systemName: live ? "checkmark.circle.fill" : "circle.dotted")
        }
            .foregroundStyle(live ? AKTheme.success : .secondary)
    }
}

struct AgentGlyph: View {
    var symbol: String
    var tint: Color
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.16), in: .rect(cornerRadius: 8))
    }
}

#Preview("Glyph") {
    AgentGlyph(symbol: "shield.fill", tint: AKTheme.accent, size: 36)
        .padding()
}
