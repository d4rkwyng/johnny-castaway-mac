//
//  Johnny Castaway for macOS
//
//  Engine logic ported from 'Johnny Reborn' (jc_reborn) resource.c,
//  Copyright (C) 2019 Jeremie GUILLAUME — GPL-3.0-or-later.
//  Swift port Copyright (C) 2026 the johnny-castaway-mac contributors.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//

import Foundation

public struct ResourceTag: Sendable {
    public let id: UInt16
    public let text: String
}

/// ADS: top-level scene scheduler script. Lists the TTM resources it
/// drives (`res`), the bytecode, and named entry tags.
public struct AdsResource: Sendable {
    public let name: String
    public let versionString: String
    public let res: [(id: UInt16, name: String)]
    public let data: [UInt8]
    public let tags: [ResourceTag]

    public func tag(withId id: UInt16) -> ResourceTag? {
        tags.first { $0.id == id }
    }
}

/// BMP: a sprite sheet — numImages images stored consecutively as
/// 4-bit-per-pixel data, with per-image widths/heights.
public struct BmpResource: Sendable {
    public let name: String
    public let width: UInt16
    public let height: UInt16
    public let numImages: Int
    public let widths: [UInt16]
    public let heights: [UInt16]
    public let data: [UInt8]
}

/// PAL: VGA palette (6-bit-per-channel RGB).
public struct PalResource: Sendable {
    public struct Color: Sendable {
        public let r: UInt8
        public let g: UInt8
        public let b: UInt8
    }
    public let name: String
    public let colors: [Color]  // 256 entries
}

/// SCR: full-screen 640×480 background image, 4 bits per pixel.
public struct ScrResource: Sendable {
    public let name: String
    public let flags: UInt16
    public let width: UInt16
    public let height: UInt16
    public let data: [UInt8]
}

/// TTM: animation script — bytecode plus named entry tags.
public struct TtmResource: Sendable {
    public let name: String
    public let versionString: String
    public let numPages: UInt32
    public let data: [UInt8]
    public let tags: [ResourceTag]
}

/// Parses RESOURCE.MAP + RESOURCE.001 and exposes the five resource
/// types by name. Port of resource.c.
public struct ResourceLibrary: Sendable {

    public private(set) var adsResources: [AdsResource] = []
    public private(set) var bmpResources: [BmpResource] = []
    public private(set) var palResources: [PalResource] = []
    public private(set) var scrResources: [ScrResource] = []
    public private(set) var ttmResources: [TtmResource] = []

    /// Name of the data file referenced by the map (always "RESOURCE.001").
    public let dataFileName: String

    /// Loads RESOURCE.MAP from `directory` and the data file it references.
    public init(directory: URL) throws {
        let mapURL = directory.appendingPathComponent("RESOURCE.MAP")
        guard let mapData = try? Data(contentsOf: mapURL) else {
            throw EngineError.fileNotFound(mapURL.path)
        }
        let entries = try Self.parseMap(Array(mapData))
        let dataName = entries.dataFileName

        let dataURL = directory.appendingPathComponent(dataName)
        guard let resData = try? Data(contentsOf: dataURL) else {
            throw EngineError.fileNotFound(dataURL.path)
        }
        try self.init(mapData: Array(mapData), resourceData: Array(resData))
    }

    /// In-memory variant for tests.
    public init(mapData: [UInt8], resourceData: [UInt8]) throws {
        let map = try Self.parseMap(mapData)
        self.dataFileName = map.dataFileName

        for entry in map.entries {
            var r = ByteReader(resourceData, at: Int(entry.offset))
            let resName = try r.fixedString(13)
            _ = try r.u32()  // resSize — unused, sizes come from chunk headers

            guard resName.count >= 4 else { continue }
            let ext = String(resName.suffix(4))

            switch ext {
            case ".ADS":
                adsResources.append(try Self.parseAds(&r, name: resName))
            case ".BMP":
                bmpResources.append(try Self.parseBmp(&r, name: resName))
            case ".PAL":
                palResources.append(try Self.parsePal(&r, name: resName))
            case ".SCR":
                scrResources.append(try Self.parseScr(&r, name: resName))
            case ".TTM":
                ttmResources.append(try Self.parseTtm(&r, name: resName))
            default:
                break  // FILES.VIN — just a file list, not needed
            }
        }
    }

    // MARK: - Lookup (port of findXxxResource)

    public func ads(_ name: String) throws -> AdsResource {
        guard let r = adsResources.first(where: { $0.name == name }) else {
            throw EngineError.resourceNotFound(name)
        }
        return r
    }

    public func bmp(_ name: String) throws -> BmpResource {
        guard let r = bmpResources.first(where: { $0.name == name }) else {
            throw EngineError.resourceNotFound(name)
        }
        return r
    }

    public func scr(_ name: String) throws -> ScrResource {
        guard let r = scrResources.first(where: { $0.name == name }) else {
            throw EngineError.resourceNotFound(name)
        }
        return r
    }

    public func ttm(_ name: String) throws -> TtmResource {
        guard let r = ttmResources.first(where: { $0.name == name }) else {
            throw EngineError.resourceNotFound(name)
        }
        return r
    }

    // MARK: - RESOURCE.MAP

    struct MapContents {
        let dataFileName: String
        let entries: [(length: UInt32, offset: UInt32)]
    }

