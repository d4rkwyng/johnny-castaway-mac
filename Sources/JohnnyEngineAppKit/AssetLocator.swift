//
//  Johnny Castaway for macOS
//
//  Finds (and imports) the user-supplied RESOURCE.MAP / RESOURCE.001.
//  Search order:
//    1. $JC_ASSET_DIR (development)
//    2. the shared screensaver container's Application Support
//       (~/Library/Containers/com.apple.ScreenSaver.Engine.legacyScreenSaver/
//        Data/Library/Application Support/JohnnyCastaway) — writable by
//       both the sandboxed saver and the demo app, so importing once
//       provisions both
//    3. the current process's Application Support/JohnnyCastaway
//  GPL-3.0-or-later; see LICENSE.
//

import Foundation
import JohnnyEngine

public enum AssetLocator {

    public static let requiredFiles = ["RESOURCE.MAP", "RESOURCE.001"]

    /// The legacyScreenSaver sandbox container path (the saver runs
    /// inside it; other processes can write into it directly).
    public static var saverContainerDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers")
            .appendingPathComponent("com.apple.ScreenSaver.Engine.legacyScreenSaver")
            .appendingPathComponent("Data/Library/Application Support/JohnnyCastaway")
    }

    public static var processAppSupportDirectory: URL {
        (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("JohnnyCastaway")
    }

    public static func containsAssets(_ url: URL) -> Bool {
        requiredFiles.allSatisfy {
            FileManager.default.fileExists(atPath: url.appendingPathComponent($0).path)
        }
    }

    /// First directory containing both resource files, or nil.
    ///
    /// Our own Application Support is checked before the saver's
    /// container: reading another app's container is what makes macOS
    /// ask to "access data from other apps", so only go there when we
    /// have no copy of our own — and then cache the assets locally so
    /// it never has to ask again.
    public static func find() -> URL? {
        if let env = ProcessInfo.processInfo.environment["JC_ASSET_DIR"],
           containsAssets(URL(fileURLWithPath: env)) {
            return URL(fileURLWithPath: env)
        }

        let own = processAppSupportDirectory
        if containsAssets(own) { return own }

        // Inside the saver's sandbox these two are the same directory.
        let shared = saverContainerDirectory
        guard shared.standardizedFileURL != own.standardizedFileURL,
              containsAssets(shared) else { return nil }
        try? install(from: shared, into: own)
        return containsAssets(own) ? own : shared
    }

    /// Copies the resource files (and any soundN.wav next to them) from
    /// `source` into the process's own Application Support and, best
    /// effort, the saver container — one import provisions both the
    /// app and the screensaver.
    ///
    /// Each destination is staged and parsed before anything is
    /// replaced, so a failed import (missing or unparseable files)
    /// leaves the previous install untouched.
    public static func importAssets(from source: URL) throws {
        try install(from: source, into: processAppSupportDirectory)
        let shared = saverContainerDirectory
        if shared.standardizedFileURL != processAppSupportDirectory.standardizedFileURL {
            try? install(from: source, into: shared)
        }
    }

    /// Stages the asset files from `source` into a temporary sibling of
    /// `dest`, validates them by parsing with `ResourceLibrary`, then
    /// swaps the staged directory into place atomically. On any failure
    /// the staging directory is removed and `dest` is left as it was.
    ///
    /// No checksum check against the README's MD5s: those describe one
    /// specific release, while every original release (including
    /// localized ones) ships its own RESOURCE.MAP/RESOURCE.001. A full
    /// parse is what the engine actually needs and rejects corrupt or
    /// wrong files without rejecting legitimate variants.
    static func install(from source: URL, into dest: URL) throws {
        let fm = FileManager.default
        let parent = dest.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)

        // Same parent directory → same volume, so the final swap is a
        // single rename.
        let staging = parent.appendingPathComponent(
            ".\(dest.lastPathComponent)-import-\(UUID().uuidString)")
        try fm.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: staging) }

        try copyAssets(from: source, to: staging)
        _ = try ResourceLibrary(directory: staging)

        if fm.fileExists(atPath: dest.path) {
            // Atomically exchange the two directories; the old install
            // ends up in `staging` and is removed by the defer.
            guard renamex_np(staging.path, dest.path, UInt32(RENAME_SWAP)) == 0 else {
                throw CocoaError(.fileWriteUnknown, userInfo: [
                    NSFilePathErrorKey: dest.path,
                    NSUnderlyingErrorKey: POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO),
                ])
            }
        } else {
            try fm.moveItem(at: staging, to: dest)
        }
    }

    private static func copyAssets(from source: URL, to dest: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: dest, withIntermediateDirectories: true)

        var names = requiredFiles
        names += (0..<25).map { "sound\($0).wav" }

        for name in names {
            let from = source.appendingPathComponent(name)
            guard fm.fileExists(atPath: from.path) else {
                if requiredFiles.contains(name) {
                    throw EngineError.fileNotFound(from.path)
                }
                continue
            }
            let to = dest.appendingPathComponent(name)
            if fm.fileExists(atPath: to.path) {
                try fm.removeItem(at: to)
            }
            try fm.copyItem(at: from, to: to)
        }
    }
}
