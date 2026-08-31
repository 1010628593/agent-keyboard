import AgentKeyboardCore
import SwiftUI

struct AgentsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(AKL("Agents"))
                        .font(.largeTitle.weight(.bold))
                        .tracking(-0.6)
                    Text(AKL("Each agent has a color scheme. F1–F6 show who is online."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                AgentIdentityStrip()

                KeyboardPreview(
                    pixels: model.lastPixels,
                    map: model.lightingMap,
                    highlight: model.dashboard.onlineKeyNames
                )
                .padding(.horizontal, 22)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .frame(height: 292)
                .background(AKTheme.keyWell, in: .rect(cornerRadius: AKTheme.radiusXL))
                .overlay {
                    RoundedRectangle(cornerRadius: AKTheme.radiusXL)
                        .strokeBorder(
                            model.look(for: .running).color.color.opacity(scheme == .dark ? 0.32 : 0.20),
                            lineWidth: 1
                        )
                        .allowsHitTesting(false)
                }
                .shadow(
                    color: model.look(for: .running).color.color.opacity(scheme == .dark ? 0.24 : 0.10),
                    radius: 24,
                    y: 10
                )

                StatusLightingStrip()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: 1240, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(AKTheme.canvas)
    }
}

/// The only visible assignment control. Agents stay attached to their live
/// state while drag and drop moves them between F1–F6.
private struct AgentIdentityStrip: View {
    @Environment(AppModel.self) private var model
    @State private var dropTarget: String?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(model.dashboard.slots) { slot in
                AgentIdentityItem(
                    slot: slot,
                    selected: slot.isAssigned && model.selectedAgentID == slot.spec.agentID,
                    targeted: dropTarget == slot.spec.slot
                )
                .frame(maxWidth: .infinity)
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

                if slot.id != model.dashboard.slots.last?.id {
                    Divider()
                        .frame(height: 52)
                }
            }
        }
        .padding(6)
        .akGlassSurface(radius: AKTheme.radiusXL, tint: AKTheme.accent.opacity(0.025))
    }
}

private struct AgentIdentityItem: View {
    @Environment(AppModel.self) private var model
    let slot: AgentSlot
    let selected: Bool
    let targeted: Bool

    private var signature: Color {
        guard slot.isAssigned else { return .secondary.opacity(0.35) }
        return model.look(for: .running, agentID: slot.spec.agentID).color.color
    }

    var body: some View {
        Button {
            guard slot.isAssigned else { return }
            withAnimation(.snappy) { model.selectAgent(slot.spec.agentID) }
        } label: {
            HStack(spacing: 7) {
                AgentBrandIcon(agentID: slot.spec.agentID, size: 24)

                Text(slot.isAssigned ? LocalizedStringResource(stringLiteral: slot.spec.name) : AKL("Unassigned"))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(selected ? AKTheme.accent : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Divider()
                    .frame(height: 18)
                    .padding(.horizontal, 1)

                Text(verbatim: slot.spec.keyName)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(selected ? AKTheme.accent : .secondary)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 66)
            .contentShape(.rect)
            .background(selected ? AKTheme.accent.opacity(0.10) : .clear, in: .rect(cornerRadius: AKTheme.radiusM))
            .overlay {
                RoundedRectangle(cornerRadius: AKTheme.radiusM)
                    .strokeBorder(targeted || selected ? AKTheme.accent : .clear, lineWidth: targeted ? 2 : 1.5)
                    .allowsHitTesting(false)
            }
            .shadow(color: selected ? AKTheme.accent.opacity(0.24) : .clear, radius: 13)
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(signature)
                    .frame(width: 28, height: 2)
                    .padding(.bottom, 6)
            }
        }
        .buttonStyle(.plain)
        .help(AKL("Drag to reorder"))
        .accessibilityLabel(slot.isAssigned ? "\(slot.spec.name), \(slot.spec.keyName)" : slot.spec.keyName)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityAction(named: Text(AKL("Move up"))) { move(-1) }
        .accessibilityAction(named: Text(AKL("Move down"))) { move(1) }
        .animation(.snappy, value: selected)
        .animation(.snappy, value: targeted)
    }

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

private struct StatusLightingStrip: View {
    @Environment(AppModel.self) private var model

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(AKL("Status Lighting"))
                    .font(.headline)
                Spacer()
                Button {
                    model.openLighting(for: model.lightingState)
                } label: {
                    Label {
                        Text(AKL("Edit Lighting"))
                    } icon: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(AKTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .akGlassSurface(
                    radius: AKTheme.radiusM,
                    tint: AKTheme.accent.opacity(0.10),
                    interactive: true
                )
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(AgentStatus.allCases) { status in
                    StatusLightingTile(
                        status: status,
                        look: model.look(for: status),
                        selected: model.lightingState == status
                    ) {
                        withAnimation(.snappy) { model.selectLightingState(status) }
                    }
                }
            }
        }
        .akCard(padding: 14, radius: AKTheme.radiusXL)
    }
}

private struct StatusLightingTile: View {
    @Environment(\.colorScheme) private var scheme
    let status: AgentStatus
    let look: StateLook
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: look.effect.symbol)
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(look.color.color)
                    .frame(width: 42, height: 42)
                    .background(look.color.color.opacity(scheme == .dark ? 0.16 : 0.11), in: .circle)
                    .overlay {
                        Circle()
                            .strokeBorder(look.color.color.opacity(0.42), lineWidth: 1)
                            .allowsHitTesting(false)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(status.localizedTitle)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(selected ? look.color.color : .primary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(verbatim: "\(Int((look.brightness * 100).rounded()))%")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }

                    Text(look.effect.localizedTitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(look.color.color)
                        .lineLimit(1)

                    Text(status.localizedDetail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
            .contentShape(.rect)
            .background(selected ? look.color.color.opacity(0.08) : .clear, in: .rect(cornerRadius: AKTheme.radiusL))
            .akGlassSurface(
                radius: AKTheme.radiusL,
                tint: selected ? look.color.color.opacity(0.10) : nil,
                interactive: true
            )
            .overlay {
                RoundedRectangle(cornerRadius: AKTheme.radiusL)
                    .strokeBorder(selected ? look.color.color : AKTheme.cardBorder, lineWidth: selected ? 1.5 : 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: selected ? look.color.color.opacity(0.22) : .clear, radius: 14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(status.localizedTitle) + Text(", ") + Text(look.effect.localizedTitle))
        .animation(.snappy, value: selected)
    }
}

#Preview("Agents Dark") {
    AgentsView()
        .environment(AppModel.preview)
        .preferredColorScheme(.dark)
        .frame(width: 1120, height: 820)
}

#Preview("Agents Light") {
    AgentsView()
        .environment(AppModel.preview)
        .preferredColorScheme(.light)
        .frame(width: 1120, height: 820)
}

#Preview("Agents 中文") {
    AgentsView()
        .environment(AppModel.previewChinese)
        .preferredColorScheme(.light)
        .frame(width: 1120, height: 820)
}
