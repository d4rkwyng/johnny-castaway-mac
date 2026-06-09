//
//  Johnny Castaway for macOS
//
//  Engine logic ported from 'Johnny Reborn' (jc_reborn) ttm.c,
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

    /// Offset of the closest tag before `offset` (used by PURGE to loop
    /// a scene segment while its scene timer runs).
    func ttmFindPreviousTag(_ slot: TtmSlot, before offset: Int) -> Int {
        var result = 0
        var i = 0
        while i < slot.tags.count && slot.tags[i].offset < offset {
            result = slot.tags[i].offset
            i += 1
        }
        return result
    }

    /// Offset of tag `id`, or 0 with a warning (reference behavior).
    func ttmFindTag(_ slot: TtmSlot, _ id: UInt16) -> Int {
        for tag in slot.tags where tag.id == id {
            return tag.offset
        }
        return 0
    }

    /// Port of ttmLoadTtm: load a TTM's bytecode into a slot and bookmark
    /// every :TAG / :LOCAL_TAG offset for later jumps.
    func ttmLoadTtm(_ slot: TtmSlot, _ name: String) throws {
        let resource = try library.ttm(name)
        slot.data = resource.data
        slot.tags = []

        let data = resource.data
        var offset = 0

        while offset < data.count {
            let opcode = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            offset += 2

            if opcode == 0x1111 || opcode == 0x1101 {
                let arg = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
                offset += 2
                slot.tags.append((id: arg, offset: offset))
            } else {
                let numArgs = Int(opcode & 0x000F)
                if numArgs == 0x0F {
                    // Skip the even-padded string argument pairwise.
                    while data[offset] != 0 && data[offset + 1] != 0 {
                        offset += 2
                    }
                    offset += 2
                } else {
                    offset += numArgs << 1
                }
            }
        }
    }

    func ttmResetSlot(_ slot: TtmSlot) {
        slot.data = nil
        slot.tags = []
        for i in 0..<maxBmpSlots {
            slot.sprites[i] = []
        }
    }

    /// Port of ttmPlay: execute one thread's bytecode until UPDATE
    /// (yield a frame) or end of script.
    func ttmPlay(_ thread: TtmThread) throws {
        grDx = ttmDx
        grDy = ttmDy

        let slot: TtmSlot = thread.slot
        guard let data = slot.data else { return }
        var offset = thread.ip
        var continueLoop = true

        while continueLoop {
            let opcode = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            offset += 2

            var args = [Int]()
            var strArg = ""

            if opcode & 0x000F == 0x000F {
                var chars = [UInt8]()
                while data[offset] != 0 {
                    chars.append(data[offset])
                    offset += 1
                }
                offset += 1
                if (chars.count + 1) % 2 == 1 {
                    offset += 1
                }
                strArg = String(decoding: chars, as: UTF8.self)
            } else {
                for _ in 0..<Int(opcode & 0x000F) {
                    args.append(Int(UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)))
                    offset += 2
                }
            }

            switch opcode {

            case 0x0080:  // DRAW_BACKGROUND
                break

            case 0x0110:  // PURGE
                if thread.sceneTimer != 0 {
                    thread.nextGotoOffset = ttmFindPreviousTag(slot, before: offset)
                } else {
                    thread.isRunning = 2
                }

            case 0x0FF0:  // UPDATE — yield a frame
                continueLoop = false

            case 0x1021:  // SET_DELAY (minimum 4 ticks)
                thread.delay = max(args[0], 4)
                thread.timer = thread.delay

            case 0x1051:  // SET_BMP_SLOT
                thread.selectedBmpSlot = args[0]

            case 0x1061:  // SET_PALETTE_SLOT
                break

            case 0x1101, 0x1111:  // :LOCAL_TAG, :TAG
                break

            case 0x1121:  // TTM_UNKNOWN_1 (region id for SAVE_IMAGE1)
                break

            case 0x1201:  // GOTO_TAG
                thread.nextGotoOffset = ttmFindTag(slot, UInt16(args[0]))

            case 0x2002:  // SET_COLORS
                thread.fgColor = UInt8(args[0] & 0xFF)
                thread.bgColor = UInt8(args[1] & 0xFF)

            case 0x2012:  // SET_FRAME1 (always 0 0)
                break

            case 0x2022:  // TIMER
                // Same empirical formula as the reference engine.
                thread.delay = (args[0] + args[1]) / 2
                thread.timer = thread.delay

            case 0x4004:  // SET_CLIP_ZONE
                grSetClipZone(thread.layer!, args[0], args[1], args[2], args[3])

            case 0x4204:  // COPY_ZONE_TO_BG
                grCopyZoneToBg(thread.layer!, args[0], args[1], args[2], args[3])

            case 0x4214:  // SAVE_IMAGE1 (no-op, like the reference)
                break

            case 0xA002:  // DRAW_PIXEL
                grDrawPixel(thread.layer!, args[0], args[1], thread.fgColor)

            case 0xA054:  // SAVE_ZONE (only in GJGULIVR.TTM; minimal impl)
                break

            case 0xA064:  // RESTORE_ZONE
                grRestoreZone()

            case 0xA0A4:  // DRAW_LINE
                grDrawLine(thread.layer!, args[0], args[1], args[2], args[3], thread.fgColor)

            case 0xA104:  // DRAW_RECT
                grDrawRect(thread.layer!, args[0], args[1], args[2], args[3], thread.fgColor)

            case 0xA404:  // DRAW_CIRCLE
                grDrawCircle(
                    thread.layer!, args[0], args[1], args[2], args[3],
                    thread.fgColor, thread.bgColor)

            case 0xA504:  // DRAW_SPRITE
                grDrawSprite(thread.layer!, slot, args[0], args[1], args[2], args[3])

            case 0xA524:  // DRAW_SPRITE_FLIP
                grDrawSprite(thread.layer!, slot, args[0], args[1], args[2], args[3], flipped: true)

            case 0xA601:  // CLEAR_SCREEN
                thread.layer!.clearToColorKey()

            case 0xB606:  // DRAW_SCREEN
                break

            case 0xC051:  // PLAY_SAMPLE
                sound?.play(args[0])

            case 0xF01F:  // LOAD_SCREEN
                try grLoadScreen(strArg)

            case 0xF02F:  // LOAD_IMAGE
                grLoadBmp(slot, thread.selectedBmpSlot, strArg)

            case 0xF05F:  // LOAD_PALETTE
                break

            default:
                break
            }

            if offset >= slot.dataSize {
                thread.isRunning = 2
                continueLoop = false
            }
        }

        thread.ip = offset
    }
}
