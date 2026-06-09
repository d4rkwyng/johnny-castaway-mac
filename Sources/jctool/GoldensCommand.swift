//
//  Johnny Castaway for macOS — jctool
//
//  Emits a JSON manifest of SHA-256 hashes of every resource's
//  decompressed payload. The hashes (not the data) are committed at
//  Tests/AssetTests/Goldens/manifest.json and pin the decompression
//  pipeline against regressions.
//  GPL-3.0-or-later; see LICENSE.
//

import Foundation
import CryptoKit
import JohnnyEngine

func sha256Hex(_ bytes: [UInt8]) -> String {
    SHA256.hash(data: Data(bytes)).map { String(format: "%02x", $0) }.joined()
}

func printGoldens(directory: URL) throws {
    let library = try ResourceLibrary(directory: directory)
    var entries = [String: String]()

    for r in library.scrResources { entries[r.name] = sha256Hex(r.data) }
    for r in library.bmpResources { entries[r.name] = sha256Hex(r.data) }
    for r in library.ttmResources { entries[r.name] = sha256Hex(r.data) }
    for r in library.adsResources { entries[r.name] = sha256Hex(r.data) }
    for r in library.palResources {
        let raw = r.colors.flatMap { [$0.r, $0.g, $0.b] }
        entries[r.name] = sha256Hex(raw)
    }

    let json = try JSONSerialization.data(
        withJSONObject: entries, options: [.prettyPrinted, .sortedKeys])
    print(String(decoding: json, as: UTF8.self))
}
