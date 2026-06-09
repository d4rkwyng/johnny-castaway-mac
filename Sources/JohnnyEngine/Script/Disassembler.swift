//
//  Johnny Castaway for macOS
//
//  Engine logic ported from 'Johnny Reborn' (jc_reborn) dump.c,
//  Copyright (C) 2019 Jeremie GUILLAUME — GPL-3.0-or-later.
//  Swift port Copyright (C) 2026 the johnny-castaway-mac contributors.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//

import Foundation

/// TTM/ADS bytecode disassembler. Output format byte-identical to
/// jc_reborn's `dump` command, so the two can be diffed directly.
public enum Disassembler {

    /// TTM opcodes: low nibble = argument count; 0xF = NUL-terminated
    /// string argument padded to even length.
    public static func disassemble(_ ttm: TtmResource) -> String {
        var out = "\n ======== Tags list ========\n"
        for tag in ttm.tags {
            out += "\(tag.id) : \(tag.text)\n"
        }
        out += "\n\n ======== TTM script ========\n"

        let data = ttm.data
        var offset = 0

        while offset < data.count {
            let opcode = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            offset += 2

            var args = [UInt16]()
            var strArg = ""

            if opcode & 0x000F == 0x000F {
                var chars = [UInt8]()
                while data[offset] != 0 {
                    chars.append(data[offset])
                    offset += 1
                }
                offset += 1  // consume the NUL
                // Strings are stored padded to an even byte count.
                if (chars.count + 1) % 2 == 1 {
                    offset += 1
                }
                strArg = String(decoding: chars, as: UTF8.self)
            } else {
                for _ in 0..<Int(opcode & 0x000F) {
                    args.append(UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8))
                    offset += 2
                }
            }

            switch opcode {
            case 0x001F: out += "SAVE_BACKGROUND \n"
            case 0x0080: out += "DRAW_BACKGROUND\n"
            case 0x0110: out += "PURGE\n"
            case 0x0FF0: out += "UPDATE\n"
            case 0x1021: out += "SET_DELAY \(args[0])\n"
            case 0x1051: out += "SET_BMP_SLOT \(args[0])\n"
            case 0x1061: out += "SET_PALETTE_SLOT \(args[0])\n"
            case 0x1101: out += ":LOCAL_TAG \(args[0])\n"
            case 0x1111: out += "\n:TAG \(args[0])\n"
            case 0x1121: out += "TTM_UNKNOWN_1 \(args[0])\n"
            case 0x1201: out += "GOTO_TAG \(args[0])\n"
            case 0x2002: out += "SET_COLORS \(args[0]) \(args[1])\n"
            case 0x2012: out += "SET_FRAME1 \(args[0]) \(args[1])\n"
            case 0x2022: out += "TIMER \(args[0]) \(args[1])\n"
            case 0x4004: out += "SET_CLIP_ZONE \(args[0]) \(args[1]) \(args[2]) \(args[3])\n"
            case 0x4110: out += "FADE_OUT \n"
            case 0x4120: out += "FADE_IN \n"
            case 0x4204: out += "COPY_ZONE_TO_BG \(args[0]) \(args[1]) \(args[2]) \(args[3])\n"
            case 0x4214: out += "SAVE_IMAGE1 \(args[0]) \(args[1]) \(args[2]) \(args[3])\n"
            case 0xA002: out += "DRAW_PIXEL \(args[0]) \(args[1])\n"
            case 0xA054: out += "SAVE_ZONE \(args[0]) \(args[1]) \(args[2]) \(args[3])\n"
            case 0xA064: out += "RESTORE_ZONE \(args[0]) \(args[1]) \(args[2]) \(args[3])\n"
            case 0xA0A4: out += "DRAW_LINE \(args[0]) \(args[1]) \(args[2]) \(args[3])\n"
            case 0xA104: out += "DRAW_RECT \(args[0]) \(args[1]) \(args[2]) \(args[3])\n"
            case 0xA404: out += "DRAW_CIRCLE \(args[0]) \(args[1]) \(args[2]) \(args[3])\n"
            case 0xA504: out += "DRAW_SPRITE \(args[0]) \(args[1]) \(args[2]) \(args[3])\n"
            case 0xA510: out += "DRAW_SPRITE1 \n"
            case 0xA524: out += "DRAW_SPRITE_FLIP \(args[0]) \(args[1]) \(args[2]) \(args[3])\n"
            case 0xA530: out += "DRAW_SPRITE3 \n"
            case 0xA601: out += "CLEAR_SCREEN \(args[0])\n"
            case 0xB606: out += "DRAW_SCREEN \(args[0]) \(args[1]) \(args[2]) \(args[3]) \(args[4]) \(args[5])\n"
            case 0xC020: out += "LOAD_SAMPLE \n"
            case 0xC030: out += "SELECT_SAMPLE \n"
            case 0xC040: out += "DESELECT_SAMPLE \n"
            case 0xC051: out += "PLAY_SAMPLE \(args[0])\n"
            case 0xC060: out += "STOP_SAMPLE \n"
            case 0xF01F: out += "LOAD_SCREEN \(strArg)\n"
            case 0xF02F: out += "LOAD_IMAGE \(strArg)\n"
            case 0xF05F: out += "LOAD_PALETTE \(strArg)\n"
            default: break  // unknown opcodes are silently skipped, like the reference
            }
        }

