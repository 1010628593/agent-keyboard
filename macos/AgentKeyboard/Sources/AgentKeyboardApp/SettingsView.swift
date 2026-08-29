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
                        LabeledContent {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(model.bridgeListening ? AKTheme.success : AKTheme.danger)
                                    .frame(width: 7, height: 7)
                                Text(model.bridgeListening ? AKL("Listening") : AKL("Not listening"))
                            }
                        } label: {
                            Text(AKL("Service"))
                        }
                        LabeledContent {
                            HStack(spacing: 8) {
                                Text(verbatim: model.mcpEndpoint)
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Button {
                                    model.copyMCPEndpoint()
                                } label: {
                                    Text(model.mcpCopied == .endpoint ? AKL("Copied") : AKL("Copy"))
                                }
                            }
                        } label: {
                            Text(AKL("Endpoint"))
                        }
                        LabeledContent {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(model.mcpOverlayActive ? AKTheme.accent : .secondary)
                                    .frame(width: 7, height: 7)
                                if model.mcpOverlayActive {
                                    Text(verbatim: String(format: "%.1fs", model.mcpOverlayRemaining))
                                        .font(.callout.monospacedDigit())
                                } else {
                                    Text(AKL("Cookbook"))
                                }
                            }
                        } label: {
                            Text(AKL("Overlay"))
                        }
                    } header: {
                        Text(AKL("MCP service"))
                    } footer: {
                        Text(AKL("The MCP server shares 127.0.0.1:7420 with the HTTP bridge. Open Agent Light first, then connect Cursor."))
                    }

                    Section {
                        LabeledContent {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(model.mcpConfig.installed ? AKTheme.success : AKTheme.warning)
                                    .frame(width: 7, height: 7)
                                Text(model.mcpConfig.installed ? AKL("Configured") : AKL("Not configured"))
                            }
                        } label: {
                            Text(AKL("Cursor mcp.json"))
                        }
                        Text(verbatim: model.mcpConfig.configPath)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                        Text(verbatim: model.mcpConfig.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            model.installCursorMCP()
                        } label: {
                            Text(model.mcpConfig.installed ? AKL("Reinstall Cursor MCP") : AKL("Install Cursor MCP"))
                        }
                    } header: {
                        Text(AKL("One-click setup"))
                    } footer: {
                        Text(AKL("Writes the endpoint into ~/.cursor/mcp.json without removing other MCP servers. Enable agent-keyboard in Cursor Settings → MCP, then allow the tools."))
                    }

                    Section {
                        Text(AKL("MCP lighting is a per-key pixel layer. It does not use Wave, Comet, or other cookbook effects. The agent names keys, colors, duration, and brightness."))
                            .font(.callout)
                        Text(AKL("duration is required and maxes out at 15 seconds. brightness is 0–1 and scales every key in the lease. Per-key colors may also include their own brightness."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(AKL("keyboard_keys holds a still. keyboard_frames loops or plays a segmented story. When the lease ends, cookbook lighting resumes. Hooks still drive F1–F6 identity independently."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text(AKL("How it works"))
                    }

                    Section {
                        Text(verbatim: MCPService.setupPrompt)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack {
                            Button {
                                model.copyMCPSetupPrompt()
                            } label: {
                                Text(model.mcpCopied == .prompt ? AKL("Copied") : AKL("Copy setup prompt"))
                            }
                            Button {
                                model.copyMCPJSON()
                            } label: {
                                Text(model.mcpCopied == .json ? AKL("Copied") : AKL("Copy mcp.json"))
                            }
                        }
                    } header: {
                        Text(AKL("Configuration prompt"))
                    } footer: {
                        Text(AKL("Paste the prompt into a Cursor chat after installing, or share it with another agent so it connects itself."))
                    }
                }
                .formStyle(.grouped)
                .onAppear { model.refreshIntegrations() }
            } label: {
                Label {
                    Text(AKL("MCP"))
                } icon: {
                    Image(systemName: "cable.connector")
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
                        Text(AKL("Codex skips new hook commands until you trust them in /hooks."))
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
                Text(statusLabel)
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

    private var statusLabel: LocalizedStringResource {
        if spec.kind == .cursorMCP {
            return spec.installed ? AKL("Configured") : AKL("Not configured")
        }
        if spec.installed { return AKL("Hook ready") }
        return spec.available ? AKL("Not installed") : AKL("Unavailable")
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
