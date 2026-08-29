import AgentKeyboardCore
import SwiftUI

struct LightingInspector: View {
    @Environment(AppModel.self) private var model
    @State private var hexDraft = ""
    @FocusState private var hexFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    identityCard
                    stateCard
                    effectCard
                    colorCard
                    slidersCard
                    if model.lightingState == .running {
                        glyphCard
                    }
                    if model.selectedPeripheral == .mouse {
                        Text(AKL("Mouse lighting is preview only"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
            }
            Divider()
            applyBar
                .padding(12)
                .background(AKTheme.canvas)
        }
        .onAppear(perform: syncHex)
        .onChange(of: look.color) { _, _ in
            if !hexFocused { syncHex() }
        }
        .onChange(of: model.lightingState) { _, _ in
            if !hexFocused { syncHex() }
        }
        .onChange(of: model.selectedAgentID) { _, _ in
            if !hexFocused { syncHex() }
        }
    }

    private var look: StateLook { model.look(for: model.lightingState) }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AKL("Rule Preview"))
                .font(.headline)
            HStack(spacing: 8) {
                Image(systemName: model.lightingState.symbol)
                    .foregroundStyle(look.color.color)
                Text(model.lightingState.localizedTitle)
                    .font(.title2.weight(.semibold))
                Spacer(minLength: 0)
                Text(look.effect.localizedTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent {
                Picker(selection: agentBinding) {
                    ForEach(assignedAgents, id: \.id) { profile in
                        Text(verbatim: profile.name).tag(Optional(profile.id))
                    }
                } label: {
                    Text(AKL("Agent"))
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            } label: {
                Text(AKL("Agent"))
            }
            LabeledContent {
                Text(verbatim: model.productName(for: .keyboard))
                    .lineLimit(1)
                    .truncationMode(.middle)
            } label: {
                Text(AKL("Device"))
            }
        }
        .font(.callout)
        .akCard(padding: 12)
    }

    private var assignedAgents: [AgentProfile] {
        model.dashboard.slots.compactMap { slot in
            guard slot.isAssigned else { return nil }
            return AgentProfile.named(slot.spec.agentID)
        }
    }

    private var agentBinding: Binding<String?> {
        Binding(
            get: { model.selectedAgentID },
            set: { if let id = $0 { model.selectAgent(id) } }
        )
    }

    private var stateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AKL("State"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(AgentStatus.allCases) { status in
                    let selected = model.lightingState == status
                    Button {
                        model.selectLightingState(status)
                    } label: {
                        Text(status.localizedTitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(selected ? AKTheme.accent : .primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                selected ? AKTheme.accent.opacity(0.18) : AKTheme.inset,
                                in: .capsule
                            )
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        selected ? AKTheme.accent.opacity(0.7) : Color.clear,
                                        lineWidth: 1
                                    )
                                    .allowsHitTesting(false)
                            }
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private var effectCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AKL("Effect"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Picker(
                selection: Binding(
                    get: { look.effect },
                    set: { model.setEffect($0) }
                )
            ) {
                ForEach(LightingEffect.allCases) { effect in
                    Label {
                        Text(effect.localizedTitle)
                    } icon: {
                        Image(systemName: effect.symbol)
                    }
                    .tag(effect)
                }
            } label: {
                Text(AKL("Effect"))
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .akCard(padding: 12)
    }

    private var colorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AKL("Color"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(Self.swatchColors, id: \.self) { rgb in
                    Button {
                        model.setColor(rgb)
                    } label: {
                        Circle()
                            .fill(rgb.color)
                            .frame(width: 22, height: 22)
                            .overlay {
                                Circle().strokeBorder(
                                    look.color == rgb ? Color.primary : Color.white.opacity(0.35),
                                    lineWidth: look.color == rgb ? 2 : 1
                                )
                                .allowsHitTesting(false)
                            }
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(paletteName(rgb)))
                    .accessibilityAddTraits(look.color == rgb ? .isSelected : [])
                }
                ColorPicker(
                    selection: Binding(
                        get: { look.color.color },
                        set: { model.setColor($0) }
                    ),
                    supportsOpacity: false
                ) {
                    Text(AKL("Custom"))
                }
                .labelsHidden()
                .frame(width: 28, height: 22)
                .accessibilityLabel(AKL("Custom"))
            }
            HStack(spacing: 8) {
                Text(AKL("Hex"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("#RRGGBB", text: $hexDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption.monospaced())
                    .focused($hexFocused)
                    .onSubmit(commitHex)
                    .onChange(of: hexFocused) { _, focused in
                        if !focused { commitHex() }
                    }
                    .frame(width: 92)
                Text(look.localizedPaletteName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .akCard(padding: 12)
    }

    private var slidersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sliderRow(
                title: AKL("Brightness"),
                leading: "sun.min",
                trailing: "sun.max",
                value: Binding(
                    get: { look.brightness },
                    set: { model.setBrightness($0) }
                ),
                range: 0.15...1
            ) {
                Text(look.brightness, format: .percent.precision(.fractionLength(0)))
            }
            sliderRow(
                title: AKL("Speed"),
                leading: "tortoise",
                trailing: "hare",
                value: Binding(
                    get: { look.speed },
                    set: { model.setSpeed($0) }
                ),
                range: 0.4...2.5
            ) {
                HStack(spacing: 0) {
                    Text(look.speed, format: .number.precision(.fractionLength(1)))
                    Text(verbatim: "×")
                }
            }
        }
        .akCard(padding: 12)
    }

    private var glyphCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AKL("Start glyph"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(AKL("Thinking paints the agent letter on the board for a moment, then the effect."))
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                model.replayThinkingGlyph()
            } label: {
                Label {
                    Text(model.lightingGlyphPreviewing ? AKL("Playing glyph") : AKL("Preview start glyph"))
                } icon: {
                    Image(systemName: model.lightingGlyphPreviewing ? "pause.circle" : "play.circle")
                }
            }
            .disabled(model.lightingGlyphPreviewing)
        }
        .akCard(padding: 12)
    }

    private var applyBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    model.applyLighting()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: model.lightingAppliedRecently ? "checkmark" : "sparkle")
                        Text(model.lightingAppliedRecently ? AKL("Applied") : AKL("Apply Lighting"))
                    }
                }
                .buttonStyle(.akPrimary)
                .accessibilityLabel(AKL("Apply Lighting"))
                if model.pinnedCanvas != nil {
                    Button {
                        model.releaseCanvasPin()
                    } label: {
                        Text(AKL("Resume Auto"))
                    }
                    .buttonStyle(.akSecondary)
                    .accessibilityLabel(AKL("Resume Auto"))
                }
            }
            Text(footerCopy)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var footerCopy: LocalizedStringResource {
        if !model.isConnected(.keyboard) {
            return AKL("Preview is live. Connect the keyboard to write lights.")
        }
        if model.mcpOverlayActive {
            return AKL("Agent overlay is paused in this preview.")
        }
        if model.pinnedCanvas != nil {
            return AKL("This look is pinned on the board. Resume Auto follows agent status again.")
        }
        return AKL("Edits preview live. Apply pins this look on the board until the next agent event.")
    }

    private func sliderRow<Value: View>(
        title: LocalizedStringResource,
        leading: String,
        trailing: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        @ViewBuilder valueLabel: () -> Value
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                valueLabel()
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack {
                Image(systemName: leading)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                Slider(value: value, in: range)
                    .controlSize(.small)
                Image(systemName: trailing)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
    }

    private func syncHex() {
        hexDraft = look.color.hexString
    }

    private func commitHex() {
        if let rgb = RGB(hex: hexDraft) {
            model.setColor(rgb)
            hexDraft = rgb.hexString
        } else {
            syncHex()
        }
    }

    private func paletteName(_ rgb: RGB) -> LocalizedStringResource {
        StateLook(effect: .staticFill, color: rgb).localizedPaletteName
    }

    private static let swatchColors: [RGB] = [
        RGB(16, 185, 129),
        RGB(40, 90, 255),
        RGB(20, 184, 166),
        RGB(139, 92, 246),
        RGB(245, 158, 11),
        RGB(239, 68, 68),
    ]
}
