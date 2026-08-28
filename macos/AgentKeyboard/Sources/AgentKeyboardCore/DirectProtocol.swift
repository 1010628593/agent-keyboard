public enum DirectProtocol {
    public static func buildFrame(
        pixels: [RGB],
        profile: KeyboardProfile = .scopeII
    ) throws -> [UInt8] {
        guard pixels.count == profile.ledCount else {
            throw ProtocolError.pixelCount(expected: profile.ledCount, got: pixels.count)
        }
        var dest = [UInt8](repeating: 0, count: profile.frameBufferSize)
        let keys = profile.keys
        for packetIndex in 0..<profile.packetsPerFrame {
            let offset = packetIndex * AK.ledsPerPacket
            let count = min(AK.ledsPerPacket, keys.count - offset)
            if count <= 0 { break }
            let base = packetIndex * AK.reportLength
            dest[base + 1] = AK.directHeaderHi
            dest[base + 2] = AK.directHeaderLo
            dest[base + 3] = UInt8(count)
            dest[base + 4] = 0
            for j in 0..<count {
                let color = pixels[offset + j]
                let b = base + j * 4 + 5
                dest[b] = keys[offset + j].keyId
                dest[b + 1] = color.r
                dest[b + 2] = color.g
                dest[b + 3] = color.b
            }
        }
        return dest
    }

    public static func packets(in frame: [UInt8], profile: KeyboardProfile = .scopeII) -> [ArraySlice<UInt8>] {
        (0..<profile.packetsPerFrame).map { p in
            let start = p * AK.reportLength
            return frame[start..<(start + AK.reportLength)]
        }
    }
}

public enum ProtocolError: Error, Equatable {
    case pixelCount(expected: Int, got: Int)
}
