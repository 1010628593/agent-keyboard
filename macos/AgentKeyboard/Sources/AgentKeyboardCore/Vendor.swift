import Foundation

public enum KeyboardVendor: String, Sendable, Equatable, Identifiable, CaseIterable {
    case asus
    case unknown

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .asus: "ASUS / ROG"
        case .unknown: "Other"
        }
    }

    public var implemented: Bool { self == .asus }
}

public struct DeviceIdentity: Hashable, Sendable, Identifiable, Equatable {
    public var id: String { "\(vendorID)-\(productID)-\(product)" }
    public var vendor: KeyboardVendor
    public var vendorID: UInt16
    public var productID: UInt16
    public var product: String
    public var firmware: String?
    public var layoutName: String?
    public var layoutMapped: Bool
    public var usagePage: UInt32
    public var usage: UInt32

    public init(
        vendor: KeyboardVendor,
        vendorID: UInt16,
        productID: UInt16,
        product: String,
        firmware: String? = nil,
        layoutName: String? = nil,
        layoutMapped: Bool,
        usagePage: UInt32 = AK.controlUsagePage,
        usage: UInt32 = AK.controlUsage
    ) {
        self.vendor = vendor
        self.vendorID = vendorID
        self.productID = productID
        self.product = product
        self.firmware = firmware
        self.layoutName = layoutName
        self.layoutMapped = layoutMapped
        self.usagePage = usagePage
        self.usage = usage
    }

    public var pidHex: String {
        String(format: "0x%04X", productID)
    }
}

public struct AsusProduct: Sendable, Equatable, Identifiable {
    public var id: UInt16 { productID }
    public var productID: UInt16
    public var name: String
    public var family: String
    public var layout: KeyboardProfile?

    public var layoutMapped: Bool { layout != nil }
}

public enum AsusAuraCatalog {
    public static let vendorID: UInt16 = AK.asusVendorID
    public static let ignoredProductIDs: Set<UInt16> = [
        0x1ACE, // ROG Omni Receiver (mouse dongle)
        0x1B84, // ROG Pelta
    ]

    public static let products: [AsusProduct] = [
        .init(productID: 0x1AB5, name: "ROG Strix Scope II RX", family: "ROG", layout: .scopeII),
        .init(productID: 0x1AB3, name: "ROG Strix Scope II NX", family: "ROG", layout: .scopeII),
        .init(productID: 0x19B6, name: "ROG Strix Scope RX", family: "ROG", layout: nil),
        .init(productID: 0x18A4, name: "ROG Strix Scope", family: "ROG", layout: nil),
        .init(productID: 0x1875, name: "ROG Strix Flare", family: "ROG", layout: nil),
        .init(productID: 0x18A3, name: "ROG Strix Flare II", family: "ROG", layout: nil),
        .init(productID: 0x1AAE, name: "ROG Claymore II", family: "ROG", layout: nil),
        .init(productID: 0x18AA, name: "TUF Gaming K3", family: "TUF", layout: nil),
        .init(productID: 0x1A05, name: "TUF Gaming K1", family: "TUF", layout: nil),
        .init(productID: 0x1AED, name: "TUF Gaming K5", family: "TUF", layout: nil),
    ]

    public static let mappedProductIDs: Set<UInt16> = Set(
        products.filter(\.layoutMapped).map(\.productID)
    )

    public static func known(for productID: UInt16) -> AsusProduct? {
        products.first { $0.productID == productID }
    }

    public static func isIgnored(_ productID: UInt16) -> Bool {
        ignoredProductIDs.contains(productID)
    }

    public static func identity(
        productID: UInt16,
        product: String,
        firmware: String? = nil
    ) -> DeviceIdentity {
        let known = known(for: productID)
        return DeviceIdentity(
            vendor: .asus,
            vendorID: vendorID,
            productID: productID,
            product: product.isEmpty ? (known?.name ?? "ASUS Keyboard") : product,
            firmware: firmware,
            layoutName: known?.layout?.name,
            layoutMapped: known?.layoutMapped ?? false
        )
    }

    public static func lightingMap(for productID: UInt16) -> LightingMap? {
        guard let profile = known(for: productID)?.layout else { return nil }
        return LightingMap.scopeII(profile: profile)
    }
}

public protocol KeyboardDriver: AnyObject {
    var isOpen: Bool { get }
    var identity: DeviceIdentity { get }
    var lightingMap: LightingMap { get }
    func open() throws
    func writePixels(_ pixels: [RGB]) throws
    func restoreStatic(color: RGB, brightness: Int) throws
    func close()
}

