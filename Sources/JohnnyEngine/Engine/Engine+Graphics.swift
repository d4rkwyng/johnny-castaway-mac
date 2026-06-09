//
//  Johnny Castaway for macOS
//
//  Engine logic ported from 'Johnny Reborn' (jc_reborn) graphics.c,
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

    // MARK: - Display composition (port of grUpdateDisplay)

    /// Composites background + saved zones + thread layers + holiday
    /// layer, waits for the current update delay, then presents.
    func grUpdateDisplay() throws {
        var frame: [Pixel]
        if let background {
            frame = background.pixels
        } else {
            frame = [Pixel](repeating: makePixel(r: 0, g: 0, b: 0), count: Layer.width * Layer.height)
        }

        compositeOnto(&frame, savedZonesLayer)

        for thread in ttmThreads where thread.isRunning != 0 {
            compositeOnto(&frame, thread.layer)
        }

        if holidayThread.isRunning != 0 {
            compositeOnto(&frame, holidayThread.layer)
        }

        try clock.waitTicks(grUpdateDelay)
        presenter?.present(frame)
    }

    private func compositeOnto(_ frame: inout [Pixel], _ layer: Layer?) {
        guard let layer else { return }
        let count = frame.count
        frame.withUnsafeMutableBufferPointer { dst in
            layer.pixels.withUnsafeBufferPointer { src in
                for i in 0..<count {
                    let p = src[i]
                    if p != colorKeyPixel {
                        dst[i] = p
                    }
                }
            }
        }
    }

    // MARK: - Background screens

    /// Port of grLoadScreen.
    func grLoadScreen(_ name: String) throws {
        savedZonesLayer = nil
        let scr = try library.scr(name)
        background = PixelDecoder.decodeScreen(scr, palette: palette)
    }

    /// Port of grInitEmptyBackground.
    func grInitEmptyBackground() {
        savedZonesLayer = nil
        background = Layer(filledWith: makePixel(r: 0, g: 0, b: 0))
    }

    // MARK: - Layer helpers with the engine's draw offset (grDx/grDy)

    func grSetClipZone(_ layer: Layer, _ x1: Int, _ y1: Int, _ x2: Int, _ y2: Int) {
        let ax1 = x1 + grDx
        let ay1 = y1 + grDy
        let ax2 = x2 + grDx
        let ay2 = y2 + grDy
        layer.clip = ClipRect(x: ax1, y: ay1, width: ax2 - ax1, height: ay2 - ay1)
    }

    /// Port of grCopyZoneToBg — copies a zone of a thread layer onto the
    /// persistent saved-zones layer. The +2 width compensates a known
    /// coordinate bug in GJVIS6.TTM (cargo-ship hull glitch).
    func grCopyZoneToBg(_ layer: Layer, _ x: Int, _ y: Int, _ width: Int, _ height: Int) {
        if savedZonesLayer == nil {
            savedZonesLayer = Layer()
        }
        savedZonesLayer!.blitZone(
            from: layer, x: x + grDx, y: y + grDy, width: width + 2, height: height)
    }

    /// Port of grRestoreZone: in Johnny's scripts RESTORE_ZONE is never
    /// called with multiple zones saved, so dropping the whole layer
    /// is equivalent.
    func grRestoreZone() {
        savedZonesLayer = nil
    }

    func grDrawPixel(_ layer: Layer, _ x: Int, _ y: Int, _ color: UInt8) {
        layer.putPixel(x + grDx, y + grDy, palette[color])
    }

    func grDrawLine(_ layer: Layer, _ x1: Int, _ y1: Int, _ x2: Int, _ y2: Int, _ color: UInt8) {
        layer.drawLine(
            x1: x1 + grDx, y1: y1 + grDy, x2: x2 + grDx, y2: y2 + grDy,
            pixel: palette[color])
    }

    func grDrawRect(_ layer: Layer, _ x: Int, _ y: Int, _ width: Int, _ height: Int, _ color: UInt8) {
        layer.fillRect(x: x + grDx, y: y + grDy, width: width, height: height, pixel: palette[color])
    }

    func grDrawCircle(
        _ layer: Layer, _ x1: Int, _ y1: Int, _ width: Int, _ height: Int,
        _ fgColor: UInt8, _ bgColor: UInt8
    ) {
        layer.drawCircle(
            x1: x1 + grDx, y1: y1 + grDy, width: width, height: height,
            fg: palette[fgColor], bg: palette[bgColor])
    }

    func grDrawSprite(
        _ layer: Layer, _ slot: TtmSlot, _ x: Int, _ y: Int, _ spriteNo: Int, _ imageNo: Int,
        flipped: Bool = false
    ) {
        guard imageNo < maxBmpSlots, spriteNo < slot.sprites[imageNo].count else {
            return  // mirror of the reference's warning-and-skip
        }
        let sprite = slot.sprites[imageNo][spriteNo]
        layer.blit(sprite, x: x + grDx, y: y + grDy, flipped: flipped)
    }

    /// Port of grLoadBmp: decode a sprite sheet into a BMP slot.
    /// Unlike the reference (which fatalError()s), a missing sheet just
    /// empties the slot — the original data contains a few dangling
    /// references (e.g. FLAME.BMP) in scenes the story never reaches,
    /// and a screensaver must never die on them.
    func grLoadBmp(_ slot: TtmSlot, _ slotNo: Int, _ name: String) {
        guard let bmp = try? library.bmp(name) else {
            slot.sprites[slotNo] = []
            return
        }
        slot.sprites[slotNo] = PixelDecoder.decodeSprites(bmp, palette: palette)
    }

    // MARK: - Fade out (port of grFadeOut)

    /// The five fade-out styles, cycled in order. Operates on the
    /// presented frame (the original drew directly to the window).
    func grFadeOut() throws {
        grDx = 0
        grDy = 0

        // Start from the currently displayed content.
        var frame: [Pixel]
        if let background {
            frame = background.pixels
        } else {
            frame = [Pixel](repeating: makePixel(r: 0, g: 0, b: 0), count: Layer.width * Layer.height)
        }
        compositeOnto(&frame, savedZonesLayer)
        for thread in ttmThreads where thread.isRunning != 0 {
            compositeOnto(&frame, thread.layer)
        }
        if holidayThread.isRunning != 0 {
            compositeOnto(&frame, holidayThread.layer)
        }

        let work = Layer()
        work.pixels = frame
        let color5 = palette[5]

        switch fadeOutType {
        case 0:  // Circle from center
            let tmp = Layer()
            for radius in stride(from: 20, through: 400, by: 20) {
                tmp.drawCircle(
                    x1: 320 - radius, y1: 240 - radius,
                    width: radius << 1, height: radius << 1,
                    fg: color5, bg: color5)
                work.composite(tmp)
                try clock.waitTicks(1)
                presenter?.present(work.pixels)
            }

        case 1:  // Rectangle from center
            for i in 1...20 {
                work.fillRect(
                    x: 320 - i * 16, y: 240 - i * 12,
                    width: i * 32, height: i * 24, pixel: color5)
                try clock.waitTicks(1)
                presenter?.present(work.pixels)
            }

        case 2:  // Right to left
            for i in stride(from: 600, through: 0, by: -40) {
                work.fillRect(x: i, y: 0, width: 40, height: 480, pixel: color5)
                try clock.waitTicks(1)
                presenter?.present(work.pixels)
            }

        case 3:  // Left to right
            for i in stride(from: 0, to: 640, by: 40) {
                work.fillRect(x: i, y: 0, width: 40, height: 480, pixel: color5)
                try clock.waitTicks(1)
                presenter?.present(work.pixels)
            }

        default:  // Middle to left and right
            for i in stride(from: 0, to: 320, by: 20) {
                work.fillRect(x: 320 + i, y: 0, width: 20, height: 480, pixel: color5)
                work.fillRect(x: 300 - i, y: 0, width: 20, height: 480, pixel: color5)
                try clock.waitTicks(1)
                presenter?.present(work.pixels)
            }
        }

        fadeOutType = (fadeOutType + 1) % 5
    }
}
