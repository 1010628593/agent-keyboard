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

        MenuBarExtra {
            StatusMenuView()
                .environment(model)
                .environment(\.locale, model.resolvedLocale)
                .frame(width: 280)
        } label: {
            Image(nsImage: StatusBarKeycapIcon.image)
                .renderingMode(.template)
                .accessibilityLabel("Agent Light")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
private enum StatusBarKeycapIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 24, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()

            let keycap = NSBezierPath()
            keycap.move(to: NSPoint(x: 2.1, y: 3.0))
            keycap.curve(
                to: NSPoint(x: 2.0, y: 4.6),
                controlPoint1: NSPoint(x: 1.4, y: 3.0),
                controlPoint2: NSPoint(x: 1.5, y: 4.0)
            )
            keycap.line(to: NSPoint(x: 5.5, y: 10.9))
            keycap.curve(
                to: NSPoint(x: 7.1, y: 11.7),
                controlPoint1: NSPoint(x: 5.8, y: 11.5),
                controlPoint2: NSPoint(x: 6.4, y: 11.8)
            )
            keycap.curve(
                to: NSPoint(x: 16.9, y: 11.7),
                controlPoint1: NSPoint(x: 10.4, y: 11.3),
                controlPoint2: NSPoint(x: 13.6, y: 11.3)
            )
            keycap.curve(
                to: NSPoint(x: 18.5, y: 10.9),
                controlPoint1: NSPoint(x: 17.6, y: 11.8),
                controlPoint2: NSPoint(x: 18.2, y: 11.5)
            )
            keycap.line(to: NSPoint(x: 22.0, y: 4.6))
            keycap.curve(
                to: NSPoint(x: 21.9, y: 3.0),
                controlPoint1: NSPoint(x: 22.5, y: 4.0),
                controlPoint2: NSPoint(x: 22.6, y: 3.0)
            )
            keycap.close()
            keycap.lineWidth = 1.55
            keycap.lineCapStyle = .round
            keycap.lineJoinStyle = .round
            keycap.stroke()

            let rays = NSBezierPath()
            rays.move(to: NSPoint(x: 7.6, y: 14.0))
            rays.line(to: NSPoint(x: 6.2, y: 15.5))
            rays.move(to: NSPoint(x: 12.0, y: 14.5))
            rays.line(to: NSPoint(x: 12.0, y: 16.7))
            rays.move(to: NSPoint(x: 16.4, y: 14.0))
            rays.line(to: NSPoint(x: 17.8, y: 15.5))
            rays.lineWidth = 1.55
            rays.lineCapStyle = .round
            rays.stroke()

            return true
        }
        image.isTemplate = true
        return image
    }()
}
