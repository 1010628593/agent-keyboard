import AgentKeyboardCore
import SwiftUI

struct LightingInspector: View {
    var body: some View {
        LightingConfigurationPanel(showsContext: true)
    }
}

struct LightingConfigurationPanel: View {
    let showsContext: Bool

    var body: some View {
        VStack(spacing: 0) {
            LightingInspectorHeader()
                .padding(14)

            Divider()

            LightingSchemePickerControl()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    LightingEffectPickerControl()
                    LightingColorControls()
                    LightingParameterControls()
                    LightingResetControl()
                    LightingGlyphControl()
                }
                .padding(14)
            }

            Divider()

            LightingCopyControl()
                .padding(.horizontal, 12)
                .padding(.top, 10)

            LightingLivePreviewFooter()
                .padding(12)
                .background(AKTheme.canvas)
        }
    }
}

private struct LightingInspectorHeader: View {
    @Environment(AppModel.self) private var model

    private var look: StateLook { model.look(for: model.lightingState) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let slot = model.selectedSlot, slot.isAssigned {
                HStack(spacing: 9) {
                    AgentBrandIcon(agentID: slot.spec.agentID, size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: "\(slot.spec.name) | \(slot.spec.keyName)")
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                        Text(verbatim: model.lightingSchemeDisplayName(model.currentLightingScheme))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    Circle()
                        .fill(slot.status.tint)
                        .frame(width: 7, height: 7)
                        .accessibilityHidden(true)
                }
            }

            HStack(spacing: 9) {
                Circle()
                    .fill(look.color.color)
                    .frame(width: 13, height: 13)
                    .shadow(color: look.color.color.opacity(0.55), radius: 5)
                    .accessibilityHidden(true)
                Text(model.lightingState.localizedTitle)
                    .font(.title2.weight(.bold))
                Spacer(minLength: 8)
                Text(look.effect.localizedTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LightingSchemePickerControl: View {
    @Environment(AppModel.self) private var model
    @State private var libraryPresented = false

    var body: some View {
        Button {
            libraryPresented = true
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "square.stack.3d.up")
                    .foregroundStyle(AKTheme.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(AKL("Scheme"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(verbatim: model.lightingSchemeDisplayName(model.currentLightingScheme))
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.akSecondary)
        .popover(isPresented: $libraryPresented, arrowEdge: .leading) {
            LightingSchemeLibraryControl()
                .padding(16)
                .frame(width: 330)
                .fixedSize(horizontal: false, vertical: true)
                .presentationSizing(.fitted)
                .environment(model)
        }
        .accessibilityValue(Text(verbatim: model.lightingSchemeDisplayName(model.currentLightingScheme)))
    }
}

private struct LightingEffectPickerControl: View {
    @Environment(AppModel.self) private var model
    @State private var previewOffset = 0.0

    private var look: StateLook { model.look(for: model.lightingState) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(AKL("Effect"))
                    .font(.headline)
                Spacer(minLength: 8)
                Button {
                    previewOffset += 0.73
                } label: {
                    Label(AKL("Preview Effect"), systemImage: "play.circle")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                .help(AKL("Preview Effect"))
            }

            LightingEffectThumbnail(look: fullCanvasLook, phaseOffset: previewOffset)
                .frame(height: 42)

            Picker(AKL("Effect"), selection: effectBinding) {
                ForEach(LightingEffect.allCases) { effect in
                    Label(effect.localizedTitle, systemImage: effect.symbol)
                        .tag(effect.rawValue)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .accessibilityValue(look.effect.localizedTitle)
        }
        .akCard(padding: 12)
    }

    private var fullCanvasLook: StateLook {
        var preview = look
        preview.selectedKeys = nil
        return preview
    }

    private var effectBinding: Binding<String> {
        Binding(
            get: { look.effect.rawValue },
            set: { rawValue in
                guard let effect = LightingEffect(rawValue: rawValue) else { return }
                withAnimation(.snappy) {
                    model.setEffect(effect)
                }
            }
        )
    }
}

private enum LightingSchemeNameAction: Identifiable {
    case saveAs
    case rename(String)

    var id: String {
        switch self {
        case .saveAs: "saveAs"
        case .rename(let id): "rename.\(id)"
        }
    }
}

struct LightingSchemeLibraryControl: View {
    @Environment(AppModel.self) private var model
    @State private var nameAction: LightingSchemeNameAction?
    @State private var deleteTarget: LightingScheme?

    private var scheme: LightingScheme { model.currentLightingScheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(AKL("Scheme Library"))
                    .font(.headline)
                Spacer(minLength: 8)
                schemeKindBadge
            }

            Picker(AKL("Scheme"), selection: schemeBinding) {
                Section {
                    ForEach(model.currentAgentBuiltInSchemes) { item in
                        Text(verbatim: model.lightingSchemeDisplayName(item)).tag(item.id)
                    }
                } header: {
                    Text(AKL("Built-in Schemes"))
                }
                if !model.customLightingSchemes.isEmpty {
                    Section {
                        ForEach(model.customLightingSchemes) { item in
                            Text(verbatim: item.name).tag(item.id)
                        }
                    } header: {
                        Text(AKL("My Schemes"))
                    }
                }
            }
            .pickerStyle(.menu)
            .accessibilityValue(Text(verbatim: model.lightingSchemeDisplayName(scheme)))

            HStack(spacing: 6) {
                Label {
                    Text(
                        model.currentLightingSchemeUsageCount == 1
                            ? AKL("Used by 1 state")
                            : AKL("Used by \(model.currentLightingSchemeUsageCount) states")
                    )
                } icon: {
                    Image(systemName: "link")
                }
                .font(.caption)
                .foregroundStyle(model.currentLightingSchemeUsageCount > 1 ? AKTheme.accent : .secondary)

                Spacer(minLength: 6)

                Menu {
                    Button {
                        nameAction = .saveAs
                    } label: {
                        Label(AKL("Save As"), systemImage: "plus.square.on.square")
                    }
                    Button {
                        _ = model.duplicateCurrentLightingScheme()
                    } label: {
                        Label(AKL("Duplicate and Detach"), systemImage: "square.on.square")
                    }
                    Button {
                        nameAction = .rename(scheme.id)
                    } label: {
                        Label(AKL("Rename"), systemImage: "pencil")
                    }
                    .disabled(scheme.isBuiltIn)
                    Divider()
                    if model.customLightingSchemes.isEmpty {
                        Text(AKL("No custom schemes"))
                    } else {
                        ForEach(model.customLightingSchemes) { item in
                            Menu(item.name) {
                                let uses = model.lightingSchemeUses(item.id)
                                if !uses.isEmpty {
                                    Section {
                                        ForEach(uses) { use in
                                            Label {
                                                Text(verbatim: use.agentName)
                                                    + Text(verbatim: " · ")
                                                    + Text(use.status.localizedTitle)
                                            } icon: {
                                                Image(systemName: "link")
                                            }
                                        }
                                    } header: {
                                        Text(AKL("Used by"))
                                    }
                                    Divider()
                                }
                                Button {
                                    nameAction = .rename(item.id)
                                } label: {
                                    Label(AKL("Rename"), systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    deleteTarget = item
                                } label: {
                                    Label(AKL("Delete"), systemImage: "trash")
                                }
                                .disabled(model.lightingSchemeUsageCount(item.id) > 0)
                            }
                        }
                    }
                } label: {
                    Label(AKL("Manage"), systemImage: "ellipsis.circle")
                        .labelStyle(.iconOnly)
                }
                .menuStyle(.borderlessButton)
                .help(AKL("Manage Schemes"))
            }

            if !scheme.isBuiltIn {
                let uses = model.lightingSchemeUses(scheme.id)
                if !uses.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(AKL("Used by"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ScrollView(.horizontal) {
                            HStack(spacing: 6) {
                                ForEach(uses) { use in
                                    HStack(spacing: 4) {
                                        Image(systemName: "link")
                                            .accessibilityHidden(true)
                                        Text(verbatim: use.agentName)
                                        Text(verbatim: "·")
                                        Text(use.status.localizedTitle)
                                    }
                                    .font(.caption2)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(AKTheme.inset, in: .capsule)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }
                }
            }

            if model.currentLightingSchemeUsageCount > 1 {
                Text(AKL("Changes sync to every agent state using this scheme. Duplicate it first to edit only this state."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if scheme.isBuiltIn {
                Text(AKL("Built-in schemes are read-only. Your first edit creates a custom copy for this state."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .akCard(padding: 12)
        .sheet(item: $nameAction) { action in
            LightingSchemeNameEditor(action: action)
                .environment(model)
        }
        .confirmationDialog(
            AKString("Delete Scheme", locale: model.resolvedLocale),
            isPresented: deleteConfirmation,
            titleVisibility: .visible
        ) {
            if let target = deleteTarget {
                Button(AKString("Delete", locale: model.resolvedLocale), role: .destructive) {
                    _ = model.deleteLightingScheme(target.id)
                    deleteTarget = nil
                }
                Button(AKString("Cancel", locale: model.resolvedLocale), role: .cancel) {
                    deleteTarget = nil
                }
            }
        } message: {
            if let target = deleteTarget {
                Text(AKL("Delete \(target.name)? This cannot be undone."))
            }
        }
    }

    private var schemeBinding: Binding<String> {
        Binding(
            get: { model.currentLightingSchemeID },
            set: model.assignLightingScheme
        )
    }

    private var deleteConfirmation: Binding<Bool> {
        Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )
    }

    private var schemeKindBadge: some View {
        Text(scheme.isBuiltIn ? AKL("Built-in") : AKL("Custom"))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(scheme.isBuiltIn ? Color.secondary : AKTheme.accent)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                scheme.isBuiltIn ? Color.secondary.opacity(0.1) : AKTheme.accent.opacity(0.14),
                in: .capsule
            )
    }
}

private struct LightingSchemeNameEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool
    @State private var draft: String
    let action: LightingSchemeNameAction

    init(action: LightingSchemeNameAction) {
        self.action = action
        _draft = State(initialValue: "")
    }

    private var targetScheme: LightingScheme? {
        guard case .rename(let id) = action else { return nil }
        return model.lightingSchemes[id]
    }

    private var isValid: Bool {
        model.lightingSchemeNameIsAvailable(draft, ignoring: targetScheme?.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.weight(.semibold))
            TextField(AKString("Scheme Name", locale: model.resolvedLocale), text: $draft)
                .textFieldStyle(.roundedBorder)
                .focused($nameFocused)
                .onSubmit(commit)
            if !draft.isEmpty, !isValid {
                Label(AKL("Scheme names must be unique and cannot be empty."), systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(AKTheme.danger)
            }
            HStack {
                Spacer()
                Button(AKL("Cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(AKL("Save"), action: commit)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear {
            switch action {
            case .saveAs:
                draft = "\(model.lightingSchemeDisplayName(model.currentLightingScheme)) \(AKString("Scheme Copy", locale: model.resolvedLocale))"
            case .rename:
                draft = targetScheme?.name ?? ""
            }
            nameFocused = true
        }
    }

    private var title: LocalizedStringResource {
        switch action {
        case .saveAs: AKL("Save Scheme As")
        case .rename: AKL("Rename Scheme")
        }
    }

    private func commit() {
        guard isValid else { return }
        switch action {
        case .saveAs:
            _ = model.saveCurrentLightingScheme(named: draft)
        case .rename(let id):
            _ = model.renameLightingScheme(id, to: draft)
        }
        dismiss()
    }
}

private struct LightingEffectThumbnail: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let look: StateLook
    let phaseOffset: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12, paused: reduceMotion)) { timeline in
            let now = (reduceMotion ? 1.35 : timeline.date.timeIntervalSinceReferenceDate) + phaseOffset
            let pixels = SceneRenderer.renderBoard(
                Dashboard(),
                now: now,
                map: .scopeII,
                idleWhite: 0,
                globalBrightness: 1,
                preview: .canvas(look)
            )
            LightingEffectCanvas(pixels: pixels)
        }
        .background(.black, in: .rect(cornerRadius: 5))
        .compositingGroup()
        .clipShape(.rect(cornerRadius: 5))
        .accessibilityHidden(true)
    }
}

private struct LightingEffectCanvas: View {
    let pixels: [RGB]
    private let map = LightingMap.scopeII

    var body: some View {
        Canvas { context, size in
            let cellWidth = size.width / CGFloat(Swift.max(1, map.cols))
            let cellHeight = size.height / CGFloat(Swift.max(1, map.rows))
            for key in map.profile.keys where !map.agentKeySet.contains(key.name) {
                guard pixels.indices.contains(key.index) else { continue }
                let rect = CGRect(
                    x: CGFloat(key.col) * cellWidth + 0.5,
                    y: CGFloat(key.row) * cellHeight + 0.5,
                    width: Swift.max(1, cellWidth - 1),
                    height: Swift.max(1, cellHeight - 1)
                )
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(pixels[key.index].color))
            }
        }
    }
}

struct LightingColorControls: View {
    @Environment(AppModel.self) private var model
    @State private var selectedStopID = ""
    @State private var hexDraft = ""
    @FocusState private var hexFocused: Bool

    private var look: StateLook { model.look(for: model.lightingState) }
    private var descriptor: LightingEffectDescriptor { look.effect.descriptor }
    private var selectedStop: LightingColorStop? {
        look.palette.stops.first(where: { $0.id == selectedStopID }) ?? look.palette.stops.first
    }

    var body: some View {
        if descriptor.colorMode == .none {
            EmptyView()
        } else if descriptor.colorMode == .spectrum {
            spectrumNotice
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(AKL("Color"))
                        .font(.headline)
                    Spacer(minLength: 8)
                    if descriptor.maximumColorStops > 1 {
                        Button(action: addStop) {
                            Label(AKL("Add Color Stop"), systemImage: "plus")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.plain)
                        .disabled(look.palette.stops.count >= descriptor.maximumColorStops)
                        .help(AKL("Add Color Stop"))
                        Button(action: removeStop) {
                            Label(AKL("Remove Color Stop"), systemImage: "minus")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.plain)
                        .disabled(look.palette.stops.count <= descriptor.minimumColorStops)
                        .help(AKL("Remove Color Stop"))
                    }
                }

                if descriptor.maximumColorStops > 1 {
                    LightingGradientStopBar(selectedStopID: $selectedStopID)
                        .frame(height: 38)
                }

                HStack(spacing: 8) {
                    ForEach(Self.swatchColors, id: \.self) { rgb in
                        Button {
                            setSelectedColor(rgb)
                        } label: {
                            Circle()
                                .fill(rgb.color)
                                .frame(width: 22, height: 22)
                                .overlay {
                                    Circle()
                                        .strokeBorder(
                                            selectedStop?.color == rgb ? Color.primary : Color.white.opacity(0.35),
                                            lineWidth: selectedStop?.color == rgb ? 2 : 1
                                        )
                                        .allowsHitTesting(false)
                                }
                                .contentShape(.circle)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(paletteName(rgb)))
                        .accessibilityAddTraits(selectedStop?.color == rgb ? .isSelected : [])
                    }
                    ColorPicker(selection: colorBinding, supportsOpacity: false) {
                        Text(AKL("Custom"))
                    }
                    .labelsHidden()
                    .frame(width: 28, height: 22)
                    .accessibilityLabel(AKL("Custom Color"))
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
                        .frame(width: 98)
                    if let selectedStop {
                        Text(selectedStop.location, format: .percent.precision(.fractionLength(0)))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }

                if descriptor.allowsBackground {
                    Divider()
                    HStack {
                        Text(AKL("Background Color"))
                            .font(.caption.weight(.medium))
                        Spacer()
                        ColorPicker(selection: backgroundBinding, supportsOpacity: false) {
                            Text(AKL("Background Color"))
                        }
                        .labelsHidden()
                    }
                }
            }
            .akCard(padding: 12)
            .onAppear(perform: selectFirstStop)
            .onChange(of: model.currentLightingSchemeID) { _, _ in selectFirstStop() }
            .onChange(of: look.effect) { _, _ in selectFirstStop() }
            .onChange(of: look.palette.stops) { _, _ in
                if !look.palette.stops.contains(where: { $0.id == selectedStopID }) {
                    selectFirstStop()
                } else if !hexFocused {
                    syncHex()
                }
            }
        }
    }

    private var spectrumNotice: some View {
        Label {
            Text(AKL("Rainbow uses the fixed Aura spectrum. Use angle, width, brightness, and speed to shape it."))
                .font(.caption)
        } icon: {
            Image(systemName: "rainbow")
        }
        .foregroundStyle(.secondary)
        .akCard(padding: 12)
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { selectedStop?.color.color ?? look.color.color },
            set: { setSelectedColor(RGB($0)) }
        )
    }

    private var backgroundBinding: Binding<Color> {
        Binding(
            get: { (look.palette.background ?? .black).color },
            set: { model.setLightingBackgroundColor(RGB($0)) }
        )
    }

    private func selectFirstStop() {
        selectedStopID = look.palette.stops.first?.id ?? ""
        syncHex()
    }

    private func addStop() {
        if let id = model.addLightingColorStop() {
            selectedStopID = id
            syncHex()
        }
    }

    private func removeStop() {
        guard let selectedStop else { return }
        model.removeLightingColorStop(selectedStop.id)
        selectedStopID = model.look(for: model.lightingState).palette.stops.first?.id ?? ""
        syncHex()
    }

    private func setSelectedColor(_ rgb: RGB) {
        guard let selectedStop else { return }
        model.setLightingColorStop(selectedStop.id, color: rgb)
        hexDraft = rgb.hexString
    }

    private func syncHex() {
        hexDraft = selectedStop?.color.hexString ?? look.color.hexString
    }

    private func commitHex() {
        if let rgb = RGB(hex: hexDraft) {
            setSelectedColor(rgb)
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

private struct LightingGradientStopBar: View {
    @Environment(AppModel.self) private var model
    @Binding var selectedStopID: String

    private var look: StateLook { model.look(for: model.lightingState) }

    var body: some View {
        GeometryReader { proxy in
            let width = Swift.max(1, proxy.size.width)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            stops: look.palette.stops.map {
                                .init(color: $0.color.color, location: $0.location)
                            },
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 14)
                    .overlay {
                        Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1)
                    }
                ForEach(look.palette.stops) { stop in
                    let isEndpoint = stop.id == look.palette.stops.first?.id
                        || stop.id == look.palette.stops.last?.id
                    Button {
                        selectedStopID = stop.id
                    } label: {
                        Circle()
                            .fill(stop.color.color)
                            .frame(width: 18, height: 18)
                            .overlay {
                                Circle()
                                    .strokeBorder(selectedStopID == stop.id ? Color.primary : .white, lineWidth: 2)
                            }
                            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                    }
                    .buttonStyle(.plain)
                    .position(x: Swift.min(width - 9, Swift.max(9, width * stop.location)), y: proxy.size.height / 2)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { value in
                                guard !isEndpoint else { return }
                                selectedStopID = stop.id
                                model.setLightingColorStopLocation(stop.id, location: value.location.x / width)
                            }
                    )
                    .accessibilityLabel(AKL("Color Stop"))
                    .accessibilityValue(Text(stop.location, format: .percent.precision(.fractionLength(0))))
                    .accessibilityHint(isEndpoint ? AKL("Endpoint color stop is fixed") : AKL("Drag to change color stop position"))
                    .accessibilityAdjustableAction { direction in
                        guard !isEndpoint else { return }
                        switch direction {
                        case .increment:
                            model.setLightingColorStopLocation(stop.id, location: stop.location + 0.05)
                        case .decrement:
                            model.setLightingColorStopLocation(stop.id, location: stop.location - 0.05)
                        @unknown default:
                            break
                        }
                    }
                }
            }
        }
    }
}

struct LightingParameterControls: View {
    @Environment(AppModel.self) private var model

    private var look: StateLook { model.look(for: model.lightingState) }
    private var visibleParameters: [LightingParameterKind] {
        look.effect.descriptor.parameters.filter { parameter in
            !(parameter == .speed && look.effect == .gradient && !look.parameters.animated)
        }
    }

    var body: some View {
        if look.effect != .off {
            VStack(alignment: .leading, spacing: 12) {
                Text(AKL("Properties"))
                    .font(.headline)
                LightingBrightnessRow()
                ForEach(visibleParameters) { parameter in
                    LightingParameterRow(kind: parameter)
                }
            }
            .akCard(padding: 12)
        }
    }
}

private struct LightingBrightnessRow: View {
    @Environment(AppModel.self) private var model

    private var value: Double { model.look(for: model.lightingState).brightness }

    var body: some View {
        LightingSliderRow(
            title: AKL("Brightness"),
            leading: "sun.min",
            trailing: "sun.max",
            value: Binding(
                get: { value },
                set: model.setBrightness
            ),
            range: 0...1,
            display: value.formatted(.percent.precision(.fractionLength(0)))
        )
    }
}

private struct LightingParameterRow: View {
    @Environment(AppModel.self) private var model
    let kind: LightingParameterKind

    private var look: StateLook { model.look(for: model.lightingState) }

    var body: some View {
        switch kind {
        case .randomColors, .animated:
            Toggle(kind.localizedTitle, isOn: toggleBinding)
                .font(.caption.weight(.medium))
        case .speed:
            LightingSliderRow(
                title: kind.localizedTitle,
                leading: "tortoise",
                trailing: "hare",
                value: numericBinding,
                range: parameterRange,
                display: "\(numericValue.formatted(.number.precision(.fractionLength(1))))×"
            )
        case .angle:
            LightingSliderRow(
                title: kind.localizedTitle,
                leading: "arrow.right",
                trailing: "rotate.right",
                value: numericBinding,
                range: parameterRange,
                display: "\(Int(numericValue.rounded()))°"
            )
        case .width, .density, .tail, .decay, .minimumBrightness:
            LightingSliderRow(
                title: parameterTitle,
                leading: kind.leadingSymbol,
                trailing: kind.trailingSymbol,
                value: numericBinding,
                range: parameterRange,
                display: numericValue.formatted(.percent.precision(.fractionLength(0)))
            )
        }
    }

    private var numericValue: Double {
        switch kind {
        case .speed: look.speed
        case .angle: look.parameters.angleDegrees
        case .width: look.parameters.width
        case .density: look.parameters.density
        case .tail: look.parameters.tail
        case .decay: look.parameters.decay
        case .minimumBrightness: look.parameters.minimumBrightness
        case .randomColors, .animated: 0
        }
    }

    private var numericBinding: Binding<Double> {
        Binding(
            get: { numericValue },
            set: { model.setLightingParameter(kind, value: $0) }
        )
    }

    private var parameterRange: ClosedRange<Double> {
        look.effect.descriptor.range(for: kind) ?? 0...1
    }

    private var parameterTitle: LocalizedStringResource {
        guard kind == .width else { return kind.localizedTitle }
        return switch look.effect {
        case .ripple: AKL("Ring Width")
        case .scanner: AKL("Beam Width")
        case .aurora: AKL("Scale")
        case .wave, .flow, .rainbow: AKL("Band Width")
        default: kind.localizedTitle
        }
    }

    private var toggleBinding: Binding<Bool> {
        Binding(
            get: {
                switch kind {
                case .randomColors: look.parameters.randomColors
                case .animated: look.parameters.animated
                default: false
                }
            },
            set: { model.setLightingToggle(kind, enabled: $0) }
        )
    }
}

private struct LightingSliderRow: View {
    let title: LocalizedStringResource
    let leading: String
    let trailing: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let display: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(verbatim: display)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack {
                Image(systemName: leading)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                Slider(value: $value, in: range)
                    .controlSize(.small)
                    .accessibilityLabel(title)
                    .accessibilityValue(Text(verbatim: display))
                Image(systemName: trailing)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
    }
}

private struct LightingResetControl: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button(action: model.resetCurrentLightingEffect) {
            Label(AKL("Reset Effect Defaults"), systemImage: "arrow.counterclockwise")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.akSecondary)
        .disabled(model.look(for: model.lightingState).effect == .off)
        .help(AKL("Reset colors and effect-specific properties while keeping the scheme name and key selection."))
    }
}

struct LightingGlyphControl: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.lightingState == .running {
            VStack(alignment: .leading, spacing: 8) {
                Text(AKL("Start glyph"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(AKL("Thinking paints the agent letter only inside the selected keys, then starts the effect."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(action: model.replayThinkingGlyph) {
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
    }
}

private struct LightingCopyControl: View {
    @Environment(AppModel.self) private var model
    @State private var copyPresented = false
    @State private var selectedStatusIDs: Set<String> = []

    var body: some View {
        Button {
            selectedStatusIDs.removeAll()
            copyPresented = true
        } label: {
            HStack {
                Label(AKL("Copy to Other States"), systemImage: "square.on.square")
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.akSecondary)
        .popover(isPresented: $copyPresented, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AKL("Copy Lighting to States"))
                        .font(.headline)
                    Text(AKL("Each target gets an independent scheme copy, including its key range."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 6) {
                    ForEach(AgentStatus.allCases.filter { $0 != model.lightingState }) { status in
                        Toggle(isOn: copyBinding(for: status)) {
                            HStack(spacing: 8) {
                                Image(systemName: status.symbol)
                                    .foregroundStyle(model.look(for: status).color.color)
                                    .frame(width: 18)
                                Text(status.localizedTitle)
                                Spacer(minLength: 8)
                                Text(model.look(for: status).effect.localizedTitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }

                HStack {
                    Button(AKL("Cancel")) {
                        copyPresented = false
                    }
                    .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button(AKL("Copy"), action: copySelection)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(selectedStatusIDs.isEmpty)
                }
            }
            .padding(16)
            .frame(width: 330)
            .environment(model)
        }
    }

    private func copyBinding(for status: AgentStatus) -> Binding<Bool> {
        Binding(
            get: { selectedStatusIDs.contains(status.rawValue) },
            set: { selected in
                if selected {
                    selectedStatusIDs.insert(status.rawValue)
                } else {
                    selectedStatusIDs.remove(status.rawValue)
                }
            }
        )
    }

    private func copySelection() {
        let statuses = AgentStatus.allCases.filter { selectedStatusIDs.contains($0.rawValue) }
        guard model.copyCurrentLightingLook(to: statuses) > 0 else { return }
        copyPresented = false
    }
}

private struct LightingLivePreviewFooter: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(previewTitle)
                        .font(.caption.weight(.semibold))
                    Text(AKL("Automatic status lighting resumes when you leave."))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: model.isConnected(.keyboard) ? "display.and.arrow.down" : "display")
                    .foregroundStyle(model.isConnected(.keyboard) ? AKTheme.success : .secondary)
            }

            if model.mcpOverlayActive {
                Label(AKL("Agent overlay is paused in this preview."), systemImage: "pause.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button(action: model.finishLightingEditing) {
                Text(AKL("Done"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.akPrimary)
            .keyboardShortcut(.defaultAction)
        }
    }

    private var previewTitle: LocalizedStringResource {
        if !model.isConnected(.keyboard) {
            return AKL("Preview is live in the app. Connect the keyboard to write lights.")
        }
        return AKL("Device preview is live. Changes save automatically.")
    }
}

private extension LightingParameterKind {
    var leadingSymbol: String {
        switch self {
        case .width: "arrow.left.and.right"
        case .density: "circle.grid.3x3"
        case .tail: "wind"
        case .decay: "chart.line.downtrend.xyaxis"
        case .minimumBrightness: "sun.min"
        case .speed: "tortoise"
        case .angle: "arrow.right"
        case .randomColors: "dice"
        case .animated: "play"
        }
    }

    var trailingSymbol: String {
        switch self {
        case .width: "arrow.left.and.right.circle.fill"
        case .density: "circle.grid.3x3.fill"
        case .tail: "wind.circle.fill"
        case .decay: "chart.line.downtrend.xyaxis.circle.fill"
        case .minimumBrightness: "sun.max"
        case .speed: "hare"
        case .angle: "rotate.right"
        case .randomColors: "dice.fill"
        case .animated: "play.fill"
        }
    }
}
