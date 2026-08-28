import AgentKeyboardCore
import Testing

@Test func catalogMapsScopeII() {
    #expect(AsusAuraCatalog.mappedProductIDs.contains(0x1AB5))
    #expect(AsusAuraCatalog.mappedProductIDs.contains(0x1AB3))
    #expect(AsusAuraCatalog.lightingMap(for: 0x1AB5) != nil)
}

@Test func omniReceiverIsIgnored() {
    #expect(AsusAuraCatalog.isIgnored(0x1ACE))
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
