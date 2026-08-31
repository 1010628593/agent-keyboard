import AgentKeyboardCore
import SwiftUI

struct AppShell: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @State private var inspectorPresented = false

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: 96)
            Group {
                switch model.sidebar {
                case .devices: DevicesView()
                case .agents: AgentsView()
                case .lighting: LightingView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AKTheme.canvas)
            if inspectorPresented, model.sidebar != .lighting {
                Divider()
                InspectorPane()
                    .frame(width: 300)
                    .frame(maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: model.productName(for: .keyboard))
                            .font(.caption.weight(.medium))
                        HStack(spacing: 4) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5))
                                .foregroundStyle(model.connection.isLive ? AKTheme.success : .secondary)
                            Text(model.connection.isLive ? AKL("Connected · USB") : AKL("Unavailable"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Picker(AKL("Appearance"), selection: appearanceBinding) {
                    ForEach([AppearancePreference.light, .dark]) { appearance in
                        Text(appearance.localizedTitle).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 116)

                Label {
                    Text(model.bridgeListening ? AKL("Listening on 127.0.0.1:7420") : AKL("HTTP not listening"))
                } icon: {
                    Image(systemName: model.bridgeListening ? "dot.radiowaves.left.and.right" : "exclamationmark.circle")
                }
                .font(.caption)
                .foregroundStyle(model.bridgeListening ? AKTheme.success : .secondary)

                if model.sidebar != .lighting {
                    Button {
                        withAnimation(.snappy) { inspectorPresented.toggle() }
                    } label: {
                        Label {
                            Text(AKL("Inspector"))
                        } icon: {
                            Image(systemName: "sidebar.trailing")
                        }
                    }
                    .help(AKL("Inspector"))
                }
            }
        }
        .preferredColorScheme(model.appearance.colorScheme)
        .environment(\.locale, model.resolvedLocale)
        .onAppear { model.applyAppearance() }
        .onChange(of: model.appearance) { model.applyAppearance() }
    }

    private var appearanceBinding: Binding<AppearancePreference> {
        Binding {
            if model.appearance == .system {
                return colorScheme == .dark ? .dark : .light
            }
            return model.appearance
        } set: { appearance in
            model.appearance = appearance
            model.persistPreferences()
            model.applyAppearance()
        }
    }
}

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 8) {
            ForEach(SidebarItem.allCases) { item in
                Button {
                    withAnimation(.snappy) { model.navigate(to: item) }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: item.symbol)
                            .font(.title3)
                            .symbolVariant(model.sidebar == item ? .fill : .none)
                            .shadow(
                                color: model.sidebar == item ? AKTheme.accent.opacity(0.42) : .clear,
                                radius: 7
                            )
                        Text(item.localizedTitle)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(model.sidebar == item ? AKTheme.accent : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.clear)
                    .modifier(SidebarSelectionSurface(selected: model.sidebar == item))
                    .overlay {
                        if model.sidebar == item {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(AKTheme.accent.opacity(0.82), lineWidth: 1.5)
                                .allowsHitTesting(false)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .animation(.snappy, value: model.sidebar)
            }
            Spacer()
            Image(systemName: "a.square.fill")
                .font(.title2)
                .foregroundStyle(AKTheme.accent)
                .accessibilityLabel(AKL("Agent Light"))
            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(.rect)
            }
            .help(AKL("Settings"))
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 10)
        .padding(.top, 12)
        .frame(maxHeight: .infinity)
        .background(.thinMaterial)
        .background(AKTheme.sidebar)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AKTheme.cardBorder)
                .frame(width: 1)
                .allowsHitTesting(false)
        }
    }
}

private struct SidebarSelectionSurface: ViewModifier {
    var selected: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if selected {
            content.akGlassSurface(
                radius: 14,
                tint: AKTheme.accent.opacity(0.15),
                interactive: true
            )
        } else {
            content
        }
    }
}

#Preview("Shell Dark") {
    AppShell()
        .environment(AppModel.preview)
        .preferredColorScheme(.dark)
        .frame(width: 1280, height: 820)
}

#Preview("Shell Light") {
    AppShell()
        .environment(AppModel.preview)
        .preferredColorScheme(.light)
        .frame(width: 1280, height: 820)
}

#Preview("Shell 中文") {
    AppShell()
        .environment(AppModel.previewChinese)
        .preferredColorScheme(.dark)
        .frame(width: 1280, height: 820)
}
