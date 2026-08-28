import AgentKeyboardCore
import SwiftUI

struct DevicesView: View {
    @Environment(AppModel.self) private var model

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
                Text(AKL("Connected (\(model.connectedCount))"))
                    .font(.headline)
                ForEach(model.peripherals) { device in
                    DeviceCard(device: device)
                }
            }
            .padding(24)
        }
        .background(AKTheme.canvas)
        .onAppear { model.refreshDevices() }
    }
}

struct DeviceCard: View {
    @Environment(AppModel.self) private var model
    let device: PeripheralSnapshot

    var body: some View {
        Button {
            withAnimation(.snappy) { model.selectedPeripheral = device.kind }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: device.kind.symbol)
                    .font(.title)
                    .foregroundStyle(AKTheme.accent)
                    .frame(width: 48, height: 48)
                    .background(AKTheme.inset, in: .rect(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: device.name)
                        .font(.headline)
                    HStack(spacing: 8) {
                        Circle()
                            .fill(device.connected ? AKTheme.success : .secondary)
                            .frame(width: 7, height: 7)
                        Text(device.connected ? AKL("Connected") : AKL("Unavailable"))
                            .font(.caption)
                        Label {
                            Text(verbatim: device.kind.connection)
                        } icon: {
                            Image(systemName: device.kind == .keyboard ? "cable.connector" : "wifi")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    ZoneSchematic(kind: device.kind)
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
            .akSelected(model.selectedPeripheral == device.kind)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(device.name)
        .accessibilityValue(device.connected ? AKL("Connected") : AKL("Unavailable"))
    }
}

struct ZoneSchematic: View {
    var kind: PeripheralKind

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
                MousePreview(active: false, showCaption: false)
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
