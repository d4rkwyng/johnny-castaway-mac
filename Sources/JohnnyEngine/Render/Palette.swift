//
//  Johnny Castaway for macOS
//
//  Engine logic ported from 'Johnny Reborn' (jc_reborn) graphics.c,
//  Copyright (C) 2019 Jeremie GUILLAUME — GPL-3.0-or-later.
//  Swift port Copyright (C) 2026 the johnny-castaway-mac contributors.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//

import Foundation

/// A pixel packed as RGBA in memory order (byte 0 = R … byte 3 = A),
/// i.e. little-endian UInt32 value r | g<<8 | b<<16 | a<<24.
public typealias Pixel = UInt32

@inlinable
public func makePixel(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) -> Pixel {
    UInt32(r) | (UInt32(g) << 8) | (UInt32(b) << 16) | (UInt32(a) << 24)
}

/// The magenta color key marking transparent pixels on every layer
/// (0xA8, 0x00, 0xA8 — palette-independent, hardcoded in the original).
public let colorKeyPixel: Pixel = makePixel(r: 0xA8, g: 0, b: 0xA8)

/// The 16-color TTM palette. VGA 6-bit channels are expanded with << 2,
/// matching the reference engine (not a full 0-255 rescale).
public struct Palette: Sendable {
    public let colors: [Pixel]  // 16 entries

    public init(_ resource: PalResource) {
        var colors = [Pixel]()
        colors.reserveCapacity(16)
        for i in 0..<16 {
            let c = resource.colors[i]
            colors.append(makePixel(r: c.r << 2, g: c.g << 2, b: c.b << 2))
        }
        self.colors = colors
    }

    @inlinable
    public subscript(_ index: UInt8) -> Pixel {
        colors[Int(index & 0x0F)]
    }
}
