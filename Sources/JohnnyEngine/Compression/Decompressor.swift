//
//  Johnny Castaway for macOS
//
//  Engine logic ported from 'Johnny Reborn' (jc_reborn) uncompress.c,
//  Copyright (C) 2019 Jeremie GUILLAUME — GPL-3.0-or-later.
//  Swift port Copyright (C) 2026 the johnny-castaway-mac contributors.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//

import Foundation

/// RLE (method 1) and LZW (method 2) decompression for the Dynamix
/// resource container. Faithful port of uncompress.c.
public enum Decompressor {

    public static func decompress(
        method: UInt8,
        reader: inout ByteReader,
        inSize: Int,
        outSize: Int
    ) throws -> [UInt8] {
        switch method {
        case 1:
            return try rle(&reader, inSize: inSize, outSize: outSize)
        case 2:
            return try lzw(&reader, inSize: inSize, outSize: outSize)
        default:
            throw EngineError.badData("unknown compression method \(method)")
        }
    }

    // MARK: - RLE

    static func rle(_ reader: inout ByteReader, inSize: Int, outSize: Int) throws -> [UInt8] {
        var out = [UInt8]()
        out.reserveCapacity(outSize)
        var inOffset = 0

        while out.count < outSize {
            let control = try reader.u8()
            inOffset += 1

            if control & 0x80 == 0x80 {
                let length = Int(control & 0x7F)
                let b = try reader.u8()
                inOffset += 1
                for _ in 0..<length where out.count < outSize {
                    out.append(b)
                }
            } else {
                for _ in 0..<Int(control) {
                    let b = try reader.u8()
                    inOffset += 1
                    if out.count < outSize { out.append(b) }
                }
            }
        }

        guard inOffset == inSize else {
            throw EngineError.badData("error while uncompressing RLE")
        }
        return out
    }

    // MARK: - LZW

    /// 9-to-12-bit LZW with a 4096-entry code table; code 256 resets the
    /// table and realigns the bit position. Bit/byte consumption mirrors
    /// the original exactly (the bit reader refills eagerly after every
    /// 8th bit, which matters for the final inSize accounting).
    static func lzw(_ reader: inout ByteReader, inSize: Int, outSize: Int) throws -> [UInt8] {
        guard outSize > 0 else {
            throw EngineError.badData("can't uncompress LZW to 0 bytes")
        }

        var inOffset = 0
        var nextbit = 0
        var current: UInt8 = 0

        func getByte() throws -> UInt8 {
            if inOffset >= inSize { return 0 }
            inOffset += 1
            return try reader.u8()
        }

        func getBits(_ n: Int) throws -> UInt16 {
            if n == 0 { return 0 }
            var x: UInt32 = 0
            for i in 0..<n {
                if current & (1 << nextbit) != 0 {
                    x |= 1 << UInt32(i)
                }
                nextbit += 1
                if nextbit > 7 {
                    current = try getByte()
                    nextbit = 0
                }
            }
            return UInt16(truncatingIfNeeded: x)
        }

        var prefix = [UInt16](repeating: 0, count: 4096)
        var append = [UInt8](repeating: 0, count: 4096)
        var decodeStack = [UInt8](repeating: 0, count: 4097)
        var stackPtr = 0
        var nBits = 9
        var freeEntry = 257
        var bitpos = 0

        var out = [UInt8]()
        out.reserveCapacity(outSize)

        current = try getByte()
        var oldcode = try getBits(nBits)
        var lastbyte = oldcode
        out.append(UInt8(truncatingIfNeeded: oldcode))

        while inOffset < inSize {
            let newcode = try getBits(nBits)
            bitpos += nBits

            if newcode == 256 {
                let nbits3 = nBits << 3
                let nskip = (nbits3 - ((bitpos - 1) % nbits3)) - 1
                _ = try getBits(nskip)
                nBits = 9
                freeEntry = 256
                bitpos = 0
            } else {
                var code = Int(newcode)

                if code >= freeEntry {
                    if stackPtr > 4095 { break }
                    decodeStack[stackPtr] = UInt8(truncatingIfNeeded: lastbyte)
                    stackPtr += 1
                    code = Int(oldcode)
                }

                while code > 255 {
                    if code > 4095 { break }
                    decodeStack[stackPtr] = append[code]
                    stackPtr += 1
                    code = Int(prefix[code])
                }

                decodeStack[stackPtr] = UInt8(truncatingIfNeeded: code)
                stackPtr += 1
                lastbyte = UInt16(code)

                while stackPtr > 0 {
                    stackPtr -= 1
                    if out.count >= outSize {
                        return out
                    }
                    out.append(decodeStack[stackPtr])
                }

                if freeEntry < 4096 {
                    prefix[freeEntry] = oldcode
                    append[freeEntry] = UInt8(truncatingIfNeeded: lastbyte)
                    freeEntry += 1
                    if freeEntry >= (1 << nBits) && nBits < 12 {
                        nBits += 1
                        bitpos = 0
                    }
                }

                oldcode = newcode
            }
        }

        guard inOffset == inSize else {
            throw EngineError.badData("error while uncompressing LZW")
        }
        return out
    }
}
