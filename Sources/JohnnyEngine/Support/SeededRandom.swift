//
//  Johnny Castaway for macOS
//
//  GPL-3.0-or-later; see LICENSE.
//

import Foundation

/// Seedable RNG (SplitMix64). Replaces the C engine's rand() so that
/// golden tests are reproducible and multiple monitors can each run a
/// differently-seeded engine.
public struct SeededRandom: Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public init() {
        self.init(seed: UInt64.random(in: .min ... .max))
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Equivalent of `rand() % n`.
    public mutating func next(upperBound: Int) -> Int {
        Int(next() % UInt64(upperBound))
    }
}