        return out
    }

    /// ADS opcodes: fixed per-opcode argument counts; anything unknown
    /// is a tag id embedded in the stream.
    public static func disassemble(_ ads: AdsResource) -> String {
        var out = "\n ======== Resources list ========\n\n"
        for res in ads.res {
            out += "\(res.id) : \(res.name)\n"
        }
        out += "\n\n ======== Tags list ========\n\n"
        for tag in ads.tags {
            out += "\(tag.id) : \(tag.text)\n"
        }
        out += "\n\n ======== ADS script ========\n"

        let data = ads.data
        var offset = 0

        while offset < data.count {
            let opcode = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            offset += 2

            let numArgs: Int
            switch opcode {
            case 0x1070: out += "IF_LASTPLAYED_LOCAL"; numArgs = 2
            case 0x1330: out += "IF_UNKNOWN_1"; numArgs = 2
            case 0x1350: out += "IF_LASTPLAYED"; numArgs = 2
            case 0x1360: out += "IF_NOT_RUNNING"; numArgs = 2
            case 0x1370: out += "IF_IS_RUNNING"; numArgs = 2
            case 0x1420: out += "AND"; numArgs = 0
            case 0x1430: out += "OR"; numArgs = 0
            case 0x1510: out += "PLAY_SCENE"; numArgs = 0
            case 0x1520: out += "ADD_SCENE_LOCAL"; numArgs = 5
            case 0x2005: out += "ADD_SCENE"; numArgs = 4
            case 0x2010: out += "STOP_SCENE"; numArgs = 3
            case 0x2014: out += "UNKNOWN_5"; numArgs = 0
            case 0x3010: out += "RANDOM_START"; numArgs = 0
            case 0x3020: out += "NOP"; numArgs = 1
            case 0x30FF: out += "RANDOM_END"; numArgs = 0
            case 0x4000: out += "UNKNOWN_6"; numArgs = 3
            case 0xF010: out += "FADE_OUT"; numArgs = 0
            case 0xF200: out += "GOSUB_TAG"; numArgs = 1
            case 0xFFFF: out += "END"; numArgs = 0
            case 0xFFF0: out += "END_IF"; numArgs = 0
            default: out += "\n:TAG \(opcode)"; numArgs = 0
            }

            for _ in 0..<numArgs {
                let arg = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
                offset += 2
                out += " \(arg)"
            }
            out += "\n"
        }

        return out
    }
}
