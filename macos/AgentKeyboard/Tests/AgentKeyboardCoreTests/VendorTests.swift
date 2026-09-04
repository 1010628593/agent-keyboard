import AgentKeyboardCore
import Testing

@Test func catalogMapsScopeII() {
    #expect(AsusAuraCatalog.mappedProductIDs.contains(0x1AB5))
    #expect(AsusAuraCatalog.mappedProductIDs.contains(0x1AB3))
    #expect(AsusAuraCatalog.lightingMap(for: 0x1AB5) != nil)
}

@Test func peltaIsIgnoredOmniIsNot() {
    #expect(!AsusAuraCatalog.isIgnored(0x1ACE))
    #expect(AsusAuraCatalog.isIgnored(0x1B84))
}

@Test func unmappedTUFHasNoLayout() {
    let tuf = AsusAuraCatalog.known(for: 0x18AA)
    #expect(tuf != nil)
    #expect(tuf?.layoutMapped == false)
}

@Test func lightingMapHasSixAgentKeys() {
    #expect(LightingMap.scopeII.agentKeys == ["F1", "F2", "F3", "F4", "F5", "F6"])
    #expect(LightingMap.scopeII.escape == "ESCAPE")
    #expect(LightingMap.scopeII.enter == "ANSI_ENTER")
    #expect(LightingMap.scopeII.names(for: LightingTarget.fRow).count == 12)
    #expect(LightingMap.scopeII.names(for: LightingTarget.wheel).isEmpty)
}

@Test func otherVendorsArePlaceholders() {
    #expect(KeyboardVendor.asus.implemented)
    #expect(!KeyboardVendor.unknown.implemented)
}

@Test func connectionKindClassifiesTransports() {
    #expect(AsusAuraCatalog.connectionKind(productID: 0x1AB5, product: "ROG", transport: "USB") == .usb)
    #expect(AsusAuraCatalog.connectionKind(productID: 0x1A85, product: "Azoth", transport: "USB") == .rf24)
    #expect(AsusAuraCatalog.connectionKind(productID: 0x193E, product: "Falchion", transport: nil) == .rf24)
    #expect(AsusAuraCatalog.connectionKind(productID: 0x19F8, product: "Scope NX", transport: "USB") == .rf24)
    #expect(AsusAuraCatalog.connectionKind(productID: 0x1AB5, product: "ROG", transport: "Bluetooth") == .bluetooth)
    #expect(AsusAuraCatalog.connectionKind(productID: 0x1AB5, product: "ROG", transport: "BluetoothLowEnergy") == .bluetooth)
    #expect(AsusAuraCatalog.connectionKind(productID: 0x1ACE, product: "ROG OMNI RECEIVER", transport: "USB") == .rf24)
}

@Test func omniEnumeratesOnlyKeyboardCollections() {
    #expect(
        AsusAuraCatalog.shouldEnumerate(
            productID: 0x1ACE,
            product: "ROG OMNI RECEIVER",
            usagePage: 0x01,
            usage: 0x06
        )
    )
    #expect(
        !AsusAuraCatalog.shouldEnumerate(
            productID: 0x1ACE,
            product: "ROG OMNI RECEIVER",
            usagePage: 0x01,
            usage: 0x02
        )
    )
    #expect(
        AsusAuraCatalog.shouldEnumerate(
            productID: 0x1ACE,
            product: "ROG OMNI RECEIVER",
            usagePage: 0xFF00,
            usage: 0x0001
        )
    )
    #expect(
        !AsusAuraCatalog.shouldEnumerate(
            productID: 0x1B84,
            product: "ROG Pelta",
            usagePage: 0x01,
            usage: 0x06
        )
    )
    #expect(
        AsusAuraCatalog.shouldEnumerate(
            productID: 0x1AB5,
            product: "ROG Strix Scope II RX",
            usagePage: 0x01,
            usage: 0x06
        )
    )
}

@Test func identityCapturesAuraAndTransport() {
    let wired = AsusAuraCatalog.identity(
        productID: 0x1AB5,
        product: "ROG Strix Scope II RX",
        transport: "USB"
    )
    #expect(wired.connection == .usb)
    #expect(wired.hasAuraControl)
    #expect(wired.lightingCapable)

    let bluetooth = AsusAuraCatalog.identity(
        productID: 0x1AB5,
        product: "ROG Strix Scope II RX",
        transport: "Bluetooth",
        usagePage: 0x01,
        usage: 0x06
    )
    #expect(bluetooth.connection == .bluetooth)
    #expect(!bluetooth.hasAuraControl)
    #expect(!bluetooth.lightingCapable)
}
