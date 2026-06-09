//
//  Johnny Castaway for macOS
//
//  Engine logic ported from 'Johnny Reborn' (jc_reborn) island.c and the
//  island/walk entry points of ads.c, Copyright (C) 2019 Jeremie
//  GUILLAUME — GPL-3.0-or-later.
//  Swift port Copyright (C) 2026 the johnny-castaway-mac contributors.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//

import Foundation

public struct IslandState {
    public var lowTide = false
    public var night = false
    public var raft = 0      // 0…5 — build stage
    public var holiday = 0   // 0 none, 1 Halloween, 2 St Patrick, 3 Christmas, 4 New Year
    public var xPos = 0
    public var yPos = 0

    // The wave-animation counters (statics in the C islandAnimate).
    var waveCounter1 = 0
    var waveCounter2 = 0
}

extension Engine {

    /// Port of islandInit: build the island background (ocean screen,
    /// raft stage, clouds, island, palm, tide sprites) and start the
    /// shore-wave animation thread.
    func islandInit() throws {
        let slot = backgroundSlot

        if islandState.night {
            try grLoadScreen("NIGHT.SCR")
        } else {
            try grLoadScreen("OCEAN0\(rng.next(upperBound: 3)).SCR")
        }

        // The background thread draws directly into the background.
        backgroundThread.slot = slot
        backgroundThread.layer = background

        grDx = islandState.xPos
        grDy = islandState.yPos

        // Raft
        grLoadBmp(slot, 0, "MRAFT.BMP")

        let xRaft = islandState.lowTide ? 529 : 512
        let yRaft = islandState.lowTide ? 281 : 266

        if (1...5).contains(islandState.raft) {
            grDrawSprite(background!, slot, xRaft, yRaft, islandState.raft - 1, 0)
        }

        grLoadBmp(slot, 0, "BACKGRND.BMP")

        // Clouds
        let windDirection = rng.next(upperBound: 2)
        var numClouds = 0

        if rng.next(upperBound: 2) != 0 {
            numClouds = 1
        } else if rng.next(upperBound: 2) != 0 {
            numClouds = 0
        } else if rng.next(upperBound: 4) != 0 {
            numClouds = 2
        } else if rng.next(upperBound: 4) != 0 {
            numClouds = 3
        } else if rng.next(upperBound: 4) != 0 {
            numClouds = 4
        } else {
            numClouds = 5
        }

        grDx = 0
        grDy = 0

        for _ in 0..<numClouds {
            let cloudNo = rng.next(upperBound: 3)
            let cloudX: Int
            let cloudY: Int

            switch cloudNo {
            case 0:
                cloudX = rng.next(upperBound: 640 - 129)
                cloudY = rng.next(upperBound: 135 - 36)
            case 1:
                cloudX = rng.next(upperBound: 640 - 192)
                cloudY = rng.next(upperBound: 135 - 57)
            default:
                cloudX = rng.next(upperBound: 640 - 264)
                cloudY = rng.next(upperBound: 135 - 76)
            }

            grDrawSprite(
                background!, slot, cloudX, cloudY, 15 + cloudNo, 0,
                flipped: windDirection == 0)
        }

        grDx = islandState.xPos
        grDy = islandState.yPos

        // The island itself
        grDrawSprite(background!, slot, 288, 279, 0, 0)    // island
        grDrawSprite(background!, slot, 442, 148, 13, 0)   // trunk
        grDrawSprite(background!, slot, 365, 122, 12, 0)   // leafs
        grDrawSprite(background!, slot, 396, 279, 14, 0)   // palmtree's shadow

        if islandState.lowTide {
            grDrawSprite(background!, slot, 249, 303, 1, 0)   // low tide shore
            grDrawSprite(background!, slot, 150, 328, 2, 0)   // rock
        }

        // Initial waves on the shore
        islandState.waveCounter1 = 0
        islandState.waveCounter2 = 0
        for _ in 0..<4 {
            try islandAnimate()
        }

        // Waves animation cadence
        backgroundThread.delay = 8
        backgroundThread.timer = 8
    }

