//
//  Johnny Castaway for macOS — full story-mode soak test.
//  GPL-3.0-or-later; see LICENSE.
//

import Foundation
import Testing
@testable import JohnnyEngine

@Suite(.enabled(if: assetDir != nil, "JC_ASSET_DIR not set"))
struct StorySoakTests {

    /// Runs the complete screensaver loop (intro → island → scene chains
    /// → walks → fades, day after day) at max speed until the tick budget
    /// runs out. Catches crashes, runaway scripts, and unwound state.
    @Test(arguments: [UInt64(1), 42, 1337])
    func storyModeSoak(seed: UInt64) throws {
        let library = try ResourceLibrary(directory: URL(fileURLWithPath: assetDir!))
        let presenter = CountingPresenter()
        let store = InMemoryStoryStore()
        // ~6 hours of wall-clock animation per seed.
        let clock = ImmediateClock(tickLimit: 1_000_000)

        let engine = Engine(
            library: library, clock: clock, presenter: presenter,
            rng: SeededRandom(seed: seed), storyStore: store)

        do {
            try engine.storyPlay()
            Issue.record("storyPlay returned — it should only exit via cancellation")
        } catch is EngineCancelled {
            // expected: tick budget exhausted while looping forever
        }

        #expect(presenter.frameCount > 1000, "suspiciously few frames presented")
    }
}
