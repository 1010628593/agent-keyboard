import Foundation

public struct RGB: Hashable, Sendable, Equatable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8

    public init(_ r: UInt8, _ g: UInt8, _ b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }

    public static let black = RGB(0, 0, 0)
    public static let white = RGB(255, 255, 255)
    public static let running = RGB(40, 120, 255)
    public static let tool = RGB(160, 70, 255)
    public static let approval = RGB(255, 140, 30)
    public static let done = RGB(40, 210, 90)
    public static let error = RGB(255, 40, 40)
    public static let contextOK = RGB(40, 160, 90)
    public static let contextWarn = RGB(255, 200, 40)
    public static let contextHot = RGB(255, 40, 40)

    public func scaled(_ k: Double) -> RGB {
        RGB(
            UInt8(clamping: Int((Double(r) * k).rounded())),
            UInt8(clamping: Int((Double(g) * k).rounded())),
            UInt8(clamping: Int((Double(b) * k).rounded()))
        )
    }

    public func max(with other: RGB) -> RGB {
        RGB(Swift.max(r, other.r), Swift.max(g, other.g), Swift.max(b, other.b))
    }

    public var isBlack: Bool { r == 0 && g == 0 && b == 0 }

    public static func lerp(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
        let t = Swift.min(1, Swift.max(0, t))
        return RGB(
            UInt8(Int(Double(a.r) + Double(Int(b.r) - Int(a.r)) * t)),
            UInt8(Int(Double(a.g) + Double(Int(b.g) - Int(a.g)) * t)),
            UInt8(Int(Double(a.b) + Double(Int(b.b) - Int(a.b)) * t))
        )
    }

    public static func hsv(_ hue: Double, saturation: Double = 0.85, value: Double = 1) -> RGB {
        let h = ((hue.truncatingRemainder(dividingBy: 1)) + 1).truncatingRemainder(dividingBy: 1)
        let s = Swift.min(1, Swift.max(0, saturation))
        let v = Swift.min(1, Swift.max(0, value))
        let i = Int(h * 6)
        let f = h * 6 - Double(i)
        let p = v * (1 - s)
        let q = v * (1 - f * s)
        let t = v * (1 - (1 - f) * s)
        let rgb: (Double, Double, Double)
        switch i % 6 {
        case 0: rgb = (v, t, p)
        case 1: rgb = (q, v, p)
        case 2: rgb = (p, v, t)
        case 3: rgb = (p, q, v)
        case 4: rgb = (t, p, v)
        default: rgb = (v, p, q)
        }
        return RGB(
            UInt8((rgb.0 * 255).rounded()),
            UInt8((rgb.1 * 255).rounded()),
            UInt8((rgb.2 * 255).rounded())
        )
    }

    public var luminance: Int { Int(r) + Int(g) + Int(b) }
}
