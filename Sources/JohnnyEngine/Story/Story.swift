//
//  Johnny Castaway for macOS
//
//  Engine logic ported from 'Johnny Reborn' (jc_reborn) story.c and
//  story_data.h, Copyright (C) 2019 Jeremie GUILLAUME — GPL-3.0-or-later.
//  Swift port Copyright (C) 2026 the johnny-castaway-mac contributors.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//

import Foundation

struct SceneFlags: OptionSet {
    let rawValue: Int
    static let final = SceneFlags(rawValue: 0x01)
    static let first = SceneFlags(rawValue: 0x02)
    static let island = SceneFlags(rawValue: 0x04)
    static let leftIsland = SceneFlags(rawValue: 0x08)
    static let varPosOK = SceneFlags(rawValue: 0x10)
    static let lowTideOK = SceneFlags(rawValue: 0x20)
    static let noRaft = SceneFlags(rawValue: 0x40)
    static let holidayNOK = SceneFlags(rawValue: 0x80)
}

struct StoryScene {
    let adsName: String
    let adsTag: UInt16
    let spotStart: Int
    let hdgStart: Int
    let spotEnd: Int
    let hdgEnd: Int
    let dayNo: Int
    let flags: SceneFlags
}

// Spots: A=0 … F=5. Headings: S=0, SW=1, W=2, NW=3, N=4, NE=5, E=6, SE=7.
private let A = 0, B = 1, C = 2, D = 3, E = 4, F = 5
private let S = 0, SW = 1, W = 2, NW = 3, N = 4, NE = 5, EH = 6, SE = 7

