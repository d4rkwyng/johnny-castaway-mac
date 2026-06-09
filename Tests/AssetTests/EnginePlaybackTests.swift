//
//  Johnny Castaway for macOS — engine playback tests against real assets.
//  GPL-3.0-or-later; see LICENSE.
//

import Foundation
import Testing
@testable import JohnnyEngine

/// Captures the last frame and counts presentations.
final class CountingPresenter: FramePresenter {
    var frameCount = 0
    var lastFrame: [Pixel] = []

    func present(_ frame: [Pixel]) {
        frameCount += 1
        lastFrame = frame
    }
}

@Suite(.enabled(if: assetDir != nil, "JC_ASSET_DIR not set"))
struct EnginePlaybackTests {

    /// Every TTM script must play to completion without trapping on an
    /// unknown opcode, out-of-range sprite, or malformed jump.
    @Test func everyTtmPlaysToCompletion() throws {
        let library = try ResourceLibrary(directory: URL(fileURLWithPath: assetDir!))

        for ttm in library.ttmResources {
            let presenter = CountingPresenter()
            let clock = ImmediateClock(tickLimit: 1_000_000)
            let engine = Engine(
                library: library, clock: clock, presenter: presenter,
                rng: SeededRandom(seed: 1))
            engine.adsInit()
            engine.adsNoIsland()

            do {
                try engine.playSingleTtm(ttm.name)
            } catch is EngineCancelled {
                Issue.record("\(ttm.name): exceeded 1M tick budget (runaway loop)")
                continue
            }

            #expect(presenter.frameCount > 0, "\(ttm.name) presented no frames")
        }
    }

    /// Deterministic rendering: same script + same seed ⇒ same final frame.
    @Test func ttmPlaybackIsDeterministic() throws {
        let library = try ResourceLibrary(directory: URL(fileURLWithPath: assetDir!))

        func finalFrame() throws -> [Pixel] {
            let presenter = CountingPresenter()
            let engine = Engine(
                library: library, clock: ImmediateClock(tickLimit: 1_000_000),
                presenter: presenter, rng: SeededRandom(seed: 7))
            engine.adsInit()
            engine.adsNoIsland()
            try engine.playSingleTtm("MJJOG.TTM")
            return presenter.lastFrame
        }

        #expect(try finalFrame() == finalFrame())
    }
}
