import AgentKeyboardCore
import SwiftUI

struct DevicesView: View {
    @Environment(AppModel.self) private var model

    private var connected: [PeripheralSnapshot] { model.peripherals.filter(\.connected) }
    private var unavailable: [PeripheralSnapshot] { model.peripherals.filter { !$0.connected } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AKL("Devices"))
                        .font(.largeTitle.weight(.semibold))
                    Label {
                        Text(AKL("Connected devices are recognized automatically."))
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                deviceSection(
                    title: AKL("Connected (\(connected.count))"),
                    devices: connected,
                    emptyText: AKL("No connected devices")
                )
                if !unavailable.isEmpty {
                    deviceSection(
                        title: AKL("Unavailable (\(unavailable.count))"),
                        devices: unavailable,
                        emptyText: nil
                    )
                }
            }
            .padding(24)
        }
        .background(AKTheme.canvas)
        .onAppear { model.refreshDevices() }
    }

    private func deviceSection(
        title: LocalizedStringResource,
        devices: [PeripheralSnapshot],
        emptyText: LocalizedStringResource?
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            if devices.isEmpty, let emptyText {
                Text(emptyText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(AKTheme.card, in: .rect(cornerRadius: AKTheme.radiusL))
            }
            ForEach(devices) { device in
                DeviceCard(device: device)
            }
        }
    }
}

struct DeviceCard: View {
    @Environment(AppModel.self) private var model
    let device: PeripheralSnapshot

    var body: some View {
        Button {
            withAnimation(.snappy) { model.selectPeripheral(device) }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: device.kind.symbol)
                    .font(.title)
                    .foregroundStyle(device.connected ? AKTheme.accent : Color.secondary)
                    .frame(width: 48, height: 48)
                    .background(AKTheme.inset, in: .rect(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: device.name)
                        .font(.headline)
                    HStack(spacing: 8) {
                        Circle()
                            .fill(device.connected ? AKTheme.success : Color.secondary)
                            .frame(width: 7, height: 7)
                        Text(device.connected ? AKL("Connected") : AKL("Unavailable"))
                            .font(.caption)
                            .foregroundStyle(device.connected ? .primary : .secondary)
                        Label {
                            Text(device.connectionKind.localizedTitle)
                        } icon: {
                            Image(systemName: device.connectionKind.symbol)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    ZoneSchematic(kind: device.kind, active: device.connected, previewHeight: 38)
                        .frame(height: 44)
                }
                Spacer()
                if device.connected {
                    Label {
                        Text(AKL("Connected"))
                    } icon: {
                        Image(systemName: "checkmark")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AKTheme.success)
                }
            }
            .padding(14)
            .background(AKTheme.card, in: .rect(cornerRadius: AKTheme.radiusL))
            .opacity(device.connected ? 1 : 0.6)
            .akSelected(model.selectedPeripheralID == device.id)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(device.name)
        .accessibilityValue(device.connected ? AKL("Connected") : AKL("Unavailable"))
    }
}

struct ZoneSchematic: View {
    var kind: PeripheralKind
    var active: Bool = false
    /// Height budget for the mouse capsule; ignored by the keyboard canvas,
    /// which scales via its aspect ratio.
    var previewHeight: CGFloat = 64

    var body: some View {
        Group {
            if kind == .keyboard {
                KeyboardPreview(
                    pixels: SceneRenderer.renderBoard(
                        Dashboard(),
                        looks: AgentLookBook.seeded(),
                        now: 0.4,
                        globalBrightness: 0.8
                    ),
                    highlight: Set(LightingMap.scopeII.agentKeys)
                )
            } else {
                MousePreview(active: active, showCaption: false, height: previewHeight)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview("Devices Dark") {
    DevicesView()
        .environment(AppModel.preview)
        .preferredColorScheme(.dark)
        .frame(width: 900, height: 640)
}

#Preview("Devices 中文") {
    DevicesView()
        .environment(AppModel.previewChinese)
        .preferredColorScheme(.dark)
        .frame(width: 900, height: 640)
}
