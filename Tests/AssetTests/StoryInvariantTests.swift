//
//  Johnny Castaway for macOS — story choreography invariants.
//
//  The soak test proves the loop runs; this proves it tells the story
//  by the rules. Observer hooks record every scene and walk, and the
//  test asserts the structural invariants of the original scheduler:
//  day-gated scenes only on their day, walks connecting spot to spot,
//  flag filters (first/final/lowTide/varPos) actually honored.
//
//  GPL-3.0-or-later; see LICENSE.
//

import Foundation
import Testing
@testable import JohnnyEngine

/// Hands out a date that advances 4 simulated hours per query, so one
/// run crosses days (and the 11 → 1 story wrap when seeded near day 11).
private final class FastForwardDate: @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func next() -> Date {
        lock.lock()
        defer { lock.unlock() }
        calls += 1
        return start.addingTimeInterval(Double(calls) * 4 * 3600)
    }
}

@Suite(.enabled(if: assetDir != nil, "JC_ASSET_DIR not set"))
struct StoryInvariantTests {

    private enum Event {
        case scene(StoryScene, day: Int, lowTide: Bool, varPos: Bool, isFinal: Bool)
        case walk(fromSpot: Int, fromHdg: Int, toSpot: Int, toHdg: Int)
    }

    @Test(arguments: [UInt64(7), 99])
    func storyChoreographyInvariants(seed: UInt64) throws {
        let library = try ResourceLibrary(directory: URL(fileURLWithPath: assetDir!))
        let store = InMemoryStoryStore()
        store.currentDay = 9  // a few days from the wrap
        let dates = FastForwardDate()

        let engine = Engine(
            library: library,
            clock: ImmediateClock(tickLimit: 400_000),
            presenter: CountingPresenter(),
            rng: SeededRandom(seed: seed),
            storyStore: store,
            dateProvider: { dates.next() })

        var events: [Event] = []
        engine.storySceneObserver = { [weak engine] scene, isFinal in
            guard let engine else { return }
            events.append(.scene(
                scene,
                day: engine.storyCurrentDay,
                lowTide: engine.islandState.lowTide,
                varPos: engine.islandState.xPos != 0 || engine.islandState.yPos != 0,
                isFinal: isFinal))
        }
        engine.storyWalkObserver = { fromSpot, fromHdg, toSpot, toHdg in
            events.append(.walk(
                fromSpot: fromSpot, fromHdg: fromHdg, toSpot: toSpot, toHdg: toHdg))
        }

        do {
            try engine.storyPlay()
            Issue.record("storyPlay returned — it should only exit via cancellation")
        } catch is EngineCancelled {
            // expected: tick budget exhausted
        }

        let sceneCount = events.count { if case .scene = $0 { true } else { false } }
        #expect(sceneCount > 50, "too few scenes (\(sceneCount)) to be meaningful")

        var daysSeen = Set<Int>()
        var chainLength = 0
        var lastSceneEnd: (spot: Int, hdg: Int)?
        var pendingWalkTarget: (spot: Int, hdg: Int)?

        for event in events {
            switch event {
            case .walk(let fromSpot, let fromHdg, let toSpot, let toHdg):
                if let end = lastSceneEnd {
                    #expect(
                        fromSpot == end.spot && fromHdg == end.hdg,
                        "walk starts at \(fromSpot)/\(fromHdg) but the last scene ended at \(end)")
                }
                pendingWalkTarget = (toSpot, toHdg)

            case .scene(let scene, let day, let lowTide, let varPos, let isFinal):
                let label = "\(scene.adsName) tag \(scene.adsTag)"
                daysSeen.insert(day)

                #expect((1...11).contains(day), "story day \(day) out of range")
                if scene.dayNo != 0 {
                    #expect(scene.dayNo == day, "\(label) is a day-\(scene.dayNo) scene but played on day \(day)")
                }
                if let target = pendingWalkTarget {
                    #expect(
                        target == (scene.spotStart, scene.hdgStart),
                        "walk headed to \(target) but \(label) starts at \(scene.spotStart)/\(scene.hdgStart)")
                }

                if isFinal {
                    #expect(scene.flags.contains(.final), "\(label) closed a loop without the final flag")
                    if scene.flags.contains(.first) {
                        #expect(chainLength == 0, "\(label) is first-only but followed \(chainLength) chain scenes")
                    }
                    chainLength = 0
                    lastSceneEnd = nil
                } else {
                    #expect(!scene.flags.contains(.final), "\(label) has the final flag but played mid-chain")
                    if chainLength > 0 {
                        #expect(!scene.flags.contains(.first), "\(label) is first-only but played mid-chain")
                    }
                    if lowTide {
                        #expect(scene.flags.contains(.lowTideOK), "\(label) played at low tide without lowTideOK")
                    }
                    if varPos {
                        #expect(scene.flags.contains(.varPosOK), "\(label) played on a moved island without varPosOK")
                    }
                    chainLength += 1
                    lastSceneEnd = (scene.spotEnd, scene.hdgEnd)
                }
                pendingWalkTarget = nil
            }
        }

        #expect(daysSeen.count > 1, "date never advanced — day progression untested")
        #expect(daysSeen.contains(1) || daysSeen.max()! < 11,
                "ran past day 11 without wrapping to 1")
    }
}