let storyScenes: [StoryScene] = [
    .init(adsName: "ACTIVITY.ADS", adsTag: 1, spotStart: E, hdgStart: SE, spotEnd: 0, hdgEnd: 0, dayNo: 0, flags: [.island, .final, .varPosOK]),
    .init(adsName: "ACTIVITY.ADS", adsTag: 12, spotStart: D, hdgStart: SW, spotEnd: 0, hdgEnd: 0, dayNo: 0, flags: [.island, .final, .varPosOK, .lowTideOK]),
    .init(adsName: "ACTIVITY.ADS", adsTag: 11, spotStart: 0, hdgStart: 0, spotEnd: 0, hdgEnd: 0, dayNo: 0, flags: [.island, .final, .first, .varPosOK]),
    .init(adsName: "ACTIVITY.ADS", adsTag: 10, spotStart: D, hdgStart: SW, spotEnd: 0, hdgEnd: 0, dayNo: 0, flags: [.island, .final, .varPosOK, .lowTideOK]),
    .init(adsName: "ACTIVITY.ADS", adsTag: 4, spotStart: E, hdgStart: SE, spotEnd: E, hdgEnd: SE, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "ACTIVITY.ADS", adsTag: 5, spotStart: E, hdgStart: SW, spotEnd: 0, hdgEnd: 0, dayNo: 0, flags: [.island, .final, .varPosOK, .lowTideOK]),
    .init(adsName: "ACTIVITY.ADS", adsTag: 6, spotStart: D, hdgStart: SW, spotEnd: 0, hdgEnd: 0, dayNo: 0, flags: [.island, .final, .varPosOK]),
    .init(adsName: "ACTIVITY.ADS", adsTag: 7, spotStart: D, hdgStart: SW, spotEnd: F, hdgEnd: SW, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "ACTIVITY.ADS", adsTag: 8, spotStart: 0, hdgStart: 0, spotEnd: D, hdgEnd: SE, dayNo: 0, flags: [.island, .first, .varPosOK]),
    .init(adsName: "ACTIVITY.ADS", adsTag: 9, spotStart: E, hdgStart: EH, spotEnd: 0, hdgEnd: 0, dayNo: 0, flags: [.island, .final, .lowTideOK]),

    .init(adsName: "BUILDING.ADS", adsTag: 1, spotStart: F, hdgStart: W, spotEnd: A, hdgEnd: W, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "BUILDING.ADS", adsTag: 4, spotStart: A, hdgStart: EH, spotEnd: 0, hdgEnd: 0, dayNo: 0, flags: [.island, .final, .varPosOK]),
    .init(adsName: "BUILDING.ADS", adsTag: 3, spotStart: A, hdgStart: EH, spotEnd: C, hdgEnd: SE, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "BUILDING.ADS", adsTag: 2, spotStart: F, hdgStart: W, spotEnd: 0, hdgEnd: 0, dayNo: 0, flags: [.island, .final, .varPosOK]),
    .init(adsName: "BUILDING.ADS", adsTag: 5, spotStart: D, hdgStart: W, spotEnd: D, hdgEnd: EH, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "BUILDING.ADS", adsTag: 7, spotStart: D, hdgStart: W, spotEnd: D, hdgEnd: EH, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "BUILDING.ADS", adsTag: 6, spotStart: A, hdgStart: EH, spotEnd: 0, hdgEnd: 0, dayNo: 0, flags: [.island, .final, .varPosOK]),

    .init(adsName: "FISHING.ADS", adsTag: 1, spotStart: D, hdgStart: W, spotEnd: D, hdgEnd: EH, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "FISHING.ADS", adsTag: 2, spotStart: D, hdgStart: W, spotEnd: D, hdgEnd: EH, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "FISHING.ADS", adsTag: 3, spotStart: D, hdgStart: W, spotEnd: 0, hdgEnd: 0, dayNo: 0, flags: [.island, .final, .varPosOK, .lowTideOK]),
    .init(adsName: "FISHING.ADS", adsTag: 4, spotStart: E, hdgStart: EH, spotEnd: 0, hdgEnd: 0, dayNo: 0, flags: [.island, .final, .leftIsland, .lowTideOK]),
    .init(adsName: "FISHING.ADS", adsTag: 5, spotStart: E, hdgStart: EH, spotEnd: 0, hdgEnd: 0, dayNo: 0, flags: [.island, .final, .varPosOK]),
    .init(adsName: "FISHING.ADS", adsTag: 6, spotStart: D, hdgStart: W, spotEnd: 0, hdgEnd: 0, dayNo: 0, flags: [.island, .final, .lowTideOK]),
    .init(adsName: "FISHING.ADS", adsTag: 7, spotStart: E, hdgStart: EH, spotEnd: E, hdgEnd: W, dayNo: 0, flags: [.island, .leftIsland, .varPosOK, .lowTideOK]),
    .init(adsName: "FISHING.ADS", adsTag: 8, spotStart: E, hdgStart: EH, spotEnd: E, hdgEnd: W, dayNo: 0, flags: [.island, .leftIsland, .varPosOK, .lowTideOK]),

    .init(adsName: "JOHNNY.ADS", adsTag: 1, spotStart: 0, hdgStart: 0, spotEnd: 0, hdgEnd: 0, dayNo: 11, flags: [.final, .first]),
    .init(adsName: "JOHNNY.ADS", adsTag: 2, spotStart: E, hdgStart: SW, spotEnd: F, hdgEnd: 0, dayNo: 2, flags: [.island, .final, .varPosOK]),
    .init(adsName: "JOHNNY.ADS", adsTag: 3, spotStart: E, hdgStart: SW, spotEnd: F, hdgEnd: NE, dayNo: 6, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "JOHNNY.ADS", adsTag: 4, spotStart: E, hdgStart: SW, spotEnd: F, hdgEnd: NE, dayNo: 0, flags: [.island, .varPosOK]),
    .init(adsName: "JOHNNY.ADS", adsTag: 5, spotStart: E, hdgStart: SW, spotEnd: F, hdgEnd: NE, dayNo: 0, flags: [.island, .varPosOK]),
    .init(adsName: "JOHNNY.ADS", adsTag: 6, spotStart: 0, hdgStart: 0, spotEnd: 0, hdgEnd: 0, dayNo: 10, flags: [.final, .first]),

    .init(adsName: "MARY.ADS", adsTag: 1, spotStart: E, hdgStart: SW, spotEnd: 0, hdgEnd: 0, dayNo: 5, flags: [.island, .final, .varPosOK, .lowTideOK]),
    .init(adsName: "MARY.ADS", adsTag: 3, spotStart: F, hdgStart: SW, spotEnd: 0, hdgEnd: 0, dayNo: 4, flags: [.island, .final, .first, .varPosOK]),
    .init(adsName: "MARY.ADS", adsTag: 2, spotStart: E, hdgStart: EH, spotEnd: 0, hdgEnd: 0, dayNo: 1, flags: [.island, .final, .varPosOK]),
    .init(adsName: "MARY.ADS", adsTag: 4, spotStart: E, hdgStart: EH, spotEnd: 0, hdgEnd: 0, dayNo: 7, flags: [.island, .final, .varPosOK]),
    .init(adsName: "MARY.ADS", adsTag: 5, spotStart: E, hdgStart: NW, spotEnd: 0, hdgEnd: 0, dayNo: 8, flags: [.island, .leftIsland, .final, .first, .noRaft, .varPosOK]),

    .init(adsName: "MISCGAG.ADS", adsTag: 1, spotStart: D, hdgStart: W, spotEnd: 0, hdgEnd: 0, dayNo: 0, flags: [.island, .final, .varPosOK, .lowTideOK]),
    .init(adsName: "MISCGAG.ADS", adsTag: 2, spotStart: D, hdgStart: W, spotEnd: 0, hdgEnd: 0, dayNo: 0, flags: [.island, .final, .varPosOK]),

    .init(adsName: "STAND.ADS", adsTag: 1, spotStart: A, hdgStart: SW, spotEnd: A, hdgEnd: SW, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "STAND.ADS", adsTag: 2, spotStart: A, hdgStart: W, spotEnd: A, hdgEnd: W, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "STAND.ADS", adsTag: 3, spotStart: A, hdgStart: NW, spotEnd: A, hdgEnd: NW, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "STAND.ADS", adsTag: 4, spotStart: B, hdgStart: SW, spotEnd: B, hdgEnd: SW, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "STAND.ADS", adsTag: 5, spotStart: B, hdgStart: S, spotEnd: B, hdgEnd: S, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "STAND.ADS", adsTag: 6, spotStart: B, hdgStart: SE, spotEnd: B, hdgEnd: SE, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "STAND.ADS", adsTag: 7, spotStart: C, hdgStart: NE, spotEnd: C, hdgEnd: NE, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "STAND.ADS", adsTag: 8, spotStart: C, hdgStart: EH, spotEnd: C, hdgEnd: EH, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "STAND.ADS", adsTag: 9, spotStart: D, hdgStart: NW, spotEnd: D, hdgEnd: NW, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "STAND.ADS", adsTag: 10, spotStart: D, hdgStart: NE, spotEnd: D, hdgEnd: NE, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "STAND.ADS", adsTag: 11, spotStart: E, hdgStart: NW, spotEnd: E, hdgEnd: NW, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "STAND.ADS", adsTag: 12, spotStart: F, hdgStart: S, spotEnd: F, hdgEnd: S, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "STAND.ADS", adsTag: 15, spotStart: A, hdgStart: S, spotEnd: A, hdgEnd: S, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "STAND.ADS", adsTag: 16, spotStart: C, hdgStart: S, spotEnd: C, hdgEnd: S, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),

    .init(adsName: "SUZY.ADS", adsTag: 1, spotStart: 0, hdgStart: 0, spotEnd: 0, hdgEnd: 0, dayNo: 3, flags: [.final, .first]),
    .init(adsName: "SUZY.ADS", adsTag: 2, spotStart: 0, hdgStart: 0, spotEnd: 0, hdgEnd: 0, dayNo: 9, flags: [.final, .first]),

    .init(adsName: "VISITOR.ADS", adsTag: 1, spotStart: A, hdgStart: S, spotEnd: A, hdgEnd: S, dayNo: 0, flags: [.island, .lowTideOK]),
    .init(adsName: "VISITOR.ADS", adsTag: 3, spotStart: B, hdgStart: NW, spotEnd: D, hdgEnd: 0, dayNo: 0, flags: [.island, .final, .holidayNOK]),
    .init(adsName: "VISITOR.ADS", adsTag: 4, spotStart: D, hdgStart: S, spotEnd: D, hdgEnd: W, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "VISITOR.ADS", adsTag: 6, spotStart: D, hdgStart: S, spotEnd: D, hdgEnd: SW, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "VISITOR.ADS", adsTag: 7, spotStart: D, hdgStart: S, spotEnd: D, hdgEnd: SW, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
    .init(adsName: "VISITOR.ADS", adsTag: 5, spotStart: E, hdgStart: SW, spotEnd: 0, hdgEnd: 0, dayNo: 0, flags: [.island, .final, .leftIsland, .varPosOK, .lowTideOK]),

    .init(adsName: "WALKSTUF.ADS", adsTag: 1, spotStart: A, hdgStart: NE, spotEnd: 0, hdgEnd: 0, dayNo: 0, flags: [.island, .final, .lowTideOK]),
    .init(adsName: "WALKSTUF.ADS", adsTag: 2, spotStart: E, hdgStart: EH, spotEnd: D, hdgEnd: SE, dayNo: 0, flags: [.island, .varPosOK]),
    .init(adsName: "WALKSTUF.ADS", adsTag: 3, spotStart: D, hdgStart: W, spotEnd: E, hdgEnd: W, dayNo: 0, flags: [.island, .varPosOK, .lowTideOK]),
]

extension Engine {

    func storyPickScene(wanted: SceneFlags, unwanted: SceneFlags) -> StoryScene {
        let candidates = storyScenes.filter { scene in
            scene.flags.isSuperset(of: wanted)
                && scene.flags.isDisjoint(with: unwanted)
                && (scene.dayNo == 0 || scene.dayNo == storyCurrentDay)
        }
        return candidates[rng.next(upperBound: candidates.count)]
    }

    func storyUpdateCurrentDay() {
        let calendar = Calendar.current
        let today = calendar.ordinality(of: .day, in: .year, for: dateProvider()) ?? 1
        var day = storyStore.currentDay
        var hasChanged = false

        if today != storyStore.lastDate {
            storyStore.lastDate = today
            day += 1
            hasChanged = true
        }

        if day < 1 || day > 11 {
            day = 1
            hasChanged = true
        }

        if hasChanged {
            storyStore.currentDay = day
        }

        storyCurrentDay = day
    }

    func storyCalculateIslandFromDateAndTime() {
        let calendar = Calendar.current
        let now = dateProvider()

        // Night for one hour out of every eight, like the original.
        let hour = calendar.component(.hour, from: now) % 8
        islandState.night = (hour == 0 || hour == 7)

        // Holidays
        islandState.holiday = 0
        let month = calendar.component(.month, from: now)
        let day = calendar.component(.day, from: now)
        let monthDay = month * 100 + day

        if monthDay > 1028 && monthDay < 1101 {
            islandState.holiday = 1  // Halloween: Oct 29-31
        } else if monthDay > 314 && monthDay < 318 {
            islandState.holiday = 2  // St Patrick: Mar 15-17
        } else if monthDay > 1222 && monthDay < 1226 {
            islandState.holiday = 3  // Christmas: Dec 23-25
        } else if monthDay > 1228 || monthDay < 102 {
            islandState.holiday = 4  // New Year: Dec 29 - Jan 1
        }
    }

    func storyCalculateIsland(from scene: StoryScene) {
        // Low tide?
        islandState.lowTide =
            scene.flags.contains(.lowTideOK) && rng.next(upperBound: 2) != 0

        // Randomize the island's position.
        if scene.flags.contains(.varPosOK) {
            if rng.next(upperBound: 2) != 0 {
                islandState.xPos = -222 + rng.next(upperBound: 109)
                islandState.yPos = -44 + rng.next(upperBound: 128)
            } else if rng.next(upperBound: 2) != 0 {
                islandState.xPos = -114 + rng.next(upperBound: 134)
                islandState.yPos = -14 + rng.next(upperBound: 99)
            } else {
                islandState.xPos = -114 + rng.next(upperBound: 119)
                islandState.yPos = -73 + rng.next(upperBound: 60)
            }
        } else if scene.flags.contains(.leftIsland) {
            islandState.xPos = -272
            islandState.yPos = 0
        } else {
            islandState.xPos = 0
            islandState.yPos = 0
        }

        // How much of the raft has Johnny built?
        if scene.flags.contains(.noRaft) {
            islandState.raft = 0
        } else {
            switch storyCurrentDay {
            case 0, 1, 2: islandState.raft = 1
            case 3, 4, 5: islandState.raft = storyCurrentDay - 1
            default: islandState.raft = 5
            }
        }

        // The cargo-ship scene fills the screen; holiday items would be
        // drawn over the hull (matches the original's behavior).
        if scene.flags.contains(.holidayNOK) {
            islandState.holiday = 0
        }
    }

    /// Port of storyPlay: the top-level screensaver loop. Runs until the
    /// Clock cancels the engine. `skipIntro` skips the title card (used
    /// when the host restarts the engine, e.g. the demo app's day-skip).
    public func storyPlay(skipIntro: Bool = false) throws {
        adsInit()
        if !skipIntro {
            try adsPlayIntro()
        }

        while true {
            storyUpdateCurrentDay()
            storyCalculateIslandFromDateAndTime()

            var wantedFlags: SceneFlags = []
            var unwantedFlags: SceneFlags = []

            let finalScene = storyPickScene(wanted: .final, unwanted: unwantedFlags)

            if finalScene.flags.contains(.island) {
                storyCalculateIsland(from: finalScene)
                try adsInitIsland()
            } else {
                adsNoIsland()
            }

            var prevSpot = -1
            var prevHdg = -1

            if !finalScene.flags.contains(.first) {

                wantedFlags = []
                unwantedFlags.insert(.final)

                if islandState.lowTide {
                    wantedFlags.insert(.lowTideOK)
                }
                if islandState.xPos != 0 || islandState.yPos != 0 {
                    wantedFlags.insert(.varPosOK)
                }

                let count = 6 + rng.next(upperBound: 14)
                for _ in 0..<count {
                    let scene = storyPickScene(wanted: wantedFlags, unwanted: unwantedFlags)

                    if prevSpot != -1 {
                        try adsPlayWalk(
                            fromSpot: prevSpot, fromHdg: prevHdg,
                            toSpot: scene.spotStart, toHdg: scene.hdgStart)
                    }

                    ttmDx = islandState.xPos + (scene.flags.contains(.leftIsland) ? 272 : 0)
                    ttmDy = islandState.yPos

                    if scene.dayNo != 0 {
                        sound?.play(0)
                    }

                    try adsPlay(scene.adsName, scene.adsTag)

                    unwantedFlags.insert(.first)
                    prevSpot = scene.spotEnd
                    prevHdg = scene.hdgEnd
                }
            }

            if prevSpot != -1 {
                try adsPlayWalk(
                    fromSpot: prevSpot, fromHdg: prevHdg,
                    toSpot: finalScene.spotStart, toHdg: finalScene.hdgStart)
            }

            if finalScene.flags.contains(.island) {
                ttmDx = islandState.xPos + (finalScene.flags.contains(.leftIsland) ? 272 : 0)
                ttmDy = islandState.yPos
            } else {
                ttmDx = 0
                ttmDy = 0
            }

            if finalScene.dayNo != 0 {
                sound?.play(0)
            }

            try adsPlay(finalScene.adsName, finalScene.adsTag)

            try grFadeOut()

            if finalScene.flags.contains(.island) {
                adsReleaseIsland()
            }
        }
    }
}
