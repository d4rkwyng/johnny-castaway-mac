//
//  Johnny Castaway for macOS — jctool
//
//  Headless scene renderer: plays a TTM or ADS scene with an immediate
//  clock and writes selected frames as PNGs. Used to eyeball and to
//  golden-test engine output without a GUI.
//  GPL-3.0-or-later; see LICENSE.
//

import Foundation
import JohnnyEngine

final class SamplingPresenter: FramePresenter {
    let sampleEvery: Int
    let outDir: URL
    let prefix: String
    var frameCount = 0
    var written = 0
    let maxWritten: Int

    init(outDir: URL, prefix: String, sampleEvery: Int, maxWritten: Int = 200) {
        self.outDir = outDir
        self.prefix = prefix
        self.sampleEvery = sampleEvery
        self.maxWritten = maxWritten
    }

    func present(_ frame: [Pixel]) {
        frameCount += 1
        guard frameCount % sampleEvery == 0, written < maxWritten else { return }
        let url = outDir.appendingPathComponent(
            String(format: "%@.%05d.png", prefix, frameCount))
        try? writePNG(
            pixels: frame, width: 640, height: 480,
            transparentColorKey: false, to: url)
        written += 1
    }
}

func render(directory: URL, arguments: [String]) throws {
    guard arguments.count >= 2 else {
        throw EngineError.badData(
            "usage: jctool render <dir> ttm <NAME> [--every N] [--out dir]\n" +
            "       jctool render <dir> ads <NAME> <tag> [--every N] [--out dir]")
    }

    var outDir = URL(fileURLWithPath: "frames")
    var every = 10
    if let i = arguments.firstIndex(of: "--out"), i + 1 < arguments.count {
        outDir = URL(fileURLWithPath: arguments[i + 1])
    }
    if let i = arguments.firstIndex(of: "--every"), i + 1 < arguments.count {
        every = Int(arguments[i + 1]) ?? 10
    }
    try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

    let library = try ResourceLibrary(directory: directory)
    let kind = arguments[0]
    let name = arguments[1]

    let presenter = SamplingPresenter(
        outDir: outDir, prefix: name, sampleEvery: every)
    let engine = Engine(
        library: library,
        clock: ImmediateClock(tickLimit: 1_000_000),
        presenter: presenter,
        rng: SeededRandom(seed: 42))

    engine.adsInit()
    engine.adsNoIsland()

    switch kind {
    case "ttm":
        try engine.playSingleTtm(name)
    case "ads":
        guard arguments.count >= 3, let tag = UInt16(arguments[2]) else {
            throw EngineError.badData("ads render needs a tag number")
        }
        try engine.adsPlay(name, tag)
    default:
        throw EngineError.badData("unknown render kind '\(kind)' (expected ttm/ads)")
    }

    print("\(presenter.frameCount) frames played, \(presenter.written) PNGs written to \(outDir.path)")
}
