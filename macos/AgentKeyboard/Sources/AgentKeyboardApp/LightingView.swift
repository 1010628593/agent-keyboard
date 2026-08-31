import AgentKeyboardCore
import SwiftUI

struct LightingView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                LightingWorkbenchCanvas()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                LightingConfigurationPanel(showsContext: false)
                    .frame(width: inspectorWidth(for: proxy.size.width))
                    .frame(maxHeight: .infinity)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(AKTheme.canvas)
        .onAppear(perform: model.beginLightingEditing)
        .onDisappear(perform: model.endLightingEditing)
    }

    private func inspectorWidth(for width: CGFloat) -> CGFloat {
        Swift.min(360, Swift.max(330, width * 0.28))
    }
}

private struct LightingWorkbenchCanvas: View {
    @Environment(AppModel.self) private var model
    @State private var isEditingKeyRange = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LightingAgentGrid()

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    Text(AKL("Six States"))
                        .font(.headline)
                    Spacer(minLength: 12)
                    Text(AKL("Choose a state to edit its lighting."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                LightingStateGrid()
            }

            LightingKeyboardStage(isEditingKeyRange: isEditingKeyRange)
                .frame(maxWidth: .infinity)

            if isEditingKeyRange {
                LightingSelectionTools()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            LightingSelectionBar(isEditingKeyRange: $isEditingKeyRange)

            Spacer(minLength: 0)
        }
        .padding(18)
        .animation(.snappy, value: isEditingKeyRange)
        .onChange(of: model.selectedAgentID) { _, _ in
            isEditingKeyRange = false
        }
        .onChange(of: model.lightingState) { _, _ in
            isEditingKeyRange = false
        }
    }
}

private struct LightingAgentGrid: View {
    @Environment(AppModel.self) private var model

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 82), spacing: 8),
        count: 6
    )

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(model.dashboard.slots) { slot in
                LightingAgentPickButton(slot: slot)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AKL("Agents"))
    }
}

private struct LightingAgentPickButton: View {
    @Environment(AppModel.self) private var model
    let slot: AgentSlot

    private var selected: Bool {
        slot.isAssigned && model.selectedAgentID == slot.spec.agentID
    }

    var body: some View {
        Button {
            guard slot.isAssigned else { return }
            withAnimation(.snappy) {
                model.selectAgent(slot.spec.agentID)
            }
        } label: {
            HStack(spacing: 8) {
                AgentBrandIcon(agentID: slot.spec.agentID, size: 27)
                    .overlay(alignment: .bottomTrailing) {
                        Circle()
                            .fill(slot.status.tint)
                            .frame(width: 6, height: 6)
                            .overlay {
                                Circle().strokeBorder(AKTheme.card, lineWidth: 1)
                            }
                            .accessibilityHidden(true)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.isAssigned ? LocalizedStringResource(stringLiteral: slot.spec.name) : AKL("Unassigned"))
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    Text(verbatim: slot.spec.keyName)
                        .font(.caption2.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(
                selected ? AKTheme.accent.opacity(0.12) : AKTheme.inset,
                in: .rect(cornerRadius: 11)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .strokeBorder(
                        selected ? AKTheme.accent : AKTheme.cardBorder,
                        lineWidth: selected ? 1.8 : 1
                    )
                    .allowsHitTesting(false)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!slot.isAssigned)
        .opacity(slot.isAssigned ? 1 : 0.5)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var accessibilityLabel: Text {
        guard slot.isAssigned else { return Text(AKL("Unassigned")) }
        return Text(verbatim: slot.spec.name)
            + Text(verbatim: ", \(slot.spec.keyName), ")
            + Text(slot.status.localizedTitle)
    }
}

private struct LightingStateGrid: View {
    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 82), spacing: 8),
        count: 6
    )

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(AgentStatus.allCases) { status in
                LightingStatePickButton(status: status)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AKL("Six States"))
    }
}

private struct LightingStatePickButton: View {
    @Environment(AppModel.self) private var model
    let status: AgentStatus

    private var look: StateLook { model.look(for: status) }
    private var selected: Bool { model.lightingState == status }

