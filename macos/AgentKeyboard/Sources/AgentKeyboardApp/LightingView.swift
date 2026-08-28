import AgentKeyboardCore
import SwiftUI

struct LightingView: View {
    @Environment(AppModel.self) private var model

    private let effectColumns = [GridItem(.adaptive(minimum: 96), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AKL("Lighting"))
                        .font(.largeTitle.weight(.semibold))
                    Text(AKL("Choose an effect and colors for this agent's scheme. It fills the whole keyboard."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                LightingStage()
                stepHeader(1, AKL("Select Device"))
                HStack(spacing: 10) {
                    ForEach(PeripheralKind.allCases) { kind in
                        DevicePickButton(kind: kind)
                    }
                }
                stepHeader(2, AKL("Select Effect"))
                LazyVGrid(columns: effectColumns, spacing: 10) {
                    ForEach(LightingEffect.allCases) { effect in
                        EffectPickButton(effect: effect)
                    }
                }
            }
            .padding(24)
        }
        .background(AKTheme.canvas)
    }

    private func stepHeader(_ n: Int, _ title: LocalizedStringResource) -> some View {
        Label {
            Text(title).font(.headline)
        } icon: {
            Text("\(n)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(AKTheme.accent, in: .circle)
        }
    }
}

struct LightingStage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .bottom, spacing: 20) {
            KeyboardPreview(
                pixels: model.lastPixels,
                map: model.lightingMap,
                highlight: Set(model.lightingMap.canvasNames)
            )
            MousePreview(active: model.selectedPeripheral == .mouse, showCaption: true)
                .frame(width: 72, height: 110)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(AKTheme.keyWell, in: .rect(cornerRadius: AKTheme.radiusL))
        .overlay {
            RoundedRectangle(cornerRadius: AKTheme.radiusL)
                .strokeBorder(AKTheme.accent.opacity(0.55), lineWidth: 1)
        }
        .compositingGroup()
    }
}

struct DevicePickButton: View {
    @Environment(AppModel.self) private var model
    let kind: PeripheralKind

    var body: some View {
        Button {
            withAnimation(.snappy) {
                model.selectedPeripheral = kind
            }
        } label: {
            Label {
                Text(kind.localizedTitle)
            } icon: {
                Image(systemName: kind.symbol)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AKTheme.card, in: .rect(cornerRadius: 10))
            .akSelected(model.selectedPeripheral == kind, radius: 10)
        }
        .buttonStyle(.plain)
        .accessibilityHint(kind == .mouse ? AKL("Mouse lighting is preview only") : LocalizedStringResource(stringLiteral: ""))
    }
}

struct EffectPickButton: View {
    @Environment(AppModel.self) private var model
    let effect: LightingEffect

    var body: some View {
        Button {
            withAnimation(.snappy) { model.setEffect(effect) }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: effect.symbol)
                    .font(.title2)
                Text(effect.localizedTitle)
                    .font(.caption)
            }
            .foregroundStyle(model.look(for: model.lightingState).effect == effect ? AKTheme.accent : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AKTheme.card, in: .rect(cornerRadius: 10))
            .akSelected(model.look(for: model.lightingState).effect == effect, radius: 10)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Lighting Dark") {
    LightingView()
        .environment(AppModel.preview)
        .preferredColorScheme(.dark)
        .frame(width: 980, height: 820)
}

#Preview("Lighting 中文") {
    LightingView()
        .environment(AppModel.previewChinese)
        .preferredColorScheme(.dark)
        .frame(width: 980, height: 820)
}
