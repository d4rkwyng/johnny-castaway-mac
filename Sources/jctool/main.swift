//
//  Johnny Castaway for macOS — jctool
//
//  Resource inspection CLI (port of jc_reborn's dump utilities).
//  GPL-3.0-or-later; see LICENSE.
//

import Foundation
import CryptoKit
import JohnnyEngine

let knownChecksums: [String: (size: Int, md5: String)] = [
    "RESOURCE.MAP": (1461, "374e6d05c5e0acd88fb5af748948c899"),
    "RESOURCE.001": (1_175_645, "8bb6c99e9129806b5089a39d24228a36"),
]

func usage() -> Never {
    print("""
    usage: jctool <command> <asset-dir> [options]

    commands:
      verify <dir>                 check RESOURCE.MAP / RESOURCE.001 sizes + MD5s and parse them
      dump <dir>                   parse and list every resource with details
      extract <dir> [--png|--xpm] [--out <outdir>]
                                   extract backgrounds/sprites (PNG default; XPM matches
                                   jc_reborn's dump output) + TTM/ADS disassembly
    """)
    exit(2)
}

func md5Hex(of url: URL) throws -> String {
    let data = try Data(contentsOf: url)
    return Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func verify(directory: URL) throws {
    var ok = true
    for (name, expected) in knownChecksums.sorted(by: { $0.key < $1.key }) {
        let url = directory.appendingPathComponent(name)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int else {
            print("MISSING  \(name)")
            ok = false
            continue
        }
        let hash = try md5Hex(of: url)
        let sizeOK = size == expected.size
        let hashOK = hash == expected.md5
        print("\(sizeOK && hashOK ? "OK      " : "MISMATCH") \(name)  size=\(size) md5=\(hash)")
        ok = ok && sizeOK && hashOK
    }

    let library = try ResourceLibrary(directory: directory)
    print("""
    parsed   \(library.adsResources.count) ADS, \(library.bmpResources.count) BMP, \
    \(library.palResources.count) PAL, \(library.scrResources.count) SCR, \
    \(library.ttmResources.count) TTM resources
    """)
    exit(ok ? 0 : 1)
}

func dump(directory: URL) throws {
    let library = try ResourceLibrary(directory: directory)

    print("=== SCR (\(library.scrResources.count)) ===")
    for r in library.scrResources {
        print("  \(r.name)  \(r.width)x\(r.height)  flags=\(r.flags)  \(r.data.count) bytes")
    }

    print("=== BMP (\(library.bmpResources.count)) ===")
    for r in library.bmpResources {
        let dims = zip(r.widths, r.heights).map { "\($0)x\($1)" }.joined(separator: " ")
        print("  \(r.name)  \(r.numImages) images  \(r.data.count) bytes  [\(dims)]")
    }

    print("=== PAL (\(library.palResources.count)) ===")
    for r in library.palResources {
        let c = r.colors.prefix(8).map { "(\($0.r),\($0.g),\($0.b))" }.joined()
        print("  \(r.name)  first colors: \(c)")
    }

    print("=== TTM (\(library.ttmResources.count)) ===")
    for r in library.ttmResources {
        print("  \(r.name)  ver=\(r.versionString)  pages=\(r.numPages)  \(r.data.count) bytes  \(r.tags.count) tags")
        for tag in r.tags {
            print("      tag \(tag.id): \(tag.text)")
        }
    }

    print("=== ADS (\(library.adsResources.count)) ===")
    for r in library.adsResources {
        print("  \(r.name)  ver=\(r.versionString)  \(r.data.count) bytes")
        for res in r.res {
            print("      res \(res.id): \(res.name)")
        }
        for tag in r.tags {
            print("      tag \(tag.id): \(tag.text)")
        }
    }
}

let args = CommandLine.arguments
guard args.count >= 3 else { usage() }
let dir = URL(fileURLWithPath: args[2])

do {
    switch args[1] {
    case "verify": try verify(directory: dir)
    case "dump": try dump(directory: dir)
    case "extract":
        let format: ExtractFormat = args.contains("--xpm") ? .xpm : .png
        var outDir = URL(fileURLWithPath: "extracted")
        if let i = args.firstIndex(of: "--out"), i + 1 < args.count {
            outDir = URL(fileURLWithPath: args[i + 1])
        }
        try extract(directory: dir, outDir: outDir, format: format)
    case "goldens":
        try printGoldens(directory: dir)
    case "render":
        try render(directory: dir, arguments: Array(args.dropFirst(3)))
    default: usage()
    }
} catch {
    FileHandle.standardError.write("error: \(error)\n".data(using: .utf8)!)
    exit(1)
}
