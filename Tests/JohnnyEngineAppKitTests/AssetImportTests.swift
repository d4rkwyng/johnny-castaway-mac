//
//  Johnny Castaway for macOS — asset import tests (synthetic files, CI-safe).
//  GPL-3.0-or-later; see LICENSE.
//

import Foundation
import Testing
@testable import JohnnyEngineAppKit

@Suite struct AssetImportTests {

    /// A parseable RESOURCE.MAP with no entries, pointing at RESOURCE.001.
    static let validMap: [UInt8] =
        [0, 1, 5, 7, 1, 0] + Array("RESOURCE.001".utf8) + [0] + [0, 0]

    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("jc-import-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    private func makeSource(_ name: String, map: [UInt8], data: [UInt8], sound: Bool = false) throws -> URL {
        let dir = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(map).write(to: dir.appendingPathComponent("RESOURCE.MAP"))
        try Data(data).write(to: dir.appendingPathComponent("RESOURCE.001"))
        if sound {
            try Data([1, 2, 3]).write(to: dir.appendingPathComponent("sound0.wav"))
        }
        return dir
    }

    private func contents(_ url: URL) throws -> [UInt8] {
        Array(try Data(contentsOf: url))
    }

    @Test func freshInstall() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let src = try makeSource("good", map: Self.validMap, data: [0xAA], sound: true)
        let dest = root.appendingPathComponent("installed")

        try AssetLocator.install(from: src, into: dest)

        #expect(AssetLocator.containsAssets(dest))
        #expect(try contents(dest.appendingPathComponent("RESOURCE.001")) == [0xAA])
        #expect(FileManager.default.fileExists(atPath: dest.appendingPathComponent("sound0.wav").path))
    }

    @Test func validReimportReplacesPrevious() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let dest = root.appendingPathComponent("installed")
        try AssetLocator.install(
            from: try makeSource("v1", map: Self.validMap, data: [0x01], sound: true), into: dest)
        try AssetLocator.install(
            from: try makeSource("v2", map: Self.validMap, data: [0x02]), into: dest)

        #expect(try contents(dest.appendingPathComponent("RESOURCE.001")) == [0x02])
        // Whole directory swapped: the old sound file is gone too.
        #expect(!FileManager.default.fileExists(atPath: dest.appendingPathComponent("sound0.wav").path))
        // No staging directories left behind.
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: root.path)
            .filter { $0.hasPrefix(".") }
        #expect(leftovers.isEmpty)
    }

    @Test func unparseableImportLeavesPreviousInstallIntact() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let dest = root.appendingPathComponent("installed")
        try AssetLocator.install(
            from: try makeSource("good", map: Self.validMap, data: [0xAA]), into: dest)

        // Truncated map: fails to parse.
        let bad = try makeSource("bad", map: [0, 1, 2], data: [0xBB])
        #expect(throws: (any Error).self) {
            try AssetLocator.install(from: bad, into: dest)
        }

        #expect(try contents(dest.appendingPathComponent("RESOURCE.MAP")) == Self.validMap)
        #expect(try contents(dest.appendingPathComponent("RESOURCE.001")) == [0xAA])
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: root.path)
            .filter { $0.hasPrefix(".") }
        #expect(leftovers.isEmpty)
    }

    @Test func missingFileImportLeavesPreviousInstallIntact() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let dest = root.appendingPathComponent("installed")
        try AssetLocator.install(
            from: try makeSource("good", map: Self.validMap, data: [0xAA]), into: dest)

        let incomplete = root.appendingPathComponent("incomplete")
        try FileManager.default.createDirectory(at: incomplete, withIntermediateDirectories: true)
        try Data(Self.validMap).write(to: incomplete.appendingPathComponent("RESOURCE.MAP"))

        #expect(throws: (any Error).self) {
            try AssetLocator.install(from: incomplete, into: dest)
        }
        #expect(try contents(dest.appendingPathComponent("RESOURCE.001")) == [0xAA])
    }
}
