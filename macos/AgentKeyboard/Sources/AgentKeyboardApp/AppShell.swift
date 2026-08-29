import AgentKeyboardCore
import SwiftUI

struct AppShell: View {
    @Environment(AppModel.self) private var model
    @State private var inspectorPresented = true

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
        }
        .inspector(isPresented: $inspectorPresented) {
            InspectorPane()
                .inspectorColumnWidth(min: 260, ideal: 300, max: 360)
        }
        .onChange(of: model.sidebar) { _, item in
            if item == .lighting {
                model.selectedPeripheral = .keyboard
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    inspectorPresented.toggle()
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
        .preferredColorScheme(model.appearance.colorScheme)
        .environment(\.locale, model.resolvedLocale)
        .onAppear { model.applyAppearance() }
        .onChange(of: model.appearance) { model.applyAppearance() }
    }
}

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 8) {
            ForEach(SidebarItem.allCases) { item in
                Button {
                    withAnimation(.snappy) { model.sidebar = item }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: item.symbol)
                            .font(.title3)
                        Text(item.localizedTitle)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(model.sidebar == item ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        model.sidebar == item ? AKTheme.accent.opacity(0.4) : Color.clear,
                        in: .rect(cornerRadius: 12)
                    )
                    .overlay {
                        if model.sidebar == item {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(AKTheme.accent.opacity(0.8), lineWidth: 1)
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
        .background(AKTheme.sidebar)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AKTheme.cardBorder)
                .frame(width: 1)
                .allowsHitTesting(false)
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
