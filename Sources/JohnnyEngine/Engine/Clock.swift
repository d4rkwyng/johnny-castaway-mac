//
//  Johnny Castaway for macOS
//
//  Engine logic ported from 'Johnny Reborn' (jc_reborn) events.c,
//  Copyright (C) 2019 Jeremie GUILLAUME — GPL-3.0-or-later.
//  Swift port Copyright (C) 2026 the johnny-castaway-mac contributors.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//

import Foundation

/// Thrown by a Clock to unwind the (blocking) engine when the host
/// wants it gone. The engine never catches it.
public struct EngineCancelled: Error {}

/// The engine's notion of time: 1 tick = 20 ms. Replaces eventsWaitTick().
public protocol Clock: AnyObject {
    /// Waits until `ticks` × 20 ms have elapsed since the previous tick
    /// boundary (frame pacing, not a plain sleep — time already spent
    /// rendering counts). Throws `EngineCancelled` to stop the engine.
    func waitTicks(_ ticks: Int) throws
}

/// Real-time clock with cancellation, pause, single-step, and a speed
/// multiplier — all callable from other threads.
public final class RealTimeClock: Clock {
    private let lock = NSCondition()
    private var cancelled = false
    private var paused = false
    private var stepRequested = false
    private var _speedMultiplier: Double = 1.0
    private var lastTick = Date()

    public init() {}

    public var speedMultiplier: Double {
        get { lock.lock(); defer { lock.unlock() }; return _speedMultiplier }
        set {
            lock.lock()
            _speedMultiplier = max(newValue, 0.01)
            lock.signal()
            lock.unlock()
        }
    }

    public func cancel() {
        lock.lock()
        cancelled = true
        lock.broadcast()
        lock.unlock()
    }

    public func setPaused(_ value: Bool) {
        lock.lock()
        paused = value
        lock.broadcast()
        lock.unlock()
    }

    /// When paused, lets the engine advance one frame.
    public func step() {
        lock.lock()
        stepRequested = true
        lock.broadcast()
        lock.unlock()
    }

    public func waitTicks(_ ticks: Int) throws {
        lock.lock()
        defer { lock.unlock() }

        let interval = Double(ticks) * 0.020 / _speedMultiplier
        var deadline = lastTick.addingTimeInterval(interval)

        while true {
            if cancelled { throw EngineCancelled() }
            if paused {
                if stepRequested {
                    stepRequested = false
                    break
                }
                lock.wait(until: Date().addingTimeInterval(0.1))
                deadline = Date()  // don't fast-forward after unpause
                continue
            }
            if Date() >= deadline { break }
            lock.wait(until: min(deadline, Date().addingTimeInterval(0.1)))
        }

        lastTick = Date()
    }
}

/// Test clock: returns immediately (max speed), with a tick budget so
/// runaway scripts terminate the test instead of hanging it.
public final class ImmediateClock: Clock {
    public private(set) var elapsedTicks = 0
    public let tickLimit: Int

    public init(tickLimit: Int = .max) {
        self.tickLimit = tickLimit
    }

    public func waitTicks(_ ticks: Int) throws {
        elapsedTicks += ticks
        if elapsedTicks > tickLimit {
            throw EngineCancelled()
        }
    }
}
