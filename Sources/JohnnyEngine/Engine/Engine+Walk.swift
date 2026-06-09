//
//  Johnny Castaway for macOS
//
//  Engine logic ported from 'Johnny Reborn' (jc_reborn) walk.c,
//  Copyright (C) 2019 Jeremie GUILLAUME — GPL-3.0-or-later.
//  Swift port Copyright (C) 2026 the johnny-castaway-mac contributors.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//

import Foundation

/// Walking state (the statics of walk.c, instance-scoped).
final class WalkState {
    var path: [Int] = []
    var pathIndex = 0
    var currentSpot = 0
    var currentHdg = 0
    var nextSpot = -1
    var nextHdg = -1
    var finalSpot = 0
    var finalHdg = 0
    var increment = 0
    var lastTurn = false
    var hasArrived = false
    var isBehindTree = false
    var dataIndex = 0
}

extension Engine {

    func walkInit(fromSpot: Int, fromHdg: Int, toSpot: Int, toHdg: Int) {
        let walk = walkState
        walk.path = PathFinder.path(from: fromSpot, to: toSpot, rng: &rng)
        walk.pathIndex = 0

        walk.currentSpot = fromSpot
        walk.currentHdg = fromHdg
        walk.finalSpot = toSpot
        walk.finalHdg = toHdg
        walk.hasArrived = false
        walk.isBehindTree = false

        if walk.currentSpot == walk.finalSpot {
            walk.nextSpot = -1
            walk.nextHdg = walk.finalHdg
            walk.lastTurn = true
        } else {
            walk.pathIndex += 1
            walk.nextSpot = walk.path[walk.pathIndex]
            walk.nextHdg = walkDataStartHeadings[walk.currentSpot][walk.nextSpot]
            walk.lastTurn = false
        }

        walk.increment = (walk.nextHdg - walk.currentHdg) & 0x07
        if walk.increment != 0 {
            walk.increment = walk.increment < 4 ? 1 : -1
        }
    }

    /// One step of the walking animation; returns the next delay in ticks
    /// (6 while walking, 80 on arrival pose, 0 when done).
    func walkAnimate(_ thread: TtmThread, backgroundSlot bgSlot: TtmSlot) -> Int {
        let walk = walkState
        let slot: TtmSlot = thread.slot
        let layer = thread.layer!
        let delay: Int

        if !walk.hasArrived {

            // Are we turning?
            if walk.nextHdg != -1 {

                // More than one iteration left? Yes, so let's turn.
                if (((walk.nextHdg - walk.currentHdg) & 0x07) % 7) > 1 {
                    walk.currentHdg = (walk.currentHdg + walk.increment) & 7
                    walk.dataIndex = walkDataBookmarksTurns[walk.currentSpot] + walk.currentHdg
                    if walk.lastTurn {
                        walk.dataIndex += 9  // hands in pockets
                    }
                }

                // The turn is over.
                else {
                    // Do we have another spot to walk to?
                    if walk.currentSpot != walk.finalSpot {
                        walk.nextHdg = -1
                        walk.isBehindTree =
                            (walk.currentSpot == 3 && walk.nextSpot == 4)
                            || (walk.currentSpot == 4 && walk.nextSpot == 3)
                        walk.dataIndex = walkDataBookmarks[walk.currentSpot][walk.nextSpot]
                    }
                    // Else, we arrived at the destination.
                    else {
                        walk.dataIndex = walkDataBookmarksTurns[walk.finalSpot] + walk.finalHdg + 9
                        walk.hasArrived = true
                    }
                }
            }

            // Walking forward.
            else {
                walk.dataIndex += 1

                // Reached a spot? Begin a turn...
                if walkData[walk.dataIndex][1] == 0 {

                    walk.currentHdg = walkDataEndHeadings[walk.currentSpot][walk.nextSpot]
                    walk.currentSpot = walk.nextSpot

                    if walk.currentSpot != walk.finalSpot {
                        walk.pathIndex += 1
                        walk.nextSpot = walk.path[walk.pathIndex]
                        walk.nextHdg = walkDataStartHeadings[walk.currentSpot][walk.nextSpot]
                    } else {
                        walk.nextHdg = walk.finalHdg
                        walk.lastTurn = true
                    }

                    walk.increment = (walk.nextHdg - walk.currentHdg) & 0x07
                    if walk.increment != 0 {
                        walk.increment = walk.increment < 4 ? 1 : -1
                    }

                    walk.currentHdg = (walk.currentHdg + walk.increment) & 7
                    walk.dataIndex = walkDataBookmarksTurns[walk.currentSpot] + walk.currentHdg

                    if walk.lastTurn {
                        walk.dataIndex += 9  // hands in pockets
                        if walk.currentHdg == walk.finalHdg {
                            walk.hasArrived = true
                        }
                    }
                }
            }

            let step = walkData[walk.dataIndex]
            layer.clearToColorKey()

            grDrawSprite(layer, slot, step[1] - 1, step[2], step[3], 0, flipped: step[0] != 0)

            if walk.isBehindTree {
                grDrawSprite(layer, bgSlot, 442, 148, 13, 0)  // trunk
                grDrawSprite(layer, bgSlot, 365, 122, 12, 0)  // leafs
            }

            delay = walk.hasArrived ? 80 : 6
        } else {
            delay = 0
        }

        return delay
    }
}
