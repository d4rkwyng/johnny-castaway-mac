//
//  Johnny Castaway for macOS — synthetic-fixture tests (CI-safe).
//  GPL-3.0-or-later; see LICENSE.
//

import Testing
@testable import JohnnyEngine

/// LSB-first bit packer mirroring the LZW bit reader, for building
/// synthetic compressed streams.
private struct BitWriter {
    var bytes: [UInt8] = []
    private var bitCount = 0

    mutating func write(_ value: Int, bits: Int) {
        for i in 0..<bits {
            let byteIndex = bitCount / 8
            let bitIndex = bitCount % 8
            if byteIndex == bytes.count { bytes.append(0) }
            if value & (1 << i) != 0 {
                bytes[byteIndex] |= UInt8(1 << bitIndex)
            }
            bitCount += 1
        }
    }
}

@Suite struct RLETests {

    @Test func repeatRun() throws {
        // control 0x83 = repeat next byte 3 times
        var reader = ByteReader([0x83, 0xAB])
        let out = try Decompressor.rle(&reader, inSize: 2, outSize: 3)
        #expect(out == [0xAB, 0xAB, 0xAB])
    }

    @Test func literalRun() throws {
        // control 0x03 = copy next 3 bytes verbatim
        var reader = ByteReader([0x03, 0x01, 0x02, 0x03])
        let out = try Decompressor.rle(&reader, inSize: 4, outSize: 3)
        #expect(out == [0x01, 0x02, 0x03])
    }

    @Test func mixedRuns() throws {
        var reader = ByteReader([0x02, 0x10, 0x20, 0x84, 0xFF])
        let out = try Decompressor.rle(&reader, inSize: 5, outSize: 6)
        #expect(out == [0x10, 0x20, 0xFF, 0xFF, 0xFF, 0xFF])
    }

    @Test func wrongInSizeThrows() {
        var reader = ByteReader([0x83, 0xAB, 0x00])
        #expect(throws: (any Error).self) {
            try Decompressor.rle(&reader, inSize: 3, outSize: 3)
        }
    }
}

@Suite struct LZWTests {

    @Test func literalCodes() throws {
        // Two 9-bit literal codes: 0x41, 0x42 → "AB"
        var w = BitWriter()
        w.write(0x41, bits: 9)
        w.write(0x42, bits: 9)
        while w.bytes.count < 3 { w.bytes.append(0) }

        var reader = ByteReader(w.bytes)
        let out = try Decompressor.lzw(&reader, inSize: 3, outSize: 2)
        #expect(out == [0x41, 0x42])
    }

    @Test func backReference() throws {
        // Codes: 'A', 'B', then 257 (= "AB", the first table entry created)
        var w = BitWriter()
        w.write(0x41, bits: 9)
        w.write(0x42, bits: 9)
        w.write(257, bits: 9)
        w.write(0x43, bits: 9)
        w.write(0, bits: 4)  // pad to 5 whole bytes (40 bits)

        var reader = ByteReader(w.bytes)
        let out = try Decompressor.lzw(&reader, inSize: w.bytes.count, outSize: 5)
        #expect(out == [0x41, 0x42, 0x41, 0x42, 0x43])
    }

