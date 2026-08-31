import AgentKeyboardCore
import AppKit
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

/// The product identity for an agent. Status is intentionally rendered by a
/// separate control so a brand mark never has to double as a state indicator.
struct AgentBrandIcon: View {
    let agentID: String
    var size: CGFloat = 36

    var body: some View {
        Group {
            if let brandImage {
                Image(nsImage: brandImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "person.crop.square")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.22)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size * 0.22))
        .accessibilityHidden(true)
    }

    private var assetName: String? {
        switch agentID.lowercased() {
        case "codex": "AgentIconCodex"
        case "claude": "AgentIconClaude"
        case "cursor": "AgentIconCursor"
        case "hermes": "AgentIconHermes"
        case "pi": "AgentIconPi"
        case "workbuddy": "AgentIconWorkbuddy"
        default: nil
        }
    }

    private var brandImage: NSImage? {
        guard let assetName,
              let url = Bundle.module.url(forResource: assetName, withExtension: "png")
        else { return nil }
        return NSImage(contentsOf: url)
    }
}

#Preview("Glyph") {
    HStack {
        AgentGlyph(symbol: "shield.fill", tint: AKTheme.accent, size: 36)
        AgentBrandIcon(agentID: "codex", size: 36)
    }
        .padding()
}
