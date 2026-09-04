import AgentKeyboardCore
import AppKit
import SwiftUI

struct AppShell: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @State private var inspectorPresented = false

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 176, ideal: 188, max: 216)
                .background {
                    SidebarGlassBackground()
                        .ignoresSafeArea()
                }
        } detail: {
            HStack(spacing: 0) {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                AKTheme.canvas
                    .ignoresSafeArea()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
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
                                .foregroundStyle(model.peripheral(for: .keyboard).connected ? AKTheme.success : .secondary)
                            Text(model.toolbarConnectionText)
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

private struct SidebarGlassBackground: NSViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme

    func makeNSView(context: Context) -> NSView {
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = 0
            glass.style = .regular
            let tintLayer = NSView()
            tintLayer.wantsLayer = true
            glass.contentView = tintLayer
            configure(glass)
            return glass
        }

        let material = NSVisualEffectView()
        material.material = .sidebar
        material.blendingMode = .behindWindow
        material.state = .followsWindowActiveState
        return material
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if #available(macOS 26.0, *), let glass = nsView as? NSGlassEffectView {
            configure(glass)
        }
    }

    @available(macOS 26.0, *)
    private func configure(_ glass: NSGlassEffectView) {
        glass.tintColor = colorScheme == .dark
            ? NSColor(srgbRed: 0.180, green: 0.150, blue: 0.320, alpha: 0.24)
            : NSColor(srgbRed: 0.900, green: 0.920, blue: 1.000, alpha: 0.12)

        glass.contentView?.layer?.backgroundColor = colorScheme == .dark
            ? NSColor(srgbRed: 0.020, green: 0.030, blue: 0.070, alpha: 0.90).cgColor
            : NSColor(srgbRed: 0.940, green: 0.960, blue: 1.000, alpha: 0.46).cgColor

        if #available(macOS 27.0, *) {
            glass.effectIsInteractive = true
        }
    }
}

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(AKL("Control Center"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.bottom, 7)

            VStack(spacing: 4) {
                ForEach(SidebarItem.allCases) { item in
                    SidebarNavigationRow(
                        item: item,
                        selected: model.sidebar == item
                    ) {
                        withAnimation(.snappy) { model.navigate(to: item) }
                    }
                }
            }

            Spacer()

            Divider()
                .padding(.horizontal, 8)
                .padding(.bottom, 8)

            SettingsLink {
                SidebarUtilityLabel(title: AKL("Settings"), symbol: "gearshape")
            }
            .buttonStyle(.plain)
            .help(AKL("Settings"))

            HStack(spacing: 10) {
                Image(systemName: "a.square.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AKTheme.accent)
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                Text(AKL("Agent Light"))
                    .font(.callout.weight(.semibold))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 10)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SidebarNavigationRow: View {
    let item: SidebarItem
    let selected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: item.symbol)
                    .font(.system(size: item.sidebarSymbolSize, weight: .medium))
                    .symbolRenderingMode(.monochrome)
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                Text(item.localizedTitle)
                    .font(.callout.weight(selected ? .semibold : .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(selected ? AKTheme.accent : .primary)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        selected
                            ? AKTheme.sidebarSelection
                            : (isHovered ? AKTheme.sidebarHover : .clear)
                    )
            }
            .contentShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(selected ? .isSelected : [])
        .animation(.snappy, value: selected)
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

private struct SidebarUtilityLabel: View {
    let title: LocalizedStringResource
    let symbol: String
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .symbolRenderingMode(.monochrome)
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
            Text(title)
                .font(.callout.weight(.medium))
            Spacer(minLength: 0)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        .background(AKTheme.sidebarHover.opacity(isHovered ? 1 : 0), in: .rect(cornerRadius: 10))
        .contentShape(.rect(cornerRadius: 10))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

private extension SidebarItem {
    var sidebarSymbolSize: CGFloat {
        switch self {
        case .devices: 15
        case .agents: 14
        case .lighting: 16
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
