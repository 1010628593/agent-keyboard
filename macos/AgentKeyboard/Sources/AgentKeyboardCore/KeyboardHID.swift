import Foundation
import IOKit.hid
import CoreFoundation

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

    public static func matchingDictionaries() -> [[String: Any]] {
        [
            [
                kIOHIDVendorIDKey as String: Int(AK.asusVendorID),
                kIOHIDPrimaryUsagePageKey as String: Int(AK.controlUsagePage),
                kIOHIDPrimaryUsageKey as String: Int(AK.controlUsage),
            ],
            [
                kIOHIDVendorIDKey as String: Int(AK.asusVendorID),
                kIOHIDPrimaryUsagePageKey as String: Int(AK.genericDesktopUsagePage),
                kIOHIDPrimaryUsageKey as String: Int(AK.keyboardUsage),
            ],
        ]
    }

    public static func matchingCFArray() -> CFArray {
        matchingDictionaries().map { $0 as CFDictionary } as CFArray
    }

    public static func enumerateDevices() -> [DeviceIdentity] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatchingMultiple(manager, matchingCFArray())
        let opened = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        defer {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        guard opened == kIOReturnSuccess else { return [] }
        return deduplicatedIdentities(from: hidDevices(from: manager))
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
        let candidates = Self.hidDevices(from: manager).compactMap { device -> (IOHIDDevice, DeviceIdentity)? in
            guard let identity = Self.identity(from: device), identity.hasAuraControl else { return nil }
            return (device, identity)
        }
        guard !candidates.isEmpty else {
            throw HIDError.notFound
        }
        let picked: (IOHIDDevice, DeviceIdentity)
        if let preferredProductID,
           let match = candidates.first(where: { $0.1.productID == preferredProductID && $0.1.layoutMapped })
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

    private static func identity(from device: IOHIDDevice) -> DeviceIdentity? {
        let pid = UInt16(truncatingIfNeeded: numericProperty(device, kIOHIDProductIDKey) ?? 0)
        let usagePage = UInt32(truncatingIfNeeded: numericProperty(device, kIOHIDPrimaryUsagePageKey) ?? 0)
        let usage = UInt32(truncatingIfNeeded: numericProperty(device, kIOHIDPrimaryUsageKey) ?? 0)
        let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? ""
        let transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String
        guard AsusAuraCatalog.shouldEnumerate(
            productID: pid,
            product: name,
            usagePage: usagePage,
            usage: usage
        ) else {
            return nil
        }
        return AsusAuraCatalog.identity(
            productID: pid,
            product: name,
            transport: transport,
            usagePage: usagePage,
            usage: usage
        )
    }

    private static func deduplicatedIdentities(from devices: [IOHIDDevice]) -> [DeviceIdentity] {
        var best: [String: DeviceIdentity] = [:]
        for device in devices {
            guard let identity = identity(from: device) else { continue }
            if let existing = best[identity.dedupeKey] {
                if identity.hasAuraControl, !existing.hasAuraControl {
                    best[identity.dedupeKey] = identity
                }
            } else {
                best[identity.dedupeKey] = identity
            }
        }
        return best.values.sorted {
            if $0.lightingCapable != $1.lightingCapable { return $0.lightingCapable && !$1.lightingCapable }
            if $0.productID != $1.productID { return $0.productID < $1.productID }
            return $0.product < $1.product
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

public final class HIDDeviceMonitor: @unchecked Sendable {
    private var manager: IOHIDManager?
    private var onChange: (@Sendable () -> Void)?

    public init() {}

    deinit { stop() }

    public func start(onChange: @escaping @Sendable () -> Void) {
        stop()
        self.onChange = onChange
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatchingMultiple(manager, KeyboardHID.matchingCFArray())
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, _ in
            HIDDeviceMonitor.emit(context)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, _ in
            HIDDeviceMonitor.emit(context)
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        let opened = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard opened == kIOReturnSuccess else {
            self.onChange = nil
            return
        }
        self.manager = manager
        Self.emit(context)
    }

    public func stop() {
        guard let manager else {
            onChange = nil
            return
        }
        IOHIDManagerRegisterDeviceMatchingCallback(manager, nil, nil)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, nil, nil)
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = nil
        onChange = nil
    }

    private static func emit(_ context: UnsafeMutableRawPointer?) {
        guard let context else { return }
        Unmanaged<HIDDeviceMonitor>.fromOpaque(context).takeUnretainedValue().onChange?()
    }
}
