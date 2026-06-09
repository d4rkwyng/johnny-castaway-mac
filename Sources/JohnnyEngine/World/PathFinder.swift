//
//  Johnny Castaway for macOS
//
//  Engine logic ported from 'Johnny Reborn' (jc_reborn) calcpath.c,
//  Copyright (C) 2019 Jeremie GUILLAUME — GPL-3.0-or-later.
//  Swift port Copyright (C) 2026 the johnny-castaway-mac contributors.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//

import Foundation

public let numberOfSpots = 6
let undefinedSpot = 6

/// Enumerates every loop-free path between island spots permitted by the
/// direction-sensitive adjacency matrix, then picks one at random.
enum PathFinder {

    static func allPaths(from fromSpot: Int, to toSpot: Int) -> [[Int]] {
        var paths: [[Int]] = []
        var marked = [Bool](repeating: false, count: numberOfSpots)
        var current: [Int] = [fromSpot]
        marked[fromSpot] = true

        func recurse(prev: Int, node: Int) {
            if node == toSpot {
                paths.append(current)
                return
            }
            for next in 0..<numberOfSpots
            where walkMatrix[prev][node][next] != 0 && !marked[next] {
                marked[next] = true
                current.append(next)
                recurse(prev: node, node: next)
                current.removeLast()
                marked[next] = false
            }
        }

        recurse(prev: undefinedSpot, node: fromSpot)
        return paths
    }

    static func path(from fromSpot: Int, to toSpot: Int, rng: inout SeededRandom) -> [Int] {
        let paths = allPaths(from: fromSpot, to: toSpot)
        guard !paths.isEmpty else { return [fromSpot] }
        return paths[rng.next(upperBound: paths.count)]
    }
}
