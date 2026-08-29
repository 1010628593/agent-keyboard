import AgentKeyboardCore
import SwiftUI

struct InspectorPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            switch model.sidebar {
            case .devices, .agents:
                ScrollView {
                    inspectorBody
                        .padding(16)
                }
            case .lighting:
                LightingInspector()
            }
        }
        .background(AKTheme.canvas)
    }

    @ViewBuilder
    private var inspectorBody: some View {
        switch model.sidebar {
        case .devices: DeviceInspector()
        case .agents: AssignmentInspector()
        case .lighting: EmptyView()
        }
    }
}

struct DeviceInspector: View {
    @Environment(AppModel.self) private var model

    private var kind: PeripheralKind { model.selectedPeripheral }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 32))
                    .foregroundStyle(model.isConnected(kind) ? AKTheme.accent : Color.secondary)
                Text(verbatim: model.productName(for: kind))
                    .font(.callout.weight(.medium))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(AKTheme.keyWell, in: .rect(cornerRadius: 12))
            labeled(AKL("Type"), kind.localizedTitle)
            labeled(AKL("Connection"), verbatim: kind.connection)
            HStack {
                Text(AKL("Status")).foregroundStyle(.secondary)
                Spacer()
                Text(model.isConnected(kind) ? AKL("Connected") : AKL("Unavailable"))
                    .foregroundStyle(model.isConnected(kind) ? AKTheme.success : .secondary)
            }
            .font(.callout)
            if kind == .keyboard {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text(AKL("Keyboard roles"))
                    } icon: {
                        Image(systemName: "sparkle")
                    }
                    .font(.headline)
                    Text(AKL("F1–F6 are online agents. The rest of the board follows priority."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ZoneSchematic(kind: kind, active: model.isConnected(kind), previewHeight: 64)
                        .frame(height: 72)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text(AKL("Mouse lighting"))
                    } icon: {
                        Image(systemName: "computermouse")
                    }
                    .font(.headline)
                    Text(AKL("Mouse lighting is preview only"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ZoneSchematic(kind: kind, active: model.isConnected(kind), previewHeight: 64)
                        .frame(height: 72)
                }
            }
            Button {
                model.useForAgentLighting()
            } label: {
                Label {
                    Text(AKL("Use for Agent Lighting"))
                } icon: {
                    Image(systemName: "sparkle")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.akPrimary)
            .disabled(!kind.implemented)
            .opacity(kind.implemented ? 1 : 0.45)
        }
    }

    private func labeled(_ title: LocalizedStringResource, _ value: LocalizedStringResource) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.callout)
    }

    private func labeled(_ title: LocalizedStringResource, verbatim value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(verbatim: value)
        }
        .font(.callout)
    }
}

struct AssignmentInspector: View {
    @Environment(AppModel.self) private var model
    @State private var showStateLooks = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let profile = AgentProfile.named(model.selectedAgentID ?? "") {
                agentBlock(profile)
            } else {
                ContentUnavailableView {
                    Label {
                        Text(AKL("Select an agent"))
                    } icon: {
                        Image(systemName: "person.3")
                    }
                } description: {
                    Text(AKL("Choose an agent to edit its color scheme."))
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            }
            deviceBlock
            keyBlock
            statusFeed
            stateColors
        }
    }

    private func agentBlock(_ profile: AgentProfile) -> some View {
        let slot = model.dashboard.slot(forAgentID: profile.id)
        return HStack(alignment: .top, spacing: 10) {
            AgentGlyph(symbol: profile.symbol, tint: (slot?.status ?? .idle).tint, size: 36)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle().fill((slot?.status ?? .idle).tint).frame(width: 7, height: 7)
                    Text(verbatim: profile.name).font(.title3.weight(.semibold))
                }
                Text(profile.localizedSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var deviceBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AKL("Device")).font(.headline)
            HStack {
                Image(systemName: model.selectedPeripheral.symbol)
                    .foregroundStyle(AKTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: model.productName(for: model.selectedPeripheral))
                    if model.isConnected(model.selectedPeripheral) {
                        Text(AKL("Connected · \(model.selectedPeripheral.connection)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(AKL("Unavailable"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .akCard()
    }

    private var keyBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AKL("Online key")).font(.headline)
            HStack {
                Image(systemName: "function")
                Text(verbatim: model.dashboard.slot(forAgentID: model.selectedAgentID ?? "")?.spec.keyName ?? "—")
                    .font(.headline)
            }
            Text(AKL("Identity lamp on the function row. The board canvas follows priority automatically."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .akCard()
    }

    private var statusFeed: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AKL("Status feed")).font(.headline)
            HStack {
                Circle()
                    .fill(model.bridgeListening ? AKTheme.success : AKTheme.danger)
                    .frame(width: 7, height: 7)
                Text(model.bridgeListening ? AKL("Listening on 127.0.0.1:7420") : AKL("HTTP not listening"))
                    .font(.callout)
            }
            ForEach(model.libraryIntegrations) { spec in
                HStack {
                    Text(verbatim: spec.name)
                    Spacer()
                    Text(spec.installed ? AKL("Hook ready") : (spec.available ? AKL("Not installed") : AKL("Unavailable")))
                        .foregroundStyle(spec.installed ? AKTheme.success : .secondary)
                }
                .font(.caption)
            }
            if model.needsHookInstall {
                Text(AKL("Agent hooks are not installed. Status stays Idle until they are."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    model.installHooks()
                } label: {
                    Text(AKL("Install available hooks"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.akPrimary)
            }
        }
        .akCard()
    }

    private var stateColors: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                showStateLooks = true
            } label: {
                Text(AKL("Agent State Colors"))
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showStateLooks, arrowEdge: .leading) {
                AgentStateLooksPopover { status in
                    showStateLooks = false
                    model.openLighting(for: status)
                }
                .padding(16)
                .frame(width: 280)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                ForEach(AgentStatus.allCases) { status in
                    Button {
                        model.openLighting(for: status)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Circle()
                                .fill(model.look(for: status).color.color)
                                .frame(width: 14, height: 14)
                            Text(status.localizedTitle)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(AKTheme.inset, in: .rect(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .akCard()
    }
}

struct AgentStateLooksPopover: View {
    @Environment(AppModel.self) private var model
    var onSelect: (AgentStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AKL("Agent Lighting"))
                .font(.headline)
            ForEach(AgentStatus.allCases) { status in
                let look = model.look(for: status)
                Button {
                    onSelect(status)
                } label: {
                    HStack {
                        Circle()
                            .fill(look.color.color)
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(status.localizedTitle)
                                .font(.callout.weight(.medium))
                            HStack(spacing: 4) {
                                Text(look.localizedPaletteName)
                                Text("·")
                                Text(look.effect.localizedTitle)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