    /// Self-referencing entry without a reset: code 258 is first used via
    /// the KwKwK path before it exists, so entry 258 is later created with
    /// prefix 258. Decoding 258 again then chains forever. Before the bound
    /// this overran the 4097-byte decode stack and trapped.
    @Test func selfReferencingEntryThrows() {
        var w = BitWriter()
        for code in [65, 258, 257, 258] { w.write(code, bits: 9) }
        w.bytes += [0, 0]

        var reader = ByteReader(w.bytes)
        #expect(throws: EngineError.self) {
            try Decompressor.lzw(&reader, inSize: w.bytes.count, outSize: 100_000)
        }
    }

    /// Reset-then-loop: after code 256 resets the table, entry 257 still
    /// holds stale data from before the reset. Rebuilding the table lets
    /// entry 257 be re-created with itself as prefix, and the next 257
    /// cycles. Before the bound this trapped on the decode stack.
    @Test func resetThenCyclicChainThrows() {
        var w = BitWriter()
        w.write(65, bits: 9)
        w.write(66, bits: 9)
        w.write(256, bits: 9)
        // Decoder realigns after a reset: bitpos is 18 here, so it skips
        // (72 - (17 % 72)) - 1 = 54 bits.
        w.write(0, bits: 54)
        for code in [257, 258, 257] { w.write(code, bits: 9) }
        w.bytes += [0, 0]

        var reader = ByteReader(w.bytes)
        #expect(throws: EngineError.self) {
            try Decompressor.lzw(&reader, inSize: w.bytes.count, outSize: 100_000)
        }
    }

    /// The longest legitimate chain (every code a KwKwK extension of the
    /// previous one, filling the table up to 4095 across all bit widths)
    /// must still decode: the bound must not reject valid data.
    @Test func longestValidChainDecodes() throws {
        var w = BitWriter()
        var nBits = 9
        var freeEntry = 257
        w.write(65, bits: nBits)
        var expected = 1
        for code in 257...4095 {
            w.write(code, bits: nBits)
            expected += code - 255
            if freeEntry < 4096 {
                freeEntry += 1
                if freeEntry >= (1 << nBits) && nBits < 12 { nBits += 1 }
            }
        }
        w.bytes += [0, 0]

        var reader = ByteReader(w.bytes)
        let out = try Decompressor.lzw(&reader, inSize: w.bytes.count, outSize: expected)
        #expect(out.count == expected)
        #expect(out.allSatisfy { $0 == 65 })
    }

    @Test func zeroOutputThrows() {
        var reader = ByteReader([0x00])
        #expect(throws: (any Error).self) {
            try Decompressor.lzw(&reader, inSize: 1, outSize: 0)
        }
    }
}

@Suite struct ByteReaderTests {

    @Test func littleEndianReads() throws {
        var r = ByteReader([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])
        #expect(try r.u8() == 0x01)
        #expect(try r.u16() == 0x0302)
        #expect(try r.u32() == 0x0706_0504)
    }

    @Test func cStringStopsAtNul() throws {
        var r = ByteReader(Array("ABC".utf8) + [0, 0xFF])
        #expect(try r.cString(max: 13) == "ABC")
        #expect(r.offset == 4)  // NUL consumed, 0xFF not
    }

    @Test func fixedString() throws {
        var r = ByteReader(Array("HI".utf8) + [0, 0, 0] + [0x77])
        #expect(try r.fixedString(5) == "HI")
        #expect(r.offset == 5)
    }

    @Test func expectTag() throws {
        var r = ByteReader(Array("BMP:".utf8))
        try r.expectTag("BMP:", context: "test")
        var bad = ByteReader(Array("XXX:".utf8))
        #expect(throws: (any Error).self) {
            try bad.expectTag("BMP:", context: "test")
        }
    }

    @Test func truncationThrows() {
        var r = ByteReader([0x01])
        #expect(throws: (any Error).self) { try r.u32() }
    }
}

@Suite struct MapParserTests {

    @Test func parseSyntheticMap() throws {
        var bytes: [UInt8] = [0, 1, 5, 7, 1, 0]            // 6 unknown header bytes
        bytes += Array("RESOURCE.001".utf8) + [0]           // NUL-terminated data file name
        bytes += [2, 0]                                     // numEntries = 2
        bytes += [0x10, 0, 0, 0, 0x00, 0x01, 0, 0]          // length=16, offset=256
        bytes += [0x20, 0, 0, 0, 0x00, 0x02, 0, 0]          // length=32, offset=512

        let map = try ResourceLibrary.parseMap(bytes)
        #expect(map.dataFileName == "RESOURCE.001")
        #expect(map.entries.count == 2)
        #expect(map.entries[0].offset == 256)
        #expect(map.entries[1].length == 32)
    }
}
