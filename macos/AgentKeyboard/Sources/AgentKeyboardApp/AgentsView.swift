import AgentKeyboardCore
import SwiftUI

struct AgentsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            AgentLibraryPane()
                .frame(minWidth: 240, idealWidth: 280, maxWidth: 320)
            AgentKeysPane()
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(AKTheme.canvas)
    }
}

struct AgentLibraryPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(AKL("Agents"))
                    .font(.largeTitle.weight(.semibold))
                Text(AKL("Each agent has a color scheme. F1–F6 show who is online."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(AgentProfile.library) { profile in
                        LibraryAgentRow(profile: profile)
                    }
                }
            }
        }
    }
}

struct LibraryAgentRow: View {
    @Environment(AppModel.self) private var model
    let profile: AgentProfile

    private var slot: AgentSlot? {
        model.dashboard.slot(forAgentID: profile.id)
    }

    var body: some View {
        Button {
            withAnimation(.snappy) { model.selectAgent(profile.id) }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                AgentGlyph(
                    symbol: profile.symbol,
                    tint: statusDot(slot?.status ?? .idle, agentID: profile.id)
                )
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(statusDot(slot?.status ?? .idle, agentID: profile.id))
                            .frame(width: 7, height: 7)
                        Text(profile.name)
                            .font(.headline)
                    }
                    Text(profile.localizedSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(AKTheme.card, in: .rect(cornerRadius: AKTheme.radiusM))
            .akSelected(model.selectedAgentID == profile.id, radius: AKTheme.radiusM)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(profile.name)
        .accessibilityValue(slot?.status.localizedTitle ?? AKL("Idle"))
    }

    private func statusDot(_ status: AgentStatus, agentID: String) -> Color {
        if status == .idle {
            return Color.secondary.opacity(0.35)
        }
        return model.look(for: status, agentID: agentID).color.color
    }
}

struct AgentKeysPane: View {
    @Environment(AppModel.self) private var model

    private let columns = [GridItem(.adaptive(minimum: 158), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AKL("Online keys"))
                        .font(.headline)
                    Text(AKL("F1–F6 are identity lamps. Use the arrows to set who sits where."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(model.dashboard.slots.enumerated()), id: \.element.spec.slot) { index, slot in
                        SlotLampCard(
                            slot: slot,
                            isFirst: index == 0,
                            isLast: index == model.dashboard.slots.count - 1
                        )
                    }
                }
                KeyboardPreview(
                    pixels: model.lastPixels,
                    map: model.lightingMap,
                    highlight: model.dashboard.onlineKeyNames
                )
                .frame(maxHeight: 160)
            }
        }
    }
}

struct SlotLampCard: View {
    @Environment(AppModel.self) private var model
    let slot: AgentSlot
    var isFirst = false
    var isLast = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                guard slot.isAssigned else { return }
                withAnimation(.snappy) { model.selectAgent(slot.spec.agentID) }
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: slot.spec.keyName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Circle()
                        .fill(slot.status == .idle
                            ? Color.secondary.opacity(0.35)
                            : model.look(for: slot.status, agentID: slot.spec.agentID).color.color)
                        .frame(width: 14, height: 14)
                    if slot.isAssigned {
                        Text(verbatim: slot.spec.name)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } else {
                        Text(AKL("Unassigned"))
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                    Text(slot.status.localizedTitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(!slot.isAssigned)
            .opacity(slot.isAssigned ? 1 : 0.6)
            .accessibilityLabel(slot.spec.keyName)
            .accessibilityValue("\(slot.spec.name), \(slot.status.displayTitle)")

            VStack(spacing: 6) {
                Button {
                    move(-1)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.caption2.weight(.semibold))
                        .frame(width: 22, height: 22)
                        .contentShape(.rect)
                }
                .disabled(isFirst || !slot.isAssigned)
                .accessibilityLabel(AKL("Move up"))
                Button {
                    move(1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .frame(width: 22, height: 22)
                        .contentShape(.rect)
                }
                .disabled(isLast || !slot.isAssigned)
                .accessibilityLabel(AKL("Move down"))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .opacity(slot.isAssigned ? 1 : 0.3)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKTheme.inset, in: .rect(cornerRadius: 10))
        .akSelected(slot.isAssigned && model.selectedAgentID == slot.spec.agentID, radius: 10)
    }

    private func move(_ offset: Int) {
        withAnimation(.snappy) {
            model.moveAgent(slotID: slot.spec.slot, offset: offset)
        }
    }
}

#Preview("Agents Dark") {
    AgentsView()
        .environment(AppModel.preview)
        .preferredColorScheme(.dark)
        .frame(width: 980, height: 720)
}

#Preview("Agents 中文") {
    AgentsView()
        .environment(AppModel.previewChinese)
        .preferredColorScheme(.dark)
        .frame(width: 980, height: 720)
}
