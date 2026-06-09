//
//  Johnny Castaway for macOS
//
//  Engine logic ported from 'Johnny Reborn' (jc_reborn),
//  Copyright (C) 2019 Jeremie GUILLAUME — GPL-3.0-or-later.
//  Swift port Copyright (C) 2026 the johnny-castaway-mac contributors.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//

import Foundation

public enum EngineError: Error, CustomStringConvertible {
    case truncatedData(expected: Int, available: Int)
    case badMagic(expected: String, context: String)
    case badData(String)
    case resourceNotFound(String)
    case fileNotFound(String)

    public var description: String {
        switch self {
        case .truncatedData(let expected, let available):
            return "truncated data: needed \(expected) bytes, only \(available) available"
        case .badMagic(let expected, let context):
            return "'\(expected)' string not found while parsing \(context)"
        case .badData(let message):
            return message
        case .resourceNotFound(let name):
            return "resource \(name) not found"
        case .fileNotFound(let path):
            return "file not found: \(path)"
        }
    }
}
