import AgentKeyboardCore
import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.shutdown()
    }
}

@main
struct AgentKeyboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("Agent Light", id: "main") {
            AppShell()
                .environment(model)
                .environment(\.locale, model.resolvedLocale)
                .frame(minWidth: 1100, minHeight: 680)
                .task {
                    appDelegate.model = model
                    model.start()
                }
        }
        .defaultSize(width: 1280, height: 820)
        .defaultPosition(.center)
        .defaultLaunchBehavior(.presented)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(after: .newItem) {
                Button {
                    model.connect()
                } label: {
                    Text(AKL("Connect Keyboard"))
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
                Button {
                    model.idleAll()
                } label: {
                    Text(AKL("Idle All Agents"))
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                Button {
                    model.runDemo()
                } label: {
                    Text(AKL("Play Demo"))
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environment(model)
                .environment(\.locale, model.resolvedLocale)
                .frame(minWidth: 360, minHeight: 220)
                .scenePadding()
        }

        MenuBarExtra("Agent Light", systemImage: "keyboard") {
            StatusMenuView()
                .environment(model)
                .environment(\.locale, model.resolvedLocale)
                .frame(width: 280)
        }
        .menuBarExtraStyle(.window)
    }
}
