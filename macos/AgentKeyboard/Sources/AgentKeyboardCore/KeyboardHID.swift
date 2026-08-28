import Foundation
import IOKit.hid

public enum HIDError: Error, Equatable {
    case notConnected
    case notFound
    case openFailed(IOReturn)
    case setReport(IOReturn)
    case layoutUnmapped(String)
}

public final class NullKeyboard: KeyboardDriver, @unchecked Sendable {
    public var isOpen = true
    public var identity = DeviceIdentity(
        vendor: .asus,
        vendorID: AK.asusVendorID,
        productID: AK.scopeIIRXProductID,
        product: "Simulator",
        layoutName: KeyboardProfile.scopeII.name,
        layoutMapped: true
    )
    public var lightingMap: LightingMap = .scopeII
    public private(set) var lastFrame: [RGB] = []
    public private(set) var frames = 0

    public init(map: LightingMap = .scopeII) {
        lightingMap = map
    }

    public func open() throws {
        isOpen = true
    }

    public func writePixels(_ pixels: [RGB]) throws {
        _ = try DirectProtocol.buildFrame(pixels: pixels, profile: lightingMap.profile)
        lastFrame = pixels
        frames += 1
    }

    public func restoreStatic(color: RGB, brightness: Int) throws {
        let k = Double(Swift.max(0, Swift.min(100, brightness))) / 100
        try writePixels(Array(repeating: color.scaled(k), count: lightingMap.ledCount))
    }

    public func close() {
        isOpen = false
    }
}

public final class KeyboardHID: KeyboardDriver, @unchecked Sendable {
    public private(set) var isOpen = false
    public private(set) var identity = AsusAuraCatalog.identity(
        productID: AK.scopeIIRXProductID,
        product: "ROG Strix Scope II RX"
    )
    public private(set) var lightingMap: LightingMap = .scopeII

    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private let queue = DispatchQueue(label: "agent-keyboard.hid")
    private var preferredProductID: UInt16?

    public init(preferredProductID: UInt16? = nil) {
        self.preferredProductID = preferredProductID
    }

    deinit { close() }

    public func open() throws {
        try queue.sync { try openLocked() }
    }

    public func writePixels(_ pixels: [RGB]) throws {
        let frame = try DirectProtocol.buildFrame(pixels: pixels, profile: lightingMap.profile)
        try queue.sync { try sendLocked(frame) }
    }

    public func close() {
        queue.sync { closeUnlocked() }
    }

    public func restoreStatic(color: RGB, brightness: Int) throws {
        var report = [UInt8](repeating: 0, count: AK.reportLength)
        report[1] = AK.cmdEffect
        report[2] = AK.effectArg
        report[3] = 0x00
        report[5] = 30
        report[6] = UInt8(clamping: Swift.max(0, Swift.min(100, brightness)))
        report[9] = AK.effectPerLedFlag
        report[10] = color.r
        report[11] = color.g
        report[12] = color.b
        try queue.sync { try sendReportLocked(report) }
    }

    public static func enumerateDevices() -> [DeviceIdentity] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let match: [String: Any] = [
            kIOHIDVendorIDKey as String: Int(AK.asusVendorID),
            kIOHIDPrimaryUsagePageKey as String: Int(AK.controlUsagePage),
            kIOHIDPrimaryUsageKey as String: Int(AK.controlUsage),
        ]
        IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
        let opened = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        defer {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        guard opened == kIOReturnSuccess else { return [] }
        return hidDevices(from: manager).compactMap { device in
            let pid = numericProperty(device, kIOHIDProductIDKey) ?? 0
            guard !AsusAuraCatalog.isIgnored(UInt16(truncatingIfNeeded: pid)) else { return nil }
            let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? ""
            return AsusAuraCatalog.identity(
                productID: UInt16(truncatingIfNeeded: pid),
                product: name
            )
        }
    }

    private func openLocked() throws {
        closeUnlocked()
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let match: [String: Any] = [
            kIOHIDVendorIDKey as String: Int(AK.asusVendorID),
            kIOHIDPrimaryUsagePageKey as String: Int(AK.controlUsagePage),
            kIOHIDPrimaryUsageKey as String: Int(AK.controlUsage),
        ]
        IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
        let opened = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard opened == kIOReturnSuccess else {
            throw HIDError.openFailed(opened)
        }
        self.manager = manager
        let devices = Self.hidDevices(from: manager)
        let candidates = devices.compactMap { device -> (IOHIDDevice, DeviceIdentity)? in
            let pid = UInt16(truncatingIfNeeded: Self.numericProperty(device, kIOHIDProductIDKey) ?? 0)
            guard !AsusAuraCatalog.isIgnored(pid) else { return nil }
            let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? ""
            return (device, AsusAuraCatalog.identity(productID: pid, product: name))
        }
        guard !candidates.isEmpty else {
            throw HIDError.notFound
        }
        let picked: (IOHIDDevice, DeviceIdentity)
        if let preferredProductID,
           let match = candidates.first(where: { $0.1.productID == preferredProductID })
        {
            picked = match
        } else if let mapped = candidates.first(where: { $0.1.layoutMapped }) {
            picked = mapped
        } else {
            throw HIDError.layoutUnmapped(candidates[0].1.product)
        }
        guard picked.1.layoutMapped, let map = AsusAuraCatalog.lightingMap(for: picked.1.productID) else {
            throw HIDError.layoutUnmapped(picked.1.product)
        }
        let kr = IOHIDDeviceOpen(picked.0, IOOptionBits(kIOHIDOptionsTypeNone))
        guard kr == kIOReturnSuccess else {
            throw HIDError.openFailed(kr)
        }
        identity = picked.1
        lightingMap = map
        device = picked.0
        isOpen = true
    }

    private func closeUnlocked() {
        if let device {
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        device = nil
        if let manager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        manager = nil
        isOpen = false
    }

    private func sendLocked(_ frame: [UInt8]) throws {
        guard device != nil else { throw HIDError.notConnected }
        for packet in DirectProtocol.packets(in: frame, profile: lightingMap.profile) {
            try sendReportLocked(Array(packet))
        }
    }

    private func sendReportLocked(_ report: [UInt8]) throws {
        guard let device else { throw HIDError.notConnected }
        let result: IOReturn = report.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress, buf.count >= 2 else {
                return kIOReturnBadArgument
            }
            return IOHIDDeviceSetReport(
                device,
                kIOHIDReportTypeOutput,
                CFIndex(buf[0]),
                base + 1,
                buf.count - 1
            )
        }
        if result != kIOReturnSuccess {
            throw HIDError.setReport(result)
        }
    }

    private static func hidDevices(from manager: IOHIDManager) -> [IOHIDDevice] {
        guard let cfDevices = IOHIDManagerCopyDevices(manager) else { return [] }
        let count = CFSetGetCount(cfDevices)
        guard count > 0 else { return [] }
        var raw = [UnsafeRawPointer?](repeating: nil, count: count)
        raw.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            CFSetGetValues(cfDevices, base)
        }
        return raw.compactMap { pointer in
            guard let pointer else { return nil }
            return Unmanaged<IOHIDDevice>.fromOpaque(pointer).takeUnretainedValue()
        }
    }

    private static func numericProperty(_ device: IOHIDDevice, _ key: String) -> Int? {
        guard let value = IOHIDDeviceGetProperty(device, key as CFString) else { return nil }
        return (value as? NSNumber)?.intValue
    }
}
