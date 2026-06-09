//
//  Johnny Castaway for macOS
//
//  Engine logic ported from 'Johnny Reborn' (jc_reborn) ads.c,
//  Copyright (C) 2019 Jeremie GUILLAUME — GPL-3.0-or-later.
//  Swift port Copyright (C) 2026 the johnny-castaway-mac contributors.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//

import Foundation

extension Engine {

    // MARK: - ADS loading (port of adsLoad)

    /// Scans ADS bytecode, recording every tag offset and — for the tag
    /// being played — the IF_LASTPLAYED / leading IF_NOT_RUNNING chunks
    /// that get (re)triggered when one of their scenes finishes.
    /// Returns the offset of `tag` (0 if not found, like the reference).
    func adsLoad(_ data: [UInt8], tag: UInt16) -> Int {
        var offset = 0
        var tagOffset = 0
        var bookmarkingChunks = false
        var bookmarkingIfNotRunnings = false

        adsChunks = []
        adsChunksLocal = []
        adsTags = []

        func u16() -> UInt16 {
            let v = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            offset += 2
            return v
        }

        while offset < data.count {
            let opcode = u16()

            switch opcode {

            case 0x1350:  // IF_LASTPLAYED
                if bookmarkingChunks {
                    bookmarkingIfNotRunnings = false
                    let slot = u16()
                    let sceneTag = u16()
                    adsChunks.append(AdsChunk(slot: slot, tag: sceneTag, offset: offset))
                } else {
                    offset += 2 << 1
                }

            case 0x1360:  // IF_NOT_RUNNING
                // Only those preceding the first IF_LASTPLAYED/IF_IS_RUNNING.
                if bookmarkingChunks && bookmarkingIfNotRunnings {
                    let slot = u16()
                    let sceneTag = u16()
                    adsChunks.append(AdsChunk(slot: slot, tag: sceneTag, offset: offset))
                } else {
                    offset += 2 << 1
                }

            case 0x1370:  // IF_IS_RUNNING
                bookmarkingIfNotRunnings = false
                offset += 2 << 1

            case 0x1070: offset += 2 << 1
            case 0x1330: offset += 2 << 1
            case 0x1420: break
            case 0x1430: break
            case 0x1510: break
            case 0x1520: offset += 5 << 1
            case 0x2005: offset += 4 << 1
            case 0x2010: offset += 3 << 1
            case 0x2014: break
            case 0x3010: break
            case 0x3020: offset += 1 << 1
            case 0x30FF: break
            case 0x4000: offset += 3 << 1
            case 0xF010: break
            case 0xF200: offset += 1 << 1
            case 0xFFFF: break
            case 0xFFF0: break

            default:  // a tag id embedded in the stream
                adsTags.append((id: opcode, offset: offset))
                if opcode == tag {
                    tagOffset = offset
                    bookmarkingChunks = true
                    bookmarkingIfNotRunnings = true
                } else {
                    bookmarkingChunks = false
                    bookmarkingIfNotRunnings = false
                }
            }
        }

        return tagOffset
    }

    func adsFindTag(_ id: UInt16) -> Int {
        for tag in adsTags where tag.id == id {
            return tag.offset
        }
        return 0
    }

    // MARK: - Thread/scene management

    /// Port of adsAddScene. `arg3` semantics: negative = scene timer in
    /// ticks; positive = number of plays.
    func adsAddScene(_ ttmSlotNo: UInt16, _ ttmTag: UInt16, _ arg3: UInt16) {
        for thread in ttmThreads where thread.isRunning == 1 {
            if thread.sceneSlot == ttmSlotNo && thread.sceneTag == ttmTag {
                return  // already running — don't add a duplicate
            }
        }

        guard let thread = ttmThreads.first(where: { $0.isRunning == 0 }) else {
            return
        }

        thread.slot = ttmSlots[Int(ttmSlotNo)]
        thread.isRunning = 1
        thread.sceneSlot = ttmSlotNo
        thread.sceneTag = ttmTag
        thread.sceneTimer = 0
        thread.sceneIterations = 0
        thread.delay = 4
        thread.timer = 0
        thread.nextGotoOffset = 0
        thread.selectedBmpSlot = 0
        thread.fgColor = 0x0F
        thread.bgColor = 0x0F

        if ttmSlotNo != 0 {
            thread.ip = ttmFindTag(ttmSlots[Int(ttmSlotNo)], ttmTag)
        } else {
            thread.ip = 0
        }

        let signedArg3 = Int(Int16(bitPattern: arg3))
        if signedArg3 < 0 {
            thread.sceneTimer = -signedArg3
        } else if signedArg3 > 0 {
            thread.sceneIterations = signedArg3 - 1
        }

        thread.layer = Layer()
        numThreads += 1
    }

    func adsStopScene(_ thread: TtmThread) {
        thread.layer = nil
        thread.isRunning = 0
        numThreads -= 1
    }

    func adsStopSceneByTtmTag(_ ttmSlotNo: UInt16, _ ttmTag: UInt16) {
        for thread in ttmThreads where thread.isRunning != 0 {
            if thread.sceneSlot == ttmSlotNo && thread.sceneTag == ttmTag {
                adsStopScene(thread)
            }
        }
    }

