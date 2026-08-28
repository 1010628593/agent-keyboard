import AgentKeyboardCore
import SwiftUI

struct AgentsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AKL("Agents"))
                        .font(.largeTitle.weight(.semibold))
                    Text(AKL("Each agent has a color scheme. Drag a row to change the key it lights."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                AgentSlotList()
                KeyboardPreview(
                    pixels: model.lastPixels,
                    map: model.lightingMap,
                    highlight: model.dashboard.onlineKeyNames
                )
                .padding(14)
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .background(AKTheme.keyWell, in: .rect(cornerRadius: AKTheme.radiusL))
            }
            .padding(24)
            .frame(maxWidth: 860, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(AKTheme.canvas)
    }
}

/// The single source of truth for "who sits on which key". Rows are reordered by
/// dragging; there is no second list of keys to keep in sync.
private struct AgentSlotList: View {
    @Environment(AppModel.self) private var model
    @State private var dropTarget: String?

    var body: some View {
        VStack(spacing: 8) {
            ForEach(model.dashboard.slots) { slot in
                AgentSlotRow(slot: slot, isDropTarget: dropTarget == slot.spec.slot)
                    .draggable(slot.spec.slot)
                    .dropDestination(for: String.self) { payloads, _ in
                        guard let source = payloads.first else { return false }
                        dropTarget = nil
                        withAnimation(.snappy) {
                            model.moveAgent(fromSlotID: source, toSlotID: slot.spec.slot)
                        }
                        return true
                    } isTargeted: { targeted in
                        dropTarget = targeted ? slot.spec.slot : nil
                    }
            }
        }
    }
}

private struct AgentSlotRow: View {
    @Environment(AppModel.self) private var model
    let slot: AgentSlot
    var isDropTarget = false

    private let radius = AKTheme.radiusM

    private var isSelected: Bool {
        slot.isAssigned && model.selectedAgentID == slot.spec.agentID
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 12)

            Text(verbatim: slot.spec.keyName)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(slot.isAssigned ? .primary : .secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(AKTheme.inset, in: .rect(cornerRadius: 6))

            AgentGlyph(symbol: slot.profile.symbol, tint: tint)

            VStack(alignment: .leading, spacing: 2) {
                if slot.isAssigned {
                    Text(verbatim: slot.spec.name)
                        .font(.callout.weight(.semibold))
                    Text(slot.profile.localizedSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(AKL("Unassigned"))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if slot.isAssigned {
                StatusPill(status: slot.status)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(AKTheme.card, in: .rect(cornerRadius: radius))
        .overlay {
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(borderColor, lineWidth: isDropTarget ? 2 : (isSelected ? 1.5 : 1))
        }
        .animation(.snappy, value: isDropTarget)
        .animation(.snappy, value: isSelected)
        .contentShape(.rect)
        .onTapGesture(perform: select)
        .help(AKL("Drag to reorder"))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(slot.spec.keyName)
        .accessibilityValue(slot.isAssigned ? "\(slot.spec.name), \(slot.status.displayTitle)" : "Unassigned")
        .accessibilityAction(named: Text(AKL("Move up"))) { move(-1) }
        .accessibilityAction(named: Text(AKL("Move down"))) { move(1) }
    }

    private var borderColor: Color {
        if isDropTarget { return AKTheme.accent }
        return isSelected ? AKTheme.selectionStroke : AKTheme.cardBorder
    }

    private var tint: Color {
        guard slot.isAssigned, slot.status != .idle else { return Color.secondary.opacity(0.35) }
        return model.look(for: slot.status, agentID: slot.spec.agentID).color.color
    }

    private func select() {
        guard slot.isAssigned else { return }
        withAnimation(.snappy) { model.selectAgent(slot.spec.agentID) }
    }

    /// Keyboard/ VoiceOver fallback: the row has no visible buttons, so reordering
    /// without a mouse goes through accessibility actions.
    private func move(_ offset: Int) {
        let slots = model.dashboard.slots
        guard let index = slots.firstIndex(where: { $0.spec.slot == slot.spec.slot }) else { return }
        let target = index + offset
        guard slots.indices.contains(target) else { return }
        withAnimation(.snappy) {
            model.moveAgent(fromSlotID: slot.spec.slot, toSlotID: slots[target].spec.slot)
        }
    }
}

#Preview("Agents Dark") {
    AgentsView()
        .environment(AppModel.preview)
        .preferredColorScheme(.dark)
        .frame(width: 980, height: 720)
}

#Preview("Agents Light") {
    AgentsView()
        .environment(AppModel.preview)
        .preferredColorScheme(.light)
        .frame(width: 980, height: 720)
}

#Preview("Agents 中文") {
    AgentsView()
        .environment(AppModel.previewChinese)
        .preferredColorScheme(.dark)
        .frame(width: 980, height: 720)
}
