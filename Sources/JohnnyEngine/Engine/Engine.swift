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

/// Receives each composited 640×480 frame from the engine thread.
public protocol FramePresenter: AnyObject {
    func present(_ frame: [Pixel])
}

/// Plays the numbered WAV samples (sound0…sound24). The engine itself
/// stays AVFoundation-free; the AppKit side provides the implementation.
public protocol SamplePlayer: AnyObject {
    func play(_ sampleNumber: Int)
}

public let maxBmpSlots = 6
public let maxTtmSlots = 10
public let maxTtmThreads = 10

/// A loaded TTM script: bytecode, the tag jump table built at load time,
/// and the sprite sheets loaded into its 6 BMP slots.
final class TtmSlot {
    var data: [UInt8]? = nil
    var tags: [(id: UInt16, offset: Int)] = []
    var sprites: [[Sprite]] = Array(repeating: [], count: maxBmpSlots)

    var dataSize: Int { data?.count ?? 0 }
}

/// One running animation thread executing a TTM script.
/// `isRunning`: 0 = free, 1 = running, 2 = terminated (pending cleanup),
/// 3 = background island thread.
final class TtmThread {
    unowned(unsafe) var slot: TtmSlot!
    var isRunning = 0
    var sceneSlot: UInt16 = 0
    var sceneTag: UInt16 = 0
    var sceneTimer: Int = 0
    var sceneIterations: Int = 0
    var ip: Int = 0
    var delay: Int = 0
    var timer: Int = 0
    var nextGotoOffset: Int = 0
    var selectedBmpSlot: Int = 0
    var fgColor: UInt8 = 0x0F
    var bgColor: UInt8 = 0x0F
    var layer: Layer?
}

/// The engine: a faithful port of jc_reborn's global state and control
/// flow, scoped to an instance so multiple screens can run independent
/// engines in one process. All methods run on a single engine thread;
/// the only cross-thread interfaces are Clock, FramePresenter and
/// SamplePlayer.
public final class Engine {

    let library: ResourceLibrary
    let palette: Palette
    let clock: Clock
    weak var presenter: FramePresenter?
    weak var sound: SamplePlayer?
    var rng: SeededRandom

    // MARK: graphics.c state

    var background: Layer?
    var savedZonesLayer: Layer?
    var grDx = 0
    var grDy = 0
    var grUpdateDelay = 0
    var fadeOutType = 0

    // MARK: ttm.c state

    var ttmDx = 0
    var ttmDy = 0

    // MARK: ads.c state

    var ttmSlots: [TtmSlot] = (0..<maxTtmSlots).map { _ in TtmSlot() }
    var ttmThreads: [TtmThread] = (0..<maxTtmThreads).map { _ in TtmThread() }
    let backgroundSlot = TtmSlot()
    let backgroundThread = TtmThread()
    let holidaySlot = TtmSlot()
    let holidayThread = TtmThread()

    struct AdsChunk {
        var slot: UInt16
        var tag: UInt16
        var offset: Int
    }

    struct RandOp {
        enum Kind { case addScene, stopScene, nop }
        var kind: Kind
        var slot: UInt16
        var tag: UInt16
        var numPlays: UInt16
        var weight: Int
    }

    var adsChunks: [AdsChunk] = []
    var adsChunksLocal: [AdsChunk] = []
    var adsTags: [(id: UInt16, offset: Int)] = []
    var adsRandOps: [RandOp] = []
    var numThreads = 0
    var adsStopRequested = false

    // MARK: island.c / walk.c / story.c state

    var islandState = IslandState()
    let walkState = WalkState()
    var storyCurrentDay = 1
    /// Test hooks: observe story choreography without affecting playback.
    /// Called right before a scene plays; the Bool marks the final scene.
    var storySceneObserver: ((StoryScene, Bool) -> Void)?
    /// Called right before a connecting walk (fromSpot, fromHdg, toSpot, toHdg).
    var storyWalkObserver: ((Int, Int, Int, Int) -> Void)?
    let storyStore: StoryStateStore
    /// Injectable for tests and the demo app's holiday/night override.
    let dateProvider: @Sendable () -> Date

    public init(
        library: ResourceLibrary,
        clock: Clock,
        presenter: FramePresenter?,
        sound: SamplePlayer? = nil,
        rng: SeededRandom = SeededRandom(),
        storyStore: StoryStateStore = InMemoryStoryStore(),
        dateProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.library = library
        self.palette = Palette(library.palResources[0])
        self.clock = clock
        self.presenter = presenter
        self.sound = sound
        self.rng = rng
        self.storyStore = storyStore
        self.dateProvider = dateProvider
    }
}

/// Persists the 11-day story arc across runs (the original used a
/// config file; the saver uses ScreenSaverDefaults).
public protocol StoryStateStore: AnyObject {
    /// 1…11 — how far Johnny's raft has come.
    var currentDay: Int { get set }
    /// Day-of-year when the story last advanced.
    var lastDate: Int { get set }
}

public final class InMemoryStoryStore: StoryStateStore {
    public var currentDay = 1
    public var lastDate = -1
    public init() {}
}

public final class UserDefaultsStoryStore: StoryStateStore {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public var currentDay: Int {
        get { max(defaults.integer(forKey: "storyCurrentDay"), 0) }
        set { defaults.set(newValue, forKey: "storyCurrentDay") }
    }

    public var lastDate: Int {
        get {
            defaults.object(forKey: "storyLastDate") == nil
                ? -1 : defaults.integer(forKey: "storyLastDate")
        }
        set { defaults.set(newValue, forKey: "storyLastDate") }
    }
}
