//
//  Johnny Castaway for macOS
//
//  Engine logic ported from 'Johnny Reborn' (jc_reborn),
//  Copyright (C) 2019 Jeremie GUILLAUME — GPL-3.0-or-later.
//  Swift port Copyright (C) 2026 the johnny-castaway-mac contributors.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//

import Foundation

/// Little-endian cursor over a byte buffer. Replaces jc_reborn's
/// FILE*-based readUint8/readUint16/readUint32/getString helpers (utils.c).
public struct ByteReader {
    public let bytes: [UInt8]
    public private(set) var offset: Int

    public init(_ bytes: [UInt8], at offset: Int = 0) {
        self.bytes = bytes
        self.offset = offset
    }

    public var remaining: Int { bytes.count - offset }

    public mutating func seek(to newOffset: Int) {
        offset = newOffset
    }

    private mutating func require(_ n: Int) throws {
        guard remaining >= n else {
            throw EngineError.truncatedData(expected: n, available: remaining)
        }
    }

    public mutating func u8() throws -> UInt8 {
        try require(1)
        defer { offset += 1 }
        return bytes[offset]
    }

    public mutating func u16() throws -> UInt16 {
        try require(2)
        defer { offset += 2 }
        return UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }

    public mutating func u32() throws -> UInt32 {
        try require(4)
        defer { offset += 4 }
        return UInt32(bytes[offset])
            | (UInt32(bytes[offset + 1]) << 8)
            | (UInt32(bytes[offset + 2]) << 16)
            | (UInt32(bytes[offset + 3]) << 24)
    }

    public mutating func block(_ n: Int) throws -> [UInt8] {
        try require(n)
        defer { offset += n }
        return Array(bytes[offset..<(offset + n)])
    }

    public mutating func u16Block(_ n: Int) throws -> [UInt16] {
        var out = [UInt16]()
        out.reserveCapacity(n)
        for _ in 0..<n {
            out.append(try u16())
        }
        return out
    }

    /// Reads a NUL-terminated string, consuming at most `max` bytes
    /// (the terminating NUL is consumed). Mirrors utils.c getString().
    public mutating func cString(max: Int) throws -> String {
        var chars = [UInt8]()
        var numRead = 0
        while numRead < max {
            let b = try u8()
            numRead += 1
            if b == 0 { break }
            chars.append(b)
        }
        return String(decoding: chars, as: UTF8.self)
    }

    /// Reads a fixed-size field containing a NUL-terminated string
    /// (e.g. the 13-byte resource names in RESOURCE.001).
    public mutating func fixedString(_ n: Int) throws -> String {
        let raw = try block(n)
        let end = raw.firstIndex(of: 0) ?? raw.count
        return String(decoding: raw[..<end], as: UTF8.self)
    }

    /// Consumes a 4-byte magic tag ("VER:", "BMP:", ...) and validates it.
    public mutating func expectTag(_ tag: String, context: String) throws {
        let raw = try block(4)
        guard raw.elementsEqual(tag.utf8) else {
            throw EngineError.badMagic(expected: tag, context: context)
        }
    }
}
