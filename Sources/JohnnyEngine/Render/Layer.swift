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

public struct ClipRect: Sendable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public static let full = ClipRect(x: 0, y: 0, width: Layer.width, height: Layer.height)
}

/// A decoded sprite: 4bpp source expanded to RGBA pixels.
/// Color-key pixels stay as `colorKeyPixel` and are skipped when blitting.
public struct Sprite: Sendable {
    public let width: Int
    public let height: Int
    public let pixels: [Pixel]
}

/// A 640×480 software surface — the Swift equivalent of jc_reborn's
/// per-thread SDL_Surface layers. Blit/fill respect `clip` (like
/// SDL_FillRect/SDL_BlitSurface); pixel/line/circle primitives bypass it
/// (like the original's direct pixel writes under SDL_LockSurface).
public final class Layer {
    public static let width = 640
    public static let height = 480

    public var pixels: [Pixel]
    public var clip: ClipRect = .full

    /// New layer filled with the transparent color key.
    public init() {
        pixels = [Pixel](repeating: colorKeyPixel, count: Layer.width * Layer.height)
    }

    /// New layer with opaque content (used for the background screen).
    public init(filledWith pixel: Pixel) {
        pixels = [Pixel](repeating: pixel, count: Layer.width * Layer.height)
    }

    // MARK: - Primitives (bypass clip, bounds-checked — port of grPutPixel & co)

    @inlinable
    public func putPixel(_ x: Int, _ y: Int, _ pixel: Pixel) {
        if x >= 0 && y >= 0 && x < Layer.width && y < Layer.height {
            pixels[y * Layer.width + x] = pixel
        }
    }

    public func drawHorizontalLine(x1: Int, x2: Int, y: Int, pixel: Pixel) {
        if y < 0 || y > Layer.height - 1 { return }
        let xa = max(x1, 0)
        let xb = min(x2, Layer.width - 1)
        if xa > xb { return }
        for x in xa...xb {
            pixels[y * Layer.width + x] = pixel
        }
    }

    /// Pixel-perfect port of jc_reborn's Bresenham (which itself matches
    /// the original renderer). Note: draws dx (or dy) pixels — the end
    /// point is intentionally not drawn.
    public func drawLine(x1: Int, y1: Int, x2: Int, y2: Int, pixel: Pixel) {
        var x = x1
        var y = y1
        let dx = abs(x2 - x1)
        let dy = abs(y2 - y1)
        let xinc = x2 > x1 ? 1 : -1
        let yinc = y2 > y1 ? 1 : -1

        if dy < dx {
            var cumul = (dx + 1) >> 1
            for _ in 0..<dx {
                putPixel(x, y, pixel)
                x += xinc
                cumul += dy
                if cumul > dx {
                    cumul -= dx
                    y += yinc
                }
            }
        } else {
            var cumul = (dy + 1) >> 1
            for _ in 0..<dy {
                putPixel(x, y, pixel)
                y += yinc
                cumul += dx
                if cumul > dy {
                    cumul -= dy
                    x += xinc
                }
            }
        }
    }

    /// Filled circle with outline, exact port of grDrawCircle. Only even
    /// diameters with width == height exist in the original data.
    public func drawCircle(
        x1: Int, y1: Int, width: Int, height: Int, fg: Pixel, bg: Pixel
    ) {
        guard width == height, width % 2 == 0 else { return }

        let r = (width >> 1) - 1
        let xc = x1 + r
        let yc = y1 + r

        var x = 0
        var y = r
        var d = 1 - r

        while true {
            drawHorizontalLine(x1: xc - x, x2: xc + x + 1, y: yc + y + 1, pixel: bg)
            drawHorizontalLine(x1: xc - x, x2: xc + x + 1, y: yc - y, pixel: bg)
            drawHorizontalLine(x1: xc - y, x2: xc + y + 1, y: yc + x + 1, pixel: bg)
            drawHorizontalLine(x1: xc - y, x2: xc + y + 1, y: yc - x, pixel: bg)

            if y - x <= 1 { break }
            if d < 0 {
                d += (x << 1) + 3
            } else {
                d += ((x - y) << 1) + 5
                y -= 1
            }
            x += 1
        }

        if fg != bg {
            x = 0
            y = r
            d = 1 - r

            while true {
                putPixel(xc - x, yc + y + 1, fg)
                putPixel(xc + x + 1, yc + y + 1, fg)
                putPixel(xc - x, yc - y, fg)
                putPixel(xc + x + 1, yc - y, fg)
                putPixel(xc - y, yc + x + 1, fg)
                putPixel(xc + y + 1, yc + x + 1, fg)
                putPixel(xc - y, yc - x, fg)
                putPixel(xc + y + 1, yc - x, fg)

                if y - x <= 1 { break }
                if d < 0 {
                    d += (x << 1) + 3
                } else {
                    d += ((x - y) << 1) + 5
                    y -= 1
                }
                x += 1
            }
        }
    }

    // MARK: - Clipped operations (port of SDL_FillRect / SDL_BlitSurface)