public enum LightingZone: String, CaseIterable, Sendable, Equatable, Identifiable, Hashable {
    case agents
    case escape
    case enter
    case space
    case arrows
    case numpad
    case rest

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .agents: "Agent keys"
        case .escape: "Esc"
        case .enter: "Enter"
        case .space: "Space"
        case .arrows: "Arrows"
        case .numpad: "NumPad"
        case .rest: "Idle field"
        }
    }

    public var meaning: String {
        switch self {
        case .agents: "F1–F6 status lamps"
        case .escape: "Error / cancel"
        case .enter: "Approval"
        case .space: "Running flow"
        case .arrows: "Activity"
        case .numpad: "Context / progress"
        case .rest: "Dim white idle"
        }
    }
}

public enum LightingTarget: String, CaseIterable, Sendable, Equatable, Identifiable, Hashable {
    case fRow
    case main
    case numpad
    case wheel
    case logo
    case all

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .fRow: "F-row"
        case .main: "Main Keys"
        case .numpad: "Numpad"
        case .wheel: "Wheel"
        case .logo: "Logo"
        case .all: "All Devices"
        }
    }

    public var meaning: String {
        switch self {
        case .fRow: "The function-key row on the keyboard."
        case .main: "The main typing area."
        case .numpad: "The numeric keypad zone on the keyboard."
        case .wheel: "The scroll wheel on the mouse."
        case .logo: "The logo LED."
        case .all: "Every mapped lighting zone."
        }
    }

    public var symbol: String {
        switch self {
        case .fRow: "circle.grid.3x1"
        case .main: "square.grid.3x3"
        case .numpad: "square.grid.3x3.fill"
        case .wheel: "computermouse"
        case .logo: "sparkle"
        case .all: "square.resize"
        }
    }

    public var isMouse: Bool { self == .wheel }

    public var implemented: Bool { self != .wheel }

    public static let keyboardZones: [LightingTarget] = [.fRow, .main, .numpad]
    public static let mouseZones: [LightingTarget] = [.wheel]
}

public struct LightingMap: Sendable {
    public let profile: KeyboardProfile
    public let agentKeys: [String]
    public let fRow: [String]
    public let escape: String
    public let enter: String
    public let space: String
    public let arrows: [String]
    public let numpadBar: [String]
    public let toolCluster: [String]

    public var rows: Int { profile.rows }
    public var cols: Int { profile.cols }
    public var ledCount: Int { profile.ledCount }

    public var agentKeySet: Set<String> { Set(agentKeys) }

    public var canvasNames: [String] {
        Array(Set(profile.keys.map(\.name).filter { !agentKeySet.contains($0) }))
    }

    public init(
        profile: KeyboardProfile,
        agentKeys: [String],
        fRow: [String],
        escape: String,
        enter: String,
        space: String,
        arrows: [String],
        numpadBar: [String],
        toolCluster: [String]
    ) {
        self.profile = profile
        self.agentKeys = agentKeys
        self.fRow = fRow
        self.escape = escape
        self.enter = enter
        self.space = space
        self.arrows = arrows
        self.numpadBar = numpadBar
        self.toolCluster = toolCluster
    }

    public func names(for zone: LightingZone) -> [String] {
        switch zone {
        case .agents: agentKeys
        case .escape: [escape]
        case .enter: [enter]
        case .space: [space]
        case .arrows: arrows
        case .numpad: numpadBar
        case .rest: []
        }
    }

    public func names(for target: LightingTarget) -> [String] {
        switch target {
        case .fRow:
            return fRow
        case .numpad:
            return numpadBar
        case .logo:
            return ["Logo"]
        case .wheel:
            return []
        case .all:
            return Array(Set(profile.keys.map(\.name)))
        case .main:
            let skip = Set(fRow + numpadBar + ["Logo"])
            return Array(Set(profile.keys.map(\.name).filter { !skip.contains($0) }))
        }
    }

    public static let scopeII = LightingMap.scopeII(profile: .scopeII)

    public static func scopeII(profile: KeyboardProfile) -> LightingMap {
        LightingMap(
            profile: profile,
            agentKeys: ["F1", "F2", "F3", "F4", "F5", "F6"],
            fRow: ["F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"],
            escape: "ESCAPE",
            enter: "ANSI_ENTER",
            space: "SPACE",
            arrows: ["LEFT_ARROW", "DOWN_ARROW", "UP_ARROW", "RIGHT_ARROW"],
            numpadBar: [
                "NUMPAD_0", "NUMPAD_1", "NUMPAD_2", "NUMPAD_3", "NUMPAD_4", "NUMPAD_5",
                "NUMPAD_6", "NUMPAD_7", "NUMPAD_8", "NUMPAD_9", "NUMPAD_PERIOD",
                "NUMPAD_ENTER", "NUMPAD_PLUS", "NUMPAD_MINUS", "NUMPAD_TIMES",
                "NUMPAD_DIVIDE", "NUMPAD_LOCK",
            ],
            toolCluster: ["Q", "W", "E", "A", "S", "D", "Z", "X", "C"]
        )
    }
}
