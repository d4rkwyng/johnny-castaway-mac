//
//  Johnny Castaway for macOS — jctool
//
//  Resource extraction: XPM output is byte-identical to jc_reborn's
//  `dump` command (diffable for verification); PNG output is for humans.
//  GPL-3.0-or-later; see LICENSE.
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import JohnnyEngine

enum ExtractFormat {
    case xpm
    case png
}

func extract(directory: URL, outDir: URL, format: ExtractFormat) throws {
    let library = try ResourceLibrary(directory: directory)
    let palette = library.palResources[0]

    let fm = FileManager.default
    for sub in ["SCR", "BMP", "TTM", "ADS"] {
        try fm.createDirectory(
            at: outDir.appendingPathComponent(sub), withIntermediateDirectories: true)
    }

    for scr in library.scrResources {
        let url = outDir.appendingPathComponent("SCR/\(scr.name)")
        switch format {
        case .xpm:
            try xpmImage(
                rawData: scr.data, width: Int(scr.width), height: Int(scr.height),
                palette: palette
            ).write(to: url.appendingPathExtension("xpm"), atomically: true, encoding: .utf8)
        case .png:
            let pixels = PixelDecoder.decode4bpp(
                scr.data, width: Int(scr.width), height: Int(scr.height),
                palette: Palette(palette))
            try writePNG(
                pixels: pixels, width: Int(scr.width), height: Int(scr.height),
                transparentColorKey: false, to: url.appendingPathExtension("png"))
        }
        print("---- Extracting SCR : \(scr.name)")
    }

    for bmp in library.bmpResources {
        let sprites = PixelDecoder.decodeSprites(bmp, palette: Palette(palette))
        var offset = 0
        for (index, sprite) in sprites.enumerated() {
            let name = String(format: "%@.%03d", bmp.name, index)
            let url = outDir.appendingPathComponent("BMP/\(name)")
            switch format {
            case .xpm:
                let byteCount = sprite.width * sprite.height / 2
                let slice = Array(bmp.data[offset..<(offset + byteCount)])
                try xpmImage(
                    rawData: slice, width: sprite.width, height: sprite.height,
                    palette: palette
                ).write(to: url.appendingPathExtension("xpm"), atomically: true, encoding: .utf8)
                offset += byteCount
            case .png:
                try writePNG(
                    pixels: sprite.pixels, width: sprite.width, height: sprite.height,
                    transparentColorKey: true, to: url.appendingPathExtension("png"))
            }
        }
        print("---- Extracting BMP : \(bmp.name) (\(bmp.numImages) images)")
    }

    for ttm in library.ttmResources {
        let url = outDir.appendingPathComponent("TTM/\(ttm.name).txt")
        try Disassembler.disassemble(ttm).write(to: url, atomically: true, encoding: .utf8)
        print("---- Disassembling TTM : \(ttm.name)")
    }

    for ads in library.adsResources {
        let url = outDir.appendingPathComponent("ADS/\(ads.name).txt")
        try Disassembler.disassemble(ads).write(to: url, atomically: true, encoding: .utf8)
        print("---- Disassembling ADS : \(ads.name)")
    }
}

/// XPM text image of raw 4bpp data — same format as jc_reborn's dump.c:
/// one hex char per pixel, palette channels shifted left twice.
private func xpmImage(
    rawData: [UInt8], width: Int, height: Int, palette: PalResource
) -> String {
    var out = "/* XPM */\n"
    out += "static char * scrantic[] = {\n"
    out += "\"\(width) \(height) 16 1\",\n"
    for i in 0..<16 {
        let c = palette.colors[i]
        out += String(
            format: "\"%1x c #%02x%02x%02x\",\n", i,
            Int(c.r) << 2, Int(c.g) << 2, Int(c.b) << 2)
    }

    var offset = 0
    for y in 0..<height {
        out += "\""
        for _ in 0..<(width / 2) {
            out += String(format: "%02x", rawData[offset])
            offset += 1
        }
        out += y == height - 1 ? "\"}\n" : "\",\n"
    }
    return out
}

func writePNG(
    pixels: [Pixel], width: Int, height: Int,
    transparentColorKey: Bool, to url: URL
) throws {
    var rgba = pixels
    if transparentColorKey {
        for i in 0..<rgba.count where rgba[i] == colorKeyPixel {
            rgba[i] = 0
        }
    }

    let data = rgba.withUnsafeBytes { Data($0) }
    guard let provider = CGDataProvider(data: data as CFData),
          let image = CGImage(
            width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(
                rawValue: CGImageAlphaInfo.last.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false,
            intent: .defaultIntent),
          let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else {
        throw EngineError.badData("failed to create PNG for \(url.lastPathComponent)")
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        throw EngineError.badData("failed to write PNG \(url.path)")
    }
}