    func isSceneRunning(_ ttmSlotNo: UInt16, _ ttmTag: UInt16) -> Bool {
        ttmThreads.contains {
            $0.isRunning == 1 && $0.sceneSlot == ttmSlotNo && $0.sceneTag == ttmTag
        }
    }

    // MARK: - Weighted-random blocks (RANDOM_START … RANDOM_END)

    func adsRandomEnd() {
        guard !adsRandOps.isEmpty else { return }

        let totalWeight = adsRandOps.reduce(0) { $0 + $1.weight }
        let a = rng.next(upperBound: totalWeight)

        var partialWeight = 0
        var chosen = adsRandOps[adsRandOps.count - 1]
        for op in adsRandOps {
            partialWeight += op.weight
            if a < partialWeight {
                chosen = op
                break
            }
        }

        switch chosen.kind {
        case .addScene:
            adsAddScene(chosen.slot, chosen.tag, chosen.numPlays)
        case .stopScene:
            adsStopSceneByTtmTag(chosen.slot, chosen.tag)
        case .nop:
            break
        }
    }

    // MARK: - Initialization

    /// Port of adsInit.
    public func adsInit() {
        for slot in ttmSlots {
            ttmResetSlot(slot)
        }
        for thread in ttmThreads {
            thread.isRunning = 0
            thread.timer = 0
            thread.layer = nil
        }
        grUpdateDelay = 0
        backgroundThread.isRunning = 0
        holidayThread.isRunning = 0
        numThreads = 0
        adsStopRequested = false
    }

    /// Port of adsNoIsland: plain black background.
    public func adsNoIsland() {
        grDx = 0
        grDy = 0
        grInitEmptyBackground()
    }

    // MARK: - Chunk interpreter (port of adsPlayChunk)

    func adsPlayChunk(_ data: [UInt8], offset startOffset: Int) {
        var offset = startOffset
        var inRandBlock = false
        var inOrBlock = false
        var inSkipBlock = false
        var inIfLastplayedLocal = false
        var continueLoop = true

        func u16() -> UInt16 {
            let v = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            offset += 2
            return v
        }

        while continueLoop && offset < data.count {
            let opcode = u16()

            switch opcode {

            case 0x1070:  // IF_LASTPLAYED_LOCAL (only ACTIVITY.ADS tag 7)
                let slot = u16()
                let tag = u16()
                inIfLastplayedLocal = true
                adsChunksLocal.append(AdsChunk(slot: slot, tag: tag, offset: offset))

            case 0x1330:  // IF_UNKNOWN_1 — behaves fine ignored
                _ = u16()
                _ = u16()

            case 0x1350:  // IF_LASTPLAYED — ends this chunk unless OR-chained
                _ = u16()
                _ = u16()
                if !inOrBlock {
                    continueLoop = false
                }
                inOrBlock = false

            case 0x1360:  // IF_NOT_RUNNING
                let slot = u16()
                let tag = u16()
                if isSceneRunning(slot, tag) {
                    inSkipBlock = true
                }

            case 0x1370:  // IF_IS_RUNNING
                let slot = u16()
                let tag = u16()
                inSkipBlock = !isSceneRunning(slot, tag)

            case 0x1420:  // AND
                break

            case 0x1430:  // OR
                inOrBlock = true

            case 0x1510:  // PLAY_SCENE — closing brace of a block
                if inSkipBlock {
                    inSkipBlock = false
                } else {
                    continueLoop = false
                }

            case 0x1520:  // ADD_SCENE_LOCAL (only ACTIVITY.ADS tag 7)
                _ = u16()
                let slot = u16()
                let tag = u16()
                let numPlays = u16()
                _ = u16()
                if inIfLastplayedLocal {
                    // First pass: queued by IF_LASTPLAYED_LOCAL above.
                    inIfLastplayedLocal = false
                } else {
                    // Second pass (triggered): actually launch it.
                    adsAddScene(slot, tag, numPlays)
                }

            case 0x2005:  // ADD_SCENE
                let slot = u16()
                let tag = u16()
                let arg3 = u16()
                let weight = u16()
                if !inSkipBlock {
                    if inRandBlock {
                        adsRandOps.append(RandOp(
                            kind: .addScene, slot: slot, tag: tag,
                            numPlays: arg3, weight: Int(weight)))
                    } else {
                        adsAddScene(slot, tag, arg3)
                    }
                }

            case 0x2010:  // STOP_SCENE
                let slot = u16()
                let tag = u16()
                let weight = u16()
                if !inSkipBlock {
                    if inRandBlock {
                        adsRandOps.append(RandOp(
                            kind: .stopScene, slot: slot, tag: tag,
                            numPlays: 0, weight: Int(weight)))
                    } else {
                        adsStopSceneByTtmTag(slot, tag)
                    }
                }

            case 0x3010:  // RANDOM_START
                adsRandOps = []
                inRandBlock = true

            case 0x3020:  // NOP (weighted no-op inside random blocks)
                let weight = u16()
                if inRandBlock {
                    adsRandOps.append(RandOp(
                        kind: .nop, slot: 0, tag: 0, numPlays: 0, weight: Int(weight)))
                }

            case 0x30FF:  // RANDOM_END — pick one weighted op and run it
                adsRandomEnd()
                inRandBlock = false

            case 0x4000:  // UNKNOWN_6 (only BUILDING.ADS tag 7)
                _ = u16()
                _ = u16()
                _ = u16()

            case 0xF010:  // FADE_OUT (handled at story level)
                break

            case 0xF200:  // GOSUB_TAG (only STAND.ADS → tag 14)
                let tag = u16()
                adsPlayChunk(data, offset: adsFindTag(tag))

            case 0xFFFF:  // END
                if inSkipBlock {
                    inSkipBlock = false
                } else {
                    adsStopRequested = true
                }

            case 0xFFF0:  // END_IF
                break

            default:  // a tag id — chunk boundary marker
                break
            }
        }
    }