    /// Filled rectangle, clipped to `clip` (SDL_FillRect semantics).
    public func fillRect(x: Int, y: Int, width: Int, height: Int, pixel: Pixel) {
        let xa = max(x, clip.x, 0)
        let ya = max(y, clip.y, 0)
        let xb = min(x + width, clip.x + clip.width, Layer.width)
        let yb = min(y + height, clip.y + clip.height, Layer.height)
        guard xa < xb, ya < yb else { return }
        for row in ya..<yb {
            for col in xa..<xb {
                pixels[row * Layer.width + col] = pixel
            }
        }
    }

    /// Fills the whole layer with the color key, ignoring clip
    /// (port of grClearScreen).
    public func clearToColorKey() {
        for i in 0..<pixels.count {
            pixels[i] = colorKeyPixel
        }
    }

    /// Blits a sprite, skipping color-key pixels, clipped to `clip`
    /// (SDL_BlitSurface with SDL_SetColorKey semantics).
    public func blit(_ sprite: Sprite, x: Int, y: Int, flipped: Bool = false) {
        let xa = max(x, clip.x, 0)
        let ya = max(y, clip.y, 0)
        let xb = min(x + sprite.width, clip.x + clip.width, Layer.width)
        let yb = min(y + sprite.height, clip.y + clip.height, Layer.height)
        guard xa < xb, ya < yb else { return }

        for row in ya..<yb {
            let srcRow = row - y
            for col in xa..<xb {
                // When flipped, dest column x+i shows source column w-1-i.
                let srcCol = flipped ? (sprite.width - 1 - (col - x)) : (col - x)
                let p = sprite.pixels[srcRow * sprite.width + srcCol]
                if p != colorKeyPixel {
                    pixels[row * Layer.width + col] = p
                }
            }
        }
    }

    /// Blits a rectangular zone of another layer onto self at the same
    /// position, skipping color-key pixels, clipped to `clip`
    /// (port of grCopyZoneToBg's SDL_BlitSurface call).
    public func blitZone(from source: Layer, x: Int, y: Int, width: Int, height: Int) {
        let xa = max(x, clip.x, 0)
        let ya = max(y, clip.y, 0)
        let xb = min(x + width, clip.x + clip.width, Layer.width)
        let yb = min(y + height, clip.y + clip.height, Layer.height)
        guard xa < xb, ya < yb else { return }

        for row in ya..<yb {
            for col in xa..<xb {
                let p = source.pixels[row * Layer.width + col]
                if p != colorKeyPixel {
                    pixels[row * Layer.width + col] = p
                }
            }
        }
    }

    /// Composites another full layer over self, skipping color-key pixels
    /// (used by the final frame compositor; ignores clip like the
    /// original's whole-surface blits onto the window).
    public func composite(_ layer: Layer) {
        for i in 0..<pixels.count {
            let p = layer.pixels[i]
            if p != colorKeyPixel {
                pixels[i] = p
            }
        }
    }
}

// MARK: - 4bpp decoding (port of grLoadScreen / grLoadBmp)

public enum PixelDecoder {

    /// Expands 4bpp data (high nibble first) through the palette.
    public static func decode4bpp(
        _ data: [UInt8], width: Int, height: Int, palette: Palette
    ) -> [Pixel] {
        var out = [Pixel]()
        out.reserveCapacity(width * height)
        for i in 0..<(width * height / 2) {
            let byte = data[i]
            out.append(palette[(byte & 0xF0) >> 4])
            out.append(palette[byte & 0x0F])
        }
        return out
    }

    /// Decodes a full-screen background into an opaque layer. Images
    /// shorter than 480 rows (the 640×350 backgrounds) leave the rest
    /// of the layer black, like the original surface blit.
    public static func decodeScreen(_ scr: ScrResource, palette: Palette) -> Layer {
        let layer = Layer(filledWith: makePixel(r: 0, g: 0, b: 0))
        let width = Int(scr.width)
        let height = Int(scr.height)
        let decoded = decode4bpp(scr.data, width: width, height: height, palette: palette)
        for row in 0..<min(height, Layer.height) {
            for col in 0..<min(width, Layer.width) {
                layer.pixels[row * Layer.width + col] = decoded[row * width + col]
            }
        }
        return layer
    }

    /// Decodes every image of a BMP sprite sheet (consecutive 4bpp blocks).
    public static func decodeSprites(_ bmp: BmpResource, palette: Palette) -> [Sprite] {
        var sprites = [Sprite]()
        sprites.reserveCapacity(bmp.numImages)
        var offset = 0
        for image in 0..<bmp.numImages {
            let width = Int(bmp.widths[image])
            let height = Int(bmp.heights[image])
            let byteCount = width * height / 2
            let slice = Array(bmp.data[offset..<(offset + byteCount)])
            let pixels = decode4bpp(slice, width: width, height: height, palette: palette)
            sprites.append(Sprite(width: width, height: height, pixels: pixels))
            offset += byteCount
        }
        return sprites
    }
}