    /// Port of islandAnimate: advance the shore-wave sprites by one step,
    /// drawing into the background.
    func islandAnimate() throws {
        guard let background else { return }
        let slot = backgroundSlot

        grDx = islandState.xPos
        grDy = islandState.yPos

        if islandState.lowTide {
            islandState.waveCounter2 = (islandState.waveCounter2 + 1) % 4
            switch islandState.waveCounter2 {
            case 0: grDrawSprite(background, slot, 129, 340, 39 + islandState.waveCounter1, 0)
            case 1: grDrawSprite(background, slot, 233, 323, 30 + islandState.waveCounter1, 0)
            case 2: grDrawSprite(background, slot, 367, 356, 33 + islandState.waveCounter1, 0)
            default: grDrawSprite(background, slot, 558, 323, 36 + islandState.waveCounter1, 0)
            }
        } else {
            islandState.waveCounter2 = (islandState.waveCounter2 + 1) % 3
            switch islandState.waveCounter2 {
            case 0: grDrawSprite(background, slot, 270, 306, 3 + islandState.waveCounter1, 0)
            case 1: grDrawSprite(background, slot, 364, 319, 6 + islandState.waveCounter1, 0)
            default: grDrawSprite(background, slot, 518, 303, 9 + islandState.waveCounter1, 0)
            }
        }

        if islandState.waveCounter2 == 0 {
            islandState.waveCounter1 = (islandState.waveCounter1 + 1) % 3
        }
    }

    /// Port of islandInitHoliday: seasonal decoration on its own layer.
    func islandInitHoliday() {
        let slot = holidaySlot

        if islandState.holiday != 0 {
            holidayThread.slot = slot
            holidayThread.layer = Layer()
            holidayThread.isRunning = 3

            grDx = islandState.xPos
            grDy = islandState.yPos

            grLoadBmp(slot, 0, "HOLIDAY.BMP")

            switch islandState.holiday {
            case 1: grDrawSprite(holidayThread.layer!, slot, 410, 298, 0, 0)  // Halloween
            case 2: grDrawSprite(holidayThread.layer!, slot, 333, 286, 1, 0)  // St Patrick
            case 3: grDrawSprite(holidayThread.layer!, slot, 404, 267, 2, 0)  // Christmas
            default: grDrawSprite(holidayThread.layer!, slot, 361, 155, 3, 0)  // New Year
            }

            slot.sprites[0] = []
        } else {
            holidayThread.isRunning = 0
        }
    }

    // MARK: - ads.c island/walk entry points

    /// Port of adsInitIsland.
    public func adsInitIsland() throws {
        ttmResetSlot(backgroundSlot)
        backgroundThread.slot = backgroundSlot
        backgroundThread.isRunning = 3
        backgroundThread.delay = 40
        backgroundThread.timer = 0

        try islandInit()

        ttmResetSlot(holidaySlot)
        holidayThread.slot = holidaySlot
        holidayThread.isRunning = 0
        holidayThread.delay = 0
        holidayThread.timer = 0

        islandInitHoliday()
    }

    /// Port of adsReleaseIsland.
    public func adsReleaseIsland() {
        backgroundThread.isRunning = 0
        ttmResetSlot(backgroundSlot)

        if holidayThread.isRunning != 0 {
            holidayThread.isRunning = 0
            holidayThread.layer = nil
        }
    }

    /// Port of adsPlayIntro: the Sierra "Screen Antics" title card.
    public func adsPlayIntro() throws {
        try grLoadScreen("INTRO.SCR")
        grUpdateDelay = 100
        try grUpdateDisplay()
        try grFadeOut()
        ttmResetSlot(ttmSlots[0])
    }

    /// Port of adsPlayWalk: walk Johnny from one island spot to another
    /// between scenes.
    func adsPlayWalk(fromSpot: Int, fromHdg: Int, toSpot: Int, toHdg: Int) throws {
        adsAddScene(0, 0, 0)
        grLoadBmp(ttmSlots[0], 0, "JOHNWALK.BMP")

        grDx = islandState.xPos
        grDy = islandState.yPos

        let thread = ttmThreads[0]
        thread.timer = 6
        thread.delay = 6

        walkInit(fromSpot: fromSpot, fromHdg: fromHdg, toSpot: toSpot, toHdg: toHdg)

        thread.delay = walkAnimate(thread, backgroundSlot: backgroundSlot)

        while thread.delay != 0 {

            if backgroundThread.timer == 0 {
                backgroundThread.timer = backgroundThread.delay
                try islandAnimate()
            }

            if thread.timer == 0 {
                thread.delay = walkAnimate(thread, backgroundSlot: backgroundSlot)
                thread.timer = thread.delay
            }

            try grUpdateDisplay()

            var mini: Int
            if backgroundThread.timer < thread.timer {
                mini = backgroundThread.timer
            } else {
                mini = thread.timer
            }

            backgroundThread.timer -= mini
            thread.timer -= mini

            grUpdateDelay = mini
        }

        adsStopScene(thread)
    }
}
