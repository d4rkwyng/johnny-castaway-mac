//
//  Johnny Castaway for macOS — windowed demo/debug app.
//
//  swift run JohnnyDemo ttm <NAME.TTM>          play one TTM script
//  swift run JohnnyDemo ads <NAME.ADS> <tag>    play one ADS scene
//  swift run JohnnyDemo list                    list playable resources
//
//  Assets are looked up in JC_ASSET_DIR (default: ./Assets).
//  Keys: Space = pause, Return = step, M = max speed, Q/Esc = quit.
//
//  GPL-3.0-or-later; see LICENSE.
//

import AppKit
import JohnnyEngine
import JohnnyEngineAppKit

let arguments = Array(CommandLine.arguments.dropFirst())

func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(1)
}

let localAssets = URL(fileURLWithPath: "Assets")
let assetDir = AssetLocator.find()
    ?? (AssetLocator.containsAssets(localAssets) ? localAssets : nil)

guard let assetDir, let library = try? ResourceLibrary(directory: assetDir) else {
    fail("could not find RESOURCE.MAP/RESOURCE.001 (set JC_ASSET_DIR or put them in ./Assets)")
}

if arguments.first == "list" {
    print("TTM scripts:")
    for r in library.ttmResources {
        print("  \(r.name)")
    }
    print("\nADS scenes:")
    for r in library.adsResources {
        print("  \(r.name)  tags: \(r.tags.map { "\($0.id) (\($0.text))" }.joined(separator: ", "))")
    }
    exit(0)
}

enum DemoMode {
    case ttm(String)
    case ads(String, UInt16, island: Bool)
    case story
}

let mode: DemoMode
switch arguments.first {
case "ttm" where arguments.count >= 2:
    mode = .ttm(arguments[1])
case "ads" where arguments.count >= 3:
    guard let tag = UInt16(arguments[2]) else { fail("bad tag number '\(arguments[2])'") }
    mode = .ads(arguments[1], tag, island: arguments.contains("--island"))
case "story", nil:
    mode = .story
default:
    fail("""
    usage: JohnnyDemo [story]                          full screensaver loop
           JohnnyDemo ttm <NAME.TTM>                   single animation script
           JohnnyDemo ads <NAME.ADS> <tag> [--island]  single scene
           JohnnyDemo list                             list playable resources
    """)
}

// MARK: - Frame presentation

final class FrameView: NSView, FramePresenter {
    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.magnificationFilter = .nearest
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    func present(_ frame: [Pixel]) {
        let image = FrameImage.make(frame)
        DispatchQueue.main.async { [weak self] in
            self?.layer?.contents = image
        }
    }
}

// MARK: - App

final class DemoAppDelegate: NSObject, NSApplicationDelegate {
    let mode: DemoMode
    let library: ResourceLibrary
    let soundPlayer: WavSamplePlayer
    var window: NSWindow!
    var frameView: FrameView!
    let engineClock = RealTimeClock()
    var engineThread: Thread?
    var paused = false
    var maxSpeed = false

    init(mode: DemoMode, library: ResourceLibrary, soundPlayer: WavSamplePlayer) {
        self.mode = mode
        self.library = library
        self.soundPlayer = soundPlayer
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentRect = NSRect(x: 0, y: 0, width: 640, height: 480)
        frameView = FrameView(frame: contentRect)

        window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "Johnny Castaway"
        window.contentView = frameView
        window.contentAspectRatio = NSSize(width: 4, height: 3)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event) ?? event
        }

        startEngine()
    }

    func handleKey(_ event: NSEvent) -> NSEvent? {
        switch event.charactersIgnoringModifiers?.lowercased() {
        case " ":
            paused.toggle()
            engineClock.setPaused(paused)
            window.title = paused ? "Johnny Castaway (paused)" : "Johnny Castaway"
            return nil
        case "\r":
            engineClock.step()
            return nil
        case "m":
            maxSpeed.toggle()
            engineClock.speedMultiplier = maxSpeed ? 50 : 1
            window.title = maxSpeed ? "Johnny Castaway (max speed)" : "Johnny Castaway"
            return nil
        case "q", "\u{1b}":
            NSApp.terminate(nil)
            return nil
        default:
            return event
        }
    }

    func startEngine() {
        let engine = Engine(
            library: library, clock: engineClock, presenter: frameView,
            sound: soundPlayer)
        let mode = self.mode

        let thread = Thread {
            do {
                switch mode {
                case .ttm(let name):
                    engine.adsInit()
                    engine.adsNoIsland()
                    try engine.playSingleTtm(name)
                case .ads(let name, let tag, let island):
                    engine.adsInit()
                    if island {
                        try engine.adsInitIsland()
                    } else {
                        engine.adsNoIsland()
                    }
                    try engine.adsPlay(name, tag)
                case .story:
                    try engine.storyPlay()
                }
                print("scene finished")
            } catch is EngineCancelled {
                // normal shutdown
            } catch {
                print("engine error: \(error)")
            }
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
        thread.name = "JohnnyEngine"
        thread.start()
        engineThread = thread
    }

    func applicationWillTerminate(_ notification: Notification) {
        engineClock.cancel()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = DemoAppDelegate(
    mode: mode, library: library,
    soundPlayer: WavSamplePlayer(directory: assetDir))
app.delegate = delegate
app.run()
