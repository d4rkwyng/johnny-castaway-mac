//
//  Johnny Castaway for macOS — tests against the original game files.
//
//  These run only when JC_ASSET_DIR points at a directory containing
//  RESOURCE.MAP and RESOURCE.001. They are skipped on CI, which must
//  never contain the copyrighted assets. Goldens/manifest.json holds
//  only SHA-256 hashes of decoded resources — no copyrighted bytes.
//
//  GPL-3.0-or-later; see LICENSE.
//

import Foundation
import Testing
@testable import JohnnyEngine

let assetDir = ProcessInfo.processInfo.environment["JC_ASSET_DIR"]

@Suite(.enabled(if: assetDir != nil, "JC_ASSET_DIR not set"))
struct ResourceLibraryAssetTests {

    @Test func parsesAllResources() throws {
        let library = try ResourceLibrary(directory: URL(fileURLWithPath: assetDir!))

        #expect(library.dataFileName == "RESOURCE.001")
        #expect(library.adsResources.count == 10)
        #expect(library.bmpResources.count == 117)
        #expect(library.palResources.count == 1)
        #expect(library.scrResources.count == 10)
        #expect(library.ttmResources.count == 41)
    }

    @Test func knownResourcesExist() throws {
        let library = try ResourceLibrary(directory: URL(fileURLWithPath: assetDir!))

        // Core resources every scene depends on.
        _ = try library.ads("ACTIVITY.ADS")

        // The island background is 640×350 (EGA-heritage art); the night
        // and ocean backgrounds are 640×480.
        let island = try library.scr("ISLETEMP.SCR")
        #expect(island.width == 640)
        #expect(island.height == 350)
        // 4 bits per pixel
        #expect(island.data.count == 640 * 350 / 2)

        let night = try library.scr("NIGHT.SCR")
        #expect(night.height == 480)
        #expect(night.data.count == 640 * 480 / 2)
    }
}
