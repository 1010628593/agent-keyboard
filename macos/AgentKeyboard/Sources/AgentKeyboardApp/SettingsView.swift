import AgentKeyboardCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView {
            Tab {
                Form {
                    Section {
                        Picker(selection: $model.language) {
                            ForEach(LanguagePreference.allCases) { language in
                                Text(language.title).tag(language)
                            }
                        } label: {
                            Text(AKL("Language"))
                        }
                        .onChange(of: model.language) {
                            model.persistPreferences()
                        }
                        Picker(selection: $model.appearance) {
                            ForEach(AppearancePreference.allCases) { appearance in
                                Text(appearance.localizedTitle).tag(appearance)
                            }
                        } label: {
                            Text(AKL("Appearance"))
                        }
                        .onChange(of: model.appearance) {
                            model.persistPreferences()
                            model.applyAppearance()
                        }
                    } header: {
                        Text(AKL("General"))
                    }

                    Section {
                        Slider(value: $model.brightness, in: 0.15...1) {
                            Text(AKL("Brightness"))
                        }
                        .onChange(of: model.brightness) {
                            model.persistPreferencesDebounced()
                        }
                        Slider(value: $model.idleWhite, in: 0.01...0.25) {
                            Text(AKL("Idle brightness"))
                        } minimumValueLabel: {
                            Text(AKL("Dim"))
                        } maximumValueLabel: {
                            Text(AKL("Bright"))
                        }
                        .onChange(of: model.idleWhite) {
                            model.persistPreferencesDebounced()
                        }
                        Toggle(isOn: $model.agentLightingEnabled) {
                            Text(AKL("Agent Lighting"))
                        }
                        .onChange(of: model.agentLightingEnabled) {
                            model.persistPreferences()
                        }
                    } header: {
                        Text(AKL("Lighting"))
                    }
                }
                .formStyle(.grouped)
            } label: {
                Label {
                    Text(AKL("General"))
                } icon: {
                    Image(systemName: "gearshape")
                }
            }

            Tab {
                Form {
                    Section {
                        LabeledContent {
                            HStack(spacing: 8) {
                                Text(model.connection.localizedTitle)
                                if !model.connection.isLive {
                                    Button {
                                        model.connect()
                                    } label: {
                                        Text(AKL("Connect Keyboard"))
                                    }
                                }
                            }
                        } label: {
                            Text(AKL("Status"))
                        }
                        if let lastError = model.lastError {
                            Text(verbatim: lastError)
                                .font(.caption)
                                .foregroundStyle(AKTheme.danger)
                        }
                        Toggle(isOn: $model.simulate) {
                            Text(AKL("Simulate keyboard"))
                        }
                        .onChange(of: model.simulate) {
                            model.persistPreferences()
                            model.connect()
                        }
                        Toggle(isOn: $model.watchdogEnabled) {
                            Text(AKL("Idle watchdog"))
                        }
                        .onChange(of: model.watchdogEnabled) {
                            model.persistPreferences()
                        }
                        Text(AKL("Close Armoury Crate, OpenRGB, and the Python daemon before connecting. HTTP events stay on 127.0.0.1:7420."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text(AKL("Keyboard"))
                    }

                    Section {
                        LabeledContent {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(model.bridgeListening ? AKTheme.success : AKTheme.danger)
                                    .frame(width: 7, height: 7)
                                Text(model.bridgeListening ? AKL("Listening on 127.0.0.1:7420") : AKL("HTTP not listening"))
                            }
                        } label: {
                            Text(AKL("Bridge"))
                        }
                        LabeledContent {
                            Text("\(model.eventsInWindow)")
                                .font(.callout.monospacedDigit())
                        } label: {
                            Text(AKL("Events (last 60s)"))
                        }
                        LabeledContent {
                            Text("\(model.framesRendered)")
                                .font(.callout.monospacedDigit())
                        } label: {
                            Text(AKL("Frames rendered"))
                        }
                        LabeledContent {
                            Text(uptimeText)
                                .font(.callout.monospacedDigit())
                        } label: {
                            Text(AKL("Uptime"))
                        }
                    } header: {
                        Text(AKL("Diagnostics"))
                    }
                }
                .formStyle(.grouped)
            } label: {
                Label {
                    Text(AKL("Keyboard"))
                } icon: {
                    Image(systemName: "keyboard")
                }
            }

            Tab {
                Form {
                    Section {
                        ForEach(model.integrations) { spec in
                            HookRow(spec: spec)
                        }
                        Button {
                            model.installHooks()
                        } label: {
                            Text(AKL("Install available hooks"))
                        }
                        .disabled(model.integrations.allSatisfy { !$0.available || $0.installed })
                        Text(AKL("Merges notify.sh into existing agent configs. Does not replace mnemon or memmy hooks."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text(AKL("Agent hooks"))
                    }

                    Section {
                        LabeledContent {
                            Button {
                                model.revealAgentsConfig()
                            } label: {
                                Text(AKL("Show in Finder"))
                            }
                        } label: {
                            Text(AKL("agents.toml"))
                        }
                        Text(AKL("agents.toml stores the F1–F6 slot order and agent names."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text(AKL("Configuration"))
                    }
                }
                .formStyle(.grouped)
                .onAppear { model.refreshIntegrations() }
            } label: {
                Label {
                    Text(AKL("Agent hooks"))
                } icon: {
                    Image(systemName: "arrow.triangle.branch")
                }
            }
        }
        .environment(\.locale, model.resolvedLocale)
    }

    private var uptimeText: String {
        let t = Int(model.uptimeInterval)
        return String(format: "%d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60)
    }
}

struct HookRow: View {
    @Environment(AppModel.self) private var model
    let spec: IntegrationSpec

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                Text(verbatim: spec.name)
                    .font(.callout.weight(.medium))
                Spacer()
                Text(spec.installed ? AKL("Hook ready") : (spec.available ? AKL("Not installed") : AKL("Unavailable")))
                    .font(.caption)
                    .foregroundStyle(statusColor)
                Button {
                    model.installHook(agentID: spec.agentID)
                } label: {
                    Text(spec.installed ? AKL("Reinstall") : AKL("Install"))
                }
                .disabled(!spec.available)
            }
            Text(verbatim: spec.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(verbatim: spec.configPath)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 2)
    }

    private var statusColor: Color {
        if spec.installed { return AKTheme.success }
        if spec.available { return AKTheme.warning }
        return .secondary
    }
}

#Preview("Settings") {
    SettingsView()
        .environment(AppModel.preview)
}

#Preview("Settings 中文") {
    SettingsView()
        .environment(AppModel.previewChinese)
}
