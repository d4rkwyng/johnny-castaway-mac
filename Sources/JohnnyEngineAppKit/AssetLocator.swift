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
    public static func find() -> URL? {
        var candidates = [URL]()
        if let env = ProcessInfo.processInfo.environment["JC_ASSET_DIR"] {
            candidates.append(URL(fileURLWithPath: env))
        }
        candidates.append(saverContainerDirectory)
        candidates.append(processAppSupportDirectory)
        return candidates.first(where: containsAssets)
    }

    /// Copies the resource files (and any soundN.wav next to them) from
    /// `source` into the saver container, creating it if needed.
    public static func importAssets(from source: URL) throws {
        let fm = FileManager.default
        let dest = saverContainerDirectory
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
