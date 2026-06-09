// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "johnny-castaway-mac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "JohnnyEngine", targets: ["JohnnyEngine"]),
        .executable(name: "jctool", targets: ["jctool"]),
        .executable(name: "JohnnyDemo", targets: ["JohnnyDemo"]),
        // Built as a dylib, then assembled into JohnnyCastaway.saver by
        // Scripts/build-saver.sh (SwiftPM cannot produce .saver bundles).
        .library(name: "JohnnySaver", type: .dynamic, targets: ["JohnnySaver"]),
    ],
    targets: [
        // Pure Swift engine: resource parsing, software rendering, TTM/ADS
        // interpreters, island/walk/story logic. Foundation-only — no AppKit.
        .target(name: "JohnnyEngine"),

        // CLI: dump/extract/disasm/render/verify against the original
        // RESOURCE.MAP + RESOURCE.001 files.
        .executableTarget(
            name: "jctool",
            dependencies: ["JohnnyEngine"]
        ),

        // AppKit/AVFoundation glue shared by the demo app and the
        // screensaver: frame→CGImage bridging, WAV sample playback,
        // asset directory discovery/import.
        .target(
            name: "JohnnyEngineAppKit",
            dependencies: ["JohnnyEngine"]
        ),

        // Windowed demo/debug app: play a single TTM or ADS scene with
        // pause/step/speed controls. `swift run JohnnyDemo help`.
        .executableTarget(
            name: "JohnnyDemo",
            dependencies: ["JohnnyEngine", "JohnnyEngineAppKit"]
        ),

        // The screensaver view + configure sheet (ScreenSaver framework).
        .target(
            name: "JohnnySaver",
            dependencies: ["JohnnyEngine", "JohnnyEngineAppKit"]
        ),

        // CI-safe unit tests using synthetic fixtures (no copyrighted bytes).
        .testTarget(
            name: "JohnnyEngineTests",
            dependencies: ["JohnnyEngine"]
        ),

        // Tests that require the original game files; skipped unless
        // JC_ASSET_DIR points at a directory containing them.
        .testTarget(
            name: "AssetTests",
            dependencies: ["JohnnyEngine"],
            resources: [.copy("Goldens")]
        ),
    ]
)