    /// Port of adsPlayTriggeredChunks: when a scene finishes, replay any
    /// chunk whose IF_LASTPLAYED (or queued local trigger) matches it.
    func adsPlayTriggeredChunks(_ data: [UInt8], _ ttmSlotNo: UInt16, _ ttmTag: UInt16) {
        if !adsChunksLocal.isEmpty {
            // At most one local chunk ever exists (ACTIVITY.ADS tag 7).
            let pending = adsChunksLocal
            for chunk in pending where chunk.slot == ttmSlotNo && chunk.tag == ttmTag {
                adsPlayChunk(data, offset: chunk.offset)
                if !adsChunksLocal.isEmpty {
                    adsChunksLocal.removeLast()
                }
            }
        } else {
            // Some scripts (e.g. BUILDING.ADS tag 2) have several
            // IF_LASTPLAYED chunks for the same scene.
            for chunk in adsChunks where chunk.slot == ttmSlotNo && chunk.tag == ttmTag {
                adsPlayChunk(data, offset: chunk.offset)
            }
        }
    }

    // MARK: - Top-level playback

    /// Port of adsPlay: run one ADS scene (an ADS resource + entry tag)
    /// to completion.
    public func adsPlay(_ adsName: String, _ adsTag: UInt16) throws {
        let resource = try library.ads(adsName)
        let data = resource.data

        for res in resource.res {
            try ttmLoadTtm(ttmSlots[Int(res.id)], res.name)
        }

        let offset = adsLoad(data, tag: adsTag)

        adsStopRequested = false
        grUpdateDelay = 0

        // Play the first chunk of the sequence.
        adsPlayChunk(data, offset: offset)

        // Main scheduler loop.
        while numThreads > 0 {

            if backgroundThread.isRunning != 0 && backgroundThread.timer == 0 {
                backgroundThread.timer = backgroundThread.delay
                try islandAnimate()
            }

            for thread in ttmThreads where thread.isRunning != 0 && thread.timer == 0 {
                thread.timer = thread.delay
                try ttmPlay(thread)
            }

            try grUpdateDisplay()

            // Min timer across all running threads.
            var mini = 300
            if backgroundThread.isRunning != 0 {
                mini = backgroundThread.timer
            }
            for thread in ttmThreads where thread.isRunning != 0 {
                mini = min(mini, thread.delay, thread.timer)
            }

            backgroundThread.timer -= mini
            for thread in ttmThreads where thread.isRunning != 0 {
                thread.timer -= mini
            }

            grUpdateDelay = mini

            // Post-frame thread bookkeeping.
            for thread in ttmThreads where thread.isRunning != 0 && thread.timer == 0 {

                if thread.nextGotoOffset != 0 {
                    thread.ip = thread.nextGotoOffset
                    thread.nextGotoOffset = 0
                }

                if thread.sceneTimer > 0 {
                    thread.sceneTimer -= thread.delay
                    if thread.sceneTimer <= 0 {
                        thread.isRunning = 2
                    }
                }

                if thread.isRunning == 2 {
                    if thread.sceneIterations != 0 {
                        thread.sceneIterations -= 1
                        thread.isRunning = 1
                        thread.ip = ttmFindTag(ttmSlots[Int(thread.sceneSlot)], thread.sceneTag)
                    } else {
                        adsStopScene(thread)
                        if !adsStopRequested {
                            adsPlayTriggeredChunks(data, thread.sceneSlot, thread.sceneTag)
                        }
                    }
                }
            }
        }

        for slot in ttmSlots {
            ttmResetSlot(slot)
        }
        grRestoreZone()
    }

    /// Port of adsPlaySingleTtm: play one TTM script straight through.
    public func playSingleTtm(_ ttmName: String) throws {
        adsInit()
        try ttmLoadTtm(ttmSlots[0], ttmName)
        adsAddScene(0, 0, 0)
        let thread = ttmThreads[0]
        thread.ip = 0

        while thread.ip < ttmSlots[0].dataSize {
            try ttmPlay(thread)
            thread.isRunning = 1
            try grUpdateDisplay()
            grUpdateDelay = thread.delay
        }

        adsStopScene(thread)
        ttmResetSlot(ttmSlots[0])
    }
}
