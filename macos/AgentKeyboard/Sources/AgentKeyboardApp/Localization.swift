import AgentKeyboardCore
import Foundation
import SwiftUI

func AKL(_ key: String.LocalizationValue) -> LocalizedStringResource {
    LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
}

func AKString(_ key: String.LocalizationValue, locale: Locale) -> String {
    String(localized: key, bundle: .module, locale: locale)
}

enum LanguagePreference: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .system: AKL("System")
        case .english: AKL("English")
        case .simplifiedChinese: AKL("Simplified Chinese")
        }
    }

    var locale: Locale? {
        switch self {
        case .system: nil
        case .english: Locale(identifier: "en")
        case .simplifiedChinese: Locale(identifier: "zh-Hans")
        }
    }
}

extension AppearancePreference {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .system: AKL("System")
        case .dark: AKL("Dark")
        case .light: AKL("Light")
        }
    }
}

extension SidebarItem {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .devices: AKL("Devices")
        case .agents: AKL("Agents")
        case .lighting: AKL("Lighting")
        }
    }
}

extension PeripheralKind {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .keyboard: AKL("Keyboard")
        case .mouse: AKL("Mouse")
        }
    }
}

extension LightingTarget {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .fRow: AKL("F-row")
        case .main: AKL("Main Keys")
        case .numpad: AKL("Numpad")
        case .wheel: AKL("Wheel")
        case .logo: AKL("Logo")
        case .all: AKL("All Devices")
        }
    }

    var localizedMeaning: LocalizedStringResource {
        switch self {
        case .fRow: AKL("The function-key row on the keyboard.")
        case .main: AKL("The main typing area.")
        case .numpad: AKL("The numeric keypad zone on the keyboard.")
        case .wheel: AKL("The scroll wheel on the mouse.")
        case .logo: AKL("The logo LED.")
        case .all: AKL("Every mapped lighting zone.")
        }
    }
}

extension LightingEffect {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .staticFill: AKL("Static")
        case .breathing: AKL("Breathing")
        case .wave: AKL("Wave")
        case .ripple: AKL("Ripple")
        case .comet: AKL("Comet")
        case .meteor: AKL("Meteor")
        case .flow: AKL("Flow")
        case .rain: AKL("Rain")
        case .scanner: AKL("Scanner")
        case .sparkle: AKL("Sparkle")
        case .aurora: AKL("Aurora")
        case .gradient: AKL("Gradient")
        case .rainbow: AKL("Rainbow")
        case .heartbeat: AKL("Heartbeat")
        case .reactive: AKL("Reactive")
        case .off: AKL("Off")
        }
    }
}

extension AgentStatus {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .idle: AKL("Idle")
        case .running: AKL("Thinking")
        case .tool: AKL("Tool")
        case .approval: AKL("Approval")
        case .done: AKL("Done")
        case .error: AKL("Error")
        }
    }
}

extension StateLook {
    var localizedPaletteName: LocalizedStringResource {
        switch (color.r, color.g, color.b) {
        case (16, 185, 129): AKL("Green")
        case (40, 90, 255): AKL("Blue")
        case (139, 92, 246): AKL("Purple")
        case (245, 158, 11): AKL("Amber")
        case (20, 184, 166): AKL("Teal")
        case (239, 68, 68): AKL("Red")
        default: AKL("Custom")
        }
    }
}

extension AgentProfile {
    var localizedSummary: LocalizedStringResource {
        switch id {
        case "codex": AKL("Writes, refactors, and explains code.")
        case "claude": AKL("Reasoning and code collaboration.")
        case "hermes": AKL("Fast actions and task automation.")
        case "cursor": AKL("Editor-native AI pair programmer.")
        case "workbuddy": AKL("Focus sessions and smart reminders.")
        case "pi": AKL("Personal productivity")
        default: LocalizedStringResource(stringLiteral: summary)
        }
    }
}

extension AppModel.ConnectionState {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .disconnected: AKL("Disconnected")
        case .connecting: AKL("Connecting")
        case .connected(let name): LocalizedStringResource(stringLiteral: name)
        case .failed(let message): LocalizedStringResource(stringLiteral: message)
        }
    }
}
