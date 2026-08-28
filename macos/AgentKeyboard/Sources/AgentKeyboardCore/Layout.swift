public struct LedKey: Hashable, Sendable, Identifiable {
    public var id: UInt8 { keyId }
    public let keyId: UInt8
    public let name: String
    public let row: Int
    public let col: Int
    public let index: Int
}

public struct KeyboardProfile: Sendable, Equatable {
    public let name: String
    public let rows: Int
    public let cols: Int
    public let keys: [LedKey]

    public var ledCount: Int { keys.count }
    public var packetsPerFrame: Int { (ledCount + AK.ledsPerPacket - 1) / AK.ledsPerPacket }
    public var frameBufferSize: Int { packetsPerFrame * AK.reportLength }

    private let indexByKeyId: [Int]
    private let indicesByName: [String: [Int]]

    public init(name: String, rows: Int, cols: Int, raw: [(UInt8, String, Int, Int)]) {
        self.name = name
        self.rows = rows
        self.cols = cols
        let keys = raw.enumerated().map { index, item in
            LedKey(keyId: item.0, name: item.1, row: item.2, col: item.3, index: index)
        }
        self.keys = keys
        var byId = Array(repeating: -1, count: 256)
        var byName: [String: [Int]] = [:]
        for key in keys {
            byId[Int(key.keyId)] = key.index
            byName[key.name, default: []].append(key.index)
        }
        self.indexByKeyId = byId
        self.indicesByName = byName
    }

    public func key(at index: Int) -> LedKey { keys[index] }

    public func index(forKeyId keyId: UInt8) -> Int {
        indexByKeyId[Int(keyId)]
    }

    public func indices(named name: String) -> [Int] {
        indicesByName[name] ?? []
    }

    public func index(named name: String) -> Int {
        indices(named: name)[0]
    }

    public static let scopeII = KeyboardProfile(
        name: "Strix Scope II",
        rows: AK.matrixRows,
        cols: AK.matrixCols,
        raw: rawKeys
    )
}

public enum KeyNames {
    public static let agentKeys = LightingMap.scopeII.agentKeys
    public static let fRow = LightingMap.scopeII.fRow
    public static let arrows = LightingMap.scopeII.arrows
    public static let numpadBar = LightingMap.scopeII.numpadBar
}

