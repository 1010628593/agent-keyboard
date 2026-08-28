import AgentKeyboardCore
import AppKit
import SwiftUI

struct StatusMenuView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(AKTheme.accent)
                Text(AKL("Agent Light"))
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(model.connection.isLive ? AKTheme.success : AKTheme.warning)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel(model.connection.localizedTitle)
            }
            ForEach(AgentProfile.library) { profile in
                let slot = model.dashboard.slot(forAgentID: profile.id)
                HStack {
                    Circle()
                        .fill(model.look(for: slot?.status ?? .idle, agentID: profile.id).color.color)
                        .frame(width: 8, height: 8)
                    Text(verbatim: profile.name)
                    Spacer()
                    Text(verbatim: slot?.spec.keyName ?? "—")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text((slot?.status ?? .idle).localizedTitle)
                        .font(.caption)
                        .foregroundStyle((slot?.status ?? .idle).tint)
                }
                .accessibilityElement(children: .combine)
            }
            Divider()
            Button {
                openWindow(id: "main")
            } label: {
                Label {
                    Text(AKL("Open Agent Light"))
                } icon: {
                    Image(systemName: "macwindow")
                }
            }
            SettingsLink {
                Label {
                    Text(AKL("Settings"))
                } icon: {
                    Image(systemName: "gear")
                }
            }
            Button {
                model.idleAll()
            } label: {
                Text(AKL("Idle All"))
            }
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text(AKL("Quit Agent Light"))
            }
        }
        .padding(14)
        .environment(\.locale, model.resolvedLocale)
    }
}

#Preview("Menu extra") {
    StatusMenuView()
        .environment(AppModel())
}