    static func parseMap(_ bytes: [UInt8]) throws -> MapContents {
        var r = ByteReader(bytes)
        _ = try r.block(6)  // 6 unknown header bytes
        let dataFileName = try r.cString(max: 13)
        let numEntries = Int(try r.u16())
        var entries = [(length: UInt32, offset: UInt32)]()
        entries.reserveCapacity(numEntries)
        for _ in 0..<numEntries {
            let length = try r.u32()
            let offset = try r.u32()
            entries.append((length, offset))
        }
        return MapContents(dataFileName: dataFileName, entries: entries)
    }

    // MARK: - Typed resource parsers

    /// Reads the common "<TAG:> u32(size) u8(method) u32(outSize) payload"
    /// compressed-block pattern. The stored size includes the 5 bytes of
    /// method + outSize, hence the subtraction.
    private static func compressedBlock(
        _ r: inout ByteReader, tag: String, context: String
    ) throws -> [UInt8] {
        try r.expectTag(tag, context: context)
        let compressedSize = Int(try r.u32()) - 5
        let method = try r.u8()
        let outSize = Int(try r.u32())
        return try Decompressor.decompress(
            method: method, reader: &r, inSize: compressedSize, outSize: outSize)
    }

    static func parseAds(_ r: inout ByteReader, name: String) throws -> AdsResource {
        try r.expectTag("VER:", context: "ADS resource")
        _ = try r.u32()  // versionSize
        let version = try r.fixedString(5)

        try r.expectTag("ADS:", context: "ADS resource")
        _ = try r.block(4)

        try r.expectTag("RES:", context: "ADS resource")
        _ = try r.u32()  // resSize
        let numRes = Int(try r.u16())
        var res = [(id: UInt16, name: String)]()
        res.reserveCapacity(numRes)
        for _ in 0..<numRes {
            let id = try r.u16()
            let resName = try r.cString(max: 40)
            res.append((id, resName))
        }

        let data = try compressedBlock(&r, tag: "SCR:", context: "ADS resource")

        try r.expectTag("TAG:", context: "ADS resource")
        _ = try r.u32()  // tagSize
        let numTags = Int(try r.u16())
        var tags = [ResourceTag]()
        tags.reserveCapacity(numTags)
        for _ in 0..<numTags {
            let id = try r.u16()
            let text = try r.cString(max: 40)
            tags.append(ResourceTag(id: id, text: text))
        }

        return AdsResource(name: name, versionString: version, res: res, data: data, tags: tags)
    }

    static func parseBmp(_ r: inout ByteReader, name: String) throws -> BmpResource {
        try r.expectTag("BMP:", context: "BMP resource")
        let width = try r.u16()
        let height = try r.u16()

        try r.expectTag("INF:", context: "BMP resource")
        _ = try r.u32()  // dataSize
        let numImages = Int(try r.u16())
        let widths = try r.u16Block(numImages)
        let heights = try r.u16Block(numImages)

        let data = try compressedBlock(&r, tag: "BIN:", context: "BMP resource")

        return BmpResource(
            name: name, width: width, height: height,
            numImages: numImages, widths: widths, heights: heights, data: data)
    }

    static func parsePal(_ r: inout ByteReader, name: String) throws -> PalResource {
        try r.expectTag("PAL:", context: "PAL resource")
        _ = try r.u16()  // size
        _ = try r.u8()
        _ = try r.u8()

        try r.expectTag("VGA:", context: "PAL resource")
        _ = try r.block(4)

        var colors = [PalResource.Color]()
        colors.reserveCapacity(256)
        for _ in 0..<256 {
            let red = try r.u8()
            let green = try r.u8()
            let blue = try r.u8()
            colors.append(PalResource.Color(r: red, g: green, b: blue))
        }
        return PalResource(name: name, colors: colors)
    }

    static func parseScr(_ r: inout ByteReader, name: String) throws -> ScrResource {
        try r.expectTag("SCR:", context: "SCR resource")
        _ = try r.u16()  // totalSize
        let flags = try r.u16()

        try r.expectTag("DIM:", context: "SCR resource")
        _ = try r.u32()  // dimSize
        let width = try r.u16()
        let height = try r.u16()

        let data = try compressedBlock(&r, tag: "BIN:", context: "SCR resource")

        return ScrResource(name: name, flags: flags, width: width, height: height, data: data)
    }

    static func parseTtm(_ r: inout ByteReader, name: String) throws -> TtmResource {
        try r.expectTag("VER:", context: "TTM resource")
        _ = try r.u32()  // versionSize
        let version = try r.fixedString(5)

        try r.expectTag("PAG:", context: "TTM resource")
        let numPages = try r.u32()
        _ = try r.u8()
        _ = try r.u8()

        let data = try compressedBlock(&r, tag: "TT3:", context: "TTM resource")

        try r.expectTag("TTI:", context: "TTM resource")
        _ = try r.block(4)

        try r.expectTag("TAG:", context: "TTM resource")
        _ = try r.u32()  // tagSize
        let numTags = Int(try r.u16())
        var tags = [ResourceTag]()
        tags.reserveCapacity(numTags)
        for _ in 0..<numTags {
            let id = try r.u16()
            let text = try r.cString(max: 40)
            tags.append(ResourceTag(id: id, text: text))
        }

        return TtmResource(
            name: name, versionString: version, numPages: numPages, data: data, tags: tags)
    }
}
