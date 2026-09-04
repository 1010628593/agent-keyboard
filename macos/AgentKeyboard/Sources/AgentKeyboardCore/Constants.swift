import Foundation

public enum AK {
    public static let asusVendorID: UInt16 = 0x0B05
    public static let scopeIIRXProductID: UInt16 = 0x1AB5
    public static let scopeIINXProductID: UInt16 = 0x1AB3
    public static let omniReceiverProductID: UInt16 = 0x1ACE
    public static let peltaProductID: UInt16 = 0x1B84
    public static let supportedProductIDs: Set<UInt16> = [scopeIIRXProductID, scopeIINXProductID]

    public static let controlUsagePage: UInt32 = 0xFF00
    public static let controlUsage: UInt32 = 0x0001
    public static let genericDesktopUsagePage: UInt32 = 0x01
    public static let keyboardUsage: UInt32 = 0x06
    public static let controlInterface = 1

    public static let ledCount = 107
    public static let matrixRows = 6
    public static let matrixCols = 24

    public static let reportLength = 65
    public static let ledsPerPacket = 15
    public static let packetsPerFrame = 8
    public static let frameBufferSize = packetsPerFrame * reportLength

    public static let directHeaderHi: UInt8 = 0xC0
    public static let directHeaderLo: UInt8 = 0x81

    public static let cmdQuery: UInt8 = 0x12
    public static let queryVersion: UInt8 = 0x00
    public static let queryLayout: UInt8 = 0x12
    public static let cmdEffect: UInt8 = 0x51
    public static let effectArg: UInt8 = 0x2C
    public static let effectPerLedFlag: UInt8 = 0x02
    public static let cmdSave: UInt8 = 0x50
    public static let saveArg: UInt8 = 0x55

    public static let defaultFPS = 32
    public static let doneHoldSeconds = 2.0
    public static let glyphHoldSeconds = 1.6
    public static let defaultIdleWhite = 0.05
    public static let defaultBridgePort: UInt16 = 7420
    public static let mcpOverlayMaxSeconds: TimeInterval = 15
    public static let mcpEndpoint = "http://127.0.0.1:7420/mcp"
    public static let defaultIdleTimeout: TimeInterval = 120
    public static let eventLogLimit = 200
    public static let appVersion = "1.4.6"
    public static let tokenBudget = 20_000
    public static let defaultBrightness = 0.80
}
