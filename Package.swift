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