    var body: some View {
        Button {
            withAnimation(.snappy) {
                model.selectLightingState(status)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: status.symbol)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(look.color.color)
                    .frame(width: 18)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(status.localizedTitle)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(look.effect.localizedTitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(
                selected ? AKTheme.accent.opacity(0.11) : AKTheme.inset,
                in: .rect(cornerRadius: 11)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .strokeBorder(
                        selected ? AKTheme.accent : AKTheme.cardBorder,
                        lineWidth: selected ? 1.8 : 1
                    )
                    .allowsHitTesting(false)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            Text(status.localizedTitle)
                + Text(verbatim: ", ")
                + Text(look.effect.localizedTitle)
        )
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct LightingKeyboardStage: View {
    @Environment(AppModel.self) private var model
    let isEditingKeyRange: Bool

    var body: some View {
        VStack(spacing: 8) {
            if isEditingKeyRange {
                KeyboardSelectionEditor(enabled: true)
                    .transition(.opacity)
            } else {
                KeyboardPreview(
                    pixels: model.lastPixels,
                    map: model.lightingMap,
                    locked: Set(model.lightingMap.agentKeys)
                )
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(10)
        .background(AKTheme.card.opacity(0.72), in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(AKTheme.cardBorder, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .accessibilityLabel(isEditingKeyRange ? AKL("Keyboard key selection") : AKL("Keyboard lighting preview"))
    }
}

private struct LightingSelectionTools: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(LightingCanvasRegion.allCases) { region in
                        LightingSelectionRegionButton(region: region)
                    }
                }
            }
            .scrollIndicators(.hidden)

            Divider()
                .frame(height: 24)

            Button(AKL("Select All"), action: model.selectAllLightingKeys)
                .buttonStyle(.akSecondary)
                .disabled(model.selectedLightingKeys.count == model.lightingCanvasKeyCount)
            Button(AKL("Clear"), action: model.clearLightingKeys)
                .buttonStyle(.akSecondary)
                .disabled(model.selectedLightingKeys.isEmpty)
        }
        .padding(9)
        .background(AKTheme.inset, in: .rect(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .strokeBorder(AKTheme.cardBorder, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

private struct LightingSelectionRegionButton: View {
    @Environment(AppModel.self) private var model
    let region: LightingCanvasRegion

    private var selected: Bool { model.lightingRegionIsSelected(region) }

    var body: some View {
        Button {
            model.toggleLightingRegion(region)
        } label: {
            Label(region.localizedTitle, systemImage: region.symbol)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(selected ? AKTheme.accent : .primary)
                .padding(.horizontal, 9)
                .frame(minHeight: 30)
                .background(
                    selected ? AKTheme.accent.opacity(0.13) : AKTheme.card,
                    in: .rect(cornerRadius: 8)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(selected ? AKTheme.accent.opacity(0.8) : AKTheme.cardBorder, lineWidth: 1)
                        .allowsHitTesting(false)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(
            selected
                ? AKL("Removes this region without changing other selected keys")
                : AKL("Adds this region without changing other selected keys")
        )
    }
}

private struct LightingSelectionBar: View {
    @Environment(AppModel.self) private var model
    @Binding var isEditingKeyRange: Bool

    var body: some View {
        HStack(spacing: 10) {
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    Text(selectionTitle)
                        .font(.callout.weight(.semibold))
                    Text(AKL("F1–F6 are locked identity lamps"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "circle.grid.3x3.fill")
                    .foregroundStyle(AKTheme.accent)
            }

            Spacer(minLength: 12)

            if isEditingKeyRange {
                Button {
                    isEditingKeyRange = false
                } label: {
                    Label(AKL("Finish Key Selection"), systemImage: "checkmark")
                }
                .buttonStyle(.akPrimary)
                .keyboardShortcut(.defaultAction)
            } else {
                Button {
                    isEditingKeyRange = true
                } label: {
                    Label(AKL("Edit Key Range"), systemImage: "pencil")
                }
                .buttonStyle(.akSecondary)
            }
        }
        .padding(12)
        .background(AKTheme.inset, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(AKTheme.cardBorder, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    private var selectionTitle: LocalizedStringResource {
        if model.lightingSelectionIsAll(for: model.lightingState) {
            return AKL("All \(model.lightingCanvasKeyCount) keys")
        }
        return AKL("\(model.selectedLightingKeys.count) of \(model.lightingCanvasKeyCount) keys selected")
    }
}

#Preview("Lighting Workbench") {
    LightingView()
        .environment(AppModel.preview)
        .preferredColorScheme(.light)
        .frame(width: 1_184, height: 760)
}

#Preview("Lighting Workbench 中文") {
    LightingView()
        .environment(AppModel.previewChinese)
        .preferredColorScheme(.dark)
        .frame(width: 1_004, height: 640)
}