private let rawKeys: [(UInt8, String, Int, Int)] = [
        (0x00, "ESCAPE", 0, 0),
        (0x01, "BACK_TICK", 1, 0),
        (0x02, "TAB", 2, 0),
        (0x03, "CAPS_LOCK", 3, 0),
        (0x04, "LEFT_SHIFT", 4, 0),
        (0x05, "LEFT_CONTROL", 5, 0),
        (0x11, "1", 1, 1),
        (0x0D, "LEFT_WINDOWS", 5, 1),
        (0x18, "F1", 0, 2),
        (0x19, "2", 1, 2),
        (0x12, "Q", 2, 2),
        (0x13, "A", 3, 2),
        (0x14, "Z", 4, 2),
        (0x15, "LEFT_ALT", 5, 2),
        (0x20, "F2", 0, 3),
        (0x21, "3", 1, 3),
        (0x1A, "W", 2, 3),
        (0x1B, "S", 3, 3),
        (0x1C, "X", 4, 3),
        (0x28, "F3", 0, 4),
        (0x29, "4", 1, 4),
        (0x22, "E", 2, 4),
        (0x23, "D", 3, 4),
        (0x24, "C", 4, 4),
        (0x30, "F4", 0, 5),
        (0x31, "5", 1, 5),
        (0x2A, "R", 2, 5),
        (0x2B, "F", 3, 5),
        (0x2C, "V", 4, 5),
        (0x2D, "SPACE", 5, 5),
        (0x39, "6", 1, 6),
        (0x32, "T", 2, 6),
        (0x33, "G", 3, 6),
        (0x34, "B", 4, 6),
        (0x35, "SPACE", 5, 6),
        (0x40, "F5", 0, 7),
        (0x41, "7", 1, 7),
        (0x3A, "Y", 2, 7),
        (0x3B, "H", 3, 7),
        (0x3C, "N", 4, 7),
        (0x3D, "SPACE", 5, 7),
        (0x48, "F6", 0, 8),
        (0x49, "8", 1, 8),
        (0x42, "U", 2, 8),
        (0x43, "J", 3, 8),
        (0x44, "M", 4, 8),
        (0x50, "F7", 0, 9),
        (0x51, "9", 1, 9),
        (0x4A, "I", 2, 9),
        (0x4B, "K", 3, 9),
        (0x4C, "COMMA", 4, 9),
        (0x58, "F8", 0, 10),
        (0x59, "0", 1, 10),
        (0x52, "O", 2, 10),
        (0x53, "L", 3, 10),
        (0x54, "PERIOD", 4, 10),
        (0x4D, "RIGHT_ALT", 5, 10),
        (0x60, "F9", 0, 11),
        (0x61, "MINUS", 1, 11),
        (0x5A, "P", 2, 11),
        (0x5B, "SEMICOLON", 3, 11),
        (0x5C, "FORWARD_SLASH", 4, 11),
        (0x5D, "RIGHT_FUNCTION", 5, 11),
        (0x68, "F10", 0, 12),
        (0x69, "EQUALS", 1, 12),
        (0x62, "LEFT_BRACKET", 2, 12),
        (0x63, "QUOTE", 3, 12),
        (0x65, "MENU", 5, 12),
        (0x70, "F11", 0, 13),
        (0x79, "BACKSPACE", 1, 13),
        (0x6A, "RIGHT_BRACKET", 2, 13),
        (0x7C, "RIGHT_SHIFT", 4, 13),
        (0x78, "F12", 0, 14),
        (0x7A, "ANSI_BACK_SLASH", 2, 14),
        (0x7B, "ANSI_ENTER", 3, 14),
        (0x7D, "RIGHT_CONTROL", 5, 14),
        (0x80, "PRINT_SCREEN", 0, 16),
        (0x81, "INSERT", 1, 16),
        (0x82, "DELETE", 2, 16),
        (0x85, "LEFT_ARROW", 5, 16),
        (0x88, "SCROLL_LOCK", 0, 17),
        (0x89, "HOME", 1, 17),
        (0x8A, "END", 2, 17),
        (0x8C, "UP_ARROW", 4, 17),
        (0x8D, "DOWN_ARROW", 5, 17),
        (0x90, "PAUSE_BREAK", 0, 18),
        (0x91, "PAGE_UP", 1, 18),
        (0x92, "PAGE_DOWN", 2, 18),
        (0x95, "RIGHT_ARROW", 5, 18),
        (0x99, "NUMPAD_LOCK", 1, 20),
        (0x9A, "NUMPAD_7", 2, 20),
        (0x9B, "NUMPAD_4", 3, 20),
        (0x9C, "NUMPAD_1", 4, 20),
        (0x9D, "NUMPAD_0", 5, 20),
        (0xA0, "Logo", 0, 21),
        (0xA1, "NUMPAD_DIVIDE", 1, 21),
        (0xA2, "NUMPAD_8", 2, 21),
        (0xA3, "NUMPAD_5", 3, 21),
        (0xA4, "NUMPAD_2", 4, 21),
        (0xA9, "NUMPAD_TIMES", 1, 22),
        (0xAA, "NUMPAD_9", 2, 22),
        (0xAB, "NUMPAD_6", 3, 22),
        (0xAC, "NUMPAD_3", 4, 22),
        (0xAD, "NUMPAD_PERIOD", 5, 22),
        (0xB1, "NUMPAD_MINUS", 1, 23),
        (0xB2, "NUMPAD_PLUS", 2, 23),
        (0xB4, "NUMPAD_ENTER", 4, 23)
]
