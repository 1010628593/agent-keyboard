import AgentKeyboardCore
import SwiftUI

enum PeripheralKind: String, CaseIterable, Identifiable, Hashable {
    case keyboard
    case mouse

    var id: String { rawValue }

    var product: String {
        switch self {
        case .keyboard: "ROG STRIX SCOPE II RX"
        case .mouse: "ROG Harpe Ace"
        }
    }

    var connection: String {
        switch self {
        case .keyboard: "USB"
        case .mouse: "2.4G"
        }
    }

    var symbol: String {
        switch self {
        case .keyboard: "keyboard"
        case .mouse: "computermouse"
        }
    }

    var zones: [LightingTarget] {
        switch self {
        case .keyboard: LightingTarget.keyboardZones
        case .mouse: LightingTarget.mouseZones
        }
    }

    var implemented: Bool { self == .keyboard }
}

struct PeripheralSnapshot: Identifiable, Equatable {
    var kind: PeripheralKind
    var name: String
    var connected: Bool
    var id: String { kind.rawValue }
}

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case devices
    case agents
    case lighting

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .devices: "keyboard"
        case .agents: "person.3"
        case .lighting: "lightbulb.fill"
        }
    }
}
