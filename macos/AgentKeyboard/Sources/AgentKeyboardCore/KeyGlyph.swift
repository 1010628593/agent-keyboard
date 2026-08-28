import Foundation

/// 5×5 pixel font for the letter cluster (number row through ZXCV, plus a sparse bottom row).
public struct KeyGlyph: Equatable, Sendable {
    /// Five rows; bit 4 is the left column (x = 0).
    public let rows: [UInt8]

    public init(rows: [UInt8]) {
        precondition(rows.count == 5)
        self.rows = rows
    }

    public func lit(x: Int, y: Int) -> Bool {
        guard y >= 0, y < 5, x >= 0, x < 5 else { return false }
        return rows[y] & (1 << (4 - x)) != 0
    }

    public static func forAgent(_ agentID: String) -> KeyGlyph {
        switch agentID {
        case "codex": letterC
        case "claude": sparkle
        case "hermes": letterH
        case "cursor": chevron
        case "workbuddy": letterW
        case "pi": letterP
        default: letterC
        }
    }

    public static let originRow = 1
    public static let originCol = 3
    public static let size = 5

    public static let letterC = KeyGlyph(rows: [
        0b01110,
        0b10001,
        0b10000,
        0b10001,
        0b01110,
    ])

    public static let letterH = KeyGlyph(rows: [
        0b10001,
        0b10001,
        0b11111,
        0b10001,
        0b10001,
    ])

    public static let letterW = KeyGlyph(rows: [
        0b10001,
        0b10001,
        0b10101,
        0b11011,
        0b10001,
    ])

    public static let letterP = KeyGlyph(rows: [
        0b11110,
        0b10001,
        0b11110,
        0b10000,
        0b10000,
    ])

    public static let sparkle = KeyGlyph(rows: [
        0b00100,
        0b10101,
        0b01110,
        0b10101,
        0b00100,
    ])

    public static let chevron = KeyGlyph(rows: [
        0b10000,
        0b01100,
        0b00110,
        0b01100,
        0b10000,
    ])
}
