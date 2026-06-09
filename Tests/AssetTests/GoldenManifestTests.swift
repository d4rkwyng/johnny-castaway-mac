//
//  Johnny Castaway for macOS — golden-hash regression tests.
//
//  Verifies that every decompressed resource payload matches the
//  SHA-256 recorded in Goldens/manifest.json (generated once via
//  `jctool goldens Assets`). Catches any regression in the RLE/LZW
//  decompressors or container parsers.
//
//  GPL-3.0-or-later; see LICENSE.
//

import Foundation
import Testing
import CryptoKit
@testable import JohnnyEngine

private func sha256Hex(_ bytes: [UInt8]) -> String {
    SHA256.hash(data: Data(bytes)).map { String(format: "%02x", $0) }.joined()
}

@Suite(.enabled(if: assetDir != nil, "JC_ASSET_DIR not set"))
struct GoldenManifestTests {

    @Test func allResourcePayloadsMatchGoldenHashes() throws {
        let manifestURL = Bundle.module.url(
            forResource: "manifest", withExtension: "json", subdirectory: "Goldens")!
        let manifest = try JSONSerialization.jsonObject(
            with: Data(contentsOf: manifestURL)) as! [String: String]

        let library = try ResourceLibrary(directory: URL(fileURLWithPath: assetDir!))

        var checked = 0
        for r in library.scrResources {
            #expect(sha256Hex(r.data) == manifest[r.name], "\(r.name)")
            checked += 1
        }
        for r in library.bmpResources {
            #expect(sha256Hex(r.data) == manifest[r.name], "\(r.name)")
            checked += 1
        }
        for r in library.ttmResources {
            #expect(sha256Hex(r.data) == manifest[r.name], "\(r.name)")
            checked += 1
        }
        for r in library.adsResources {
            #expect(sha256Hex(r.data) == manifest[r.name], "\(r.name)")
            checked += 1
        }
        for r in library.palResources {
            let raw = r.colors.flatMap { [$0.r, $0.g, $0.b] }
            #expect(sha256Hex(raw) == manifest[r.name], "\(r.name)")
            checked += 1
        }
        #expect(checked == manifest.count)
    }
}
