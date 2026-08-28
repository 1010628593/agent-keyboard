import AgentKeyboardCore
import Testing

@Test func buildFrameHasEightPacketsWithCorrectHeaders() throws {
    let dest = try DirectProtocol.buildFrame(pixels: Array(repeating: .black, count: AK.ledCount))
    #expect(dest.count == AK.frameBufferSize)
    for p in 0..<AK.packetsPerFrame {
        let b = p * AK.reportLength
        #expect(dest[b] == 0x00)
        #expect(dest[b + 1] == AK.directHeaderHi)
        #expect(dest[b + 2] == AK.directHeaderLo)
        #expect(dest[b + 3] == (p < 7 ? 15 : 2))
        #expect(dest[b + 4] == 0x00)
    }
}

@Test func buildFrameWritesKeyIdAndColorInRenderOrder() throws {
    let pixels = (0..<AK.ledCount).map { i in RGB(UInt8(i), UInt8(i + 1), UInt8(i + 2)) }
    let dest = try DirectProtocol.buildFrame(pixels: pixels)
    for i in 0..<AK.ledCount {
        let p = i / AK.ledsPerPacket
        let j = i % AK.ledsPerPacket
        let b = p * AK.reportLength + j * 4 + 5
        #expect(dest[b] == KeyboardProfile.scopeII.keys[i].keyId)
        #expect(dest[b + 1] == UInt8(i))
        #expect(dest[b + 2] == UInt8(i + 1))
        #expect(dest[b + 3] == UInt8(i + 2))
    }
}

@Test func lastPacketTailIsZeroPadded() throws {
    let dest = try DirectProtocol.buildFrame(pixels: Array(repeating: .white, count: AK.ledCount))
    let base = 7 * AK.reportLength
    for k in 13..<AK.reportLength {
        #expect(dest[base + k] == 0)
    }
}

@Test func buildFrameRejectsWrongPixelCount() {
    #expect(throws: ProtocolError.pixelCount(expected: AK.ledCount, got: 10)) {
        _ = try DirectProtocol.buildFrame(pixels: Array(repeating: .black, count: 10))
    }
}
