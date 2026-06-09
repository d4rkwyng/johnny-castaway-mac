//
//  Johnny Castaway for macOS — windowed app (also the demo/debug tool).
//
//  Johnny [story]                          full screensaver loop (default)
//  Johnny ttm <NAME.TTM>                   play one TTM script
//  Johnny ads <NAME.ADS> <tag> [--island]  play one ADS scene
//  Johnny list                             list playable resources
//  Johnny --fullscreen                     start in fullscreen
//
//  Press H or ? in the app for the key reference.
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

let positional = arguments.filter { !$0.hasPrefix("--") }
let startFullscreen = arguments.contains("--fullscreen")

let mode: DemoMode
switch positional.first {
case "ttm" where positional.count >= 2:
    mode = .ttm(positional[1])
case "ads" where positional.count >= 3:
    guard let tag = UInt16(positional[2]) else { fail("bad tag number '\(positional[2])'") }
    mode = .ads(positional[1], tag, island: arguments.contains("--island"))
case "story", nil:
    mode = .story
default:
    fail("""
    usage: Johnny [story] [--fullscreen]              full screensaver loop
           Johnny ttm <NAME.TTM>                      single animation script
           Johnny ads <NAME.ADS> <tag> [--island]     single scene
           Johnny list                                list playable resources
    """)
}

// MARK: - Frame presentation

final class FrameView: NSView, FramePresenter {
    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.magnificationFilter = .nearest
        layer?.contentsGravity = .resizeAspect  // letterbox, never stretch
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

// MARK: - Help overlay

final class HelpOverlay: NSVisualEffectView {
    init() {
        super.init(frame: .zero)
        material = .hudWindow
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 12

        let title = NSTextField(labelWithString: "Keyboard Controls")
        title.font = .boldSystemFont(ofSize: 16)
        title.textColor = .labelColor

        let keys: [(String, String)] = [
            ("H or ?", "show / hide this help"),
            ("Space", "pause / resume"),
            ("Return", "advance one frame (while paused)"),
            ("M", "toggle 50× max speed"),
            ("D", "skip to the next story day (1–11)"),
            ("F", "toggle fullscreen"),
            ("Q or Esc", "quit"),
        ]

        let grid = NSGridView(views: keys.map { key, desc in
            let k = NSTextField(labelWithString: key)
            k.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
            k.textColor = .labelColor
            let d = NSTextField(labelWithString: desc)
            d.font = .systemFont(ofSize: 13)
            d.textColor = .secondaryLabelColor
            return [k, d]
        })
        grid.columnSpacing = 18
        grid.rowSpacing = 6

        let stack = NSStackView(views: [title, grid])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 22, bottom: 18, right: 22)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - App

final class DemoAppDelegate: NSObject, NSApplicationDelegate {
    let mode: DemoMode
    let library: ResourceLibrary
    let soundPlayer: WavSamplePlayer
    // The story day persists across launches, like the real screensaver.
    let storyStore = UserDefaultsStoryStore(defaults: .standard)
    var window: NSWindow!
    var frameView: FrameView!
    var helpOverlay: HelpOverlay?
    var engineClock = RealTimeClock()
    var engineThread: Thread?
    var paused = false
    var maxSpeed = false
    /// Bumped on every engine (re)start; a finishing thread only quits
    /// the app if it is still the current generation (not replaced).
    var engineGeneration = 0

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
        window.contentView = frameView
        window.contentAspectRatio = NSSize(width: 4, height: 3)
        window.collectionBehavior = [.fullScreenPrimary]
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        updateTitle()

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event) ?? event
        }

        if startFullscreen {
            window.toggleFullScreen(nil)
        }

        startEngine(skipIntro: false)
    }

    func updateTitle() {
        var title = "Johnny Castaway"
        if case .story = mode {
            title += " — day \(max(storyStore.currentDay, 1))"
        }
        if paused { title += " (paused)" }
        if maxSpeed { title += " (max speed)" }
        window.title = title
    }

    func handleKey(_ event: NSEvent) -> NSEvent? {
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "h", "?", "/":
            toggleHelp()
            return nil
        case " ":
            paused.toggle()
            engineClock.setPaused(paused)
            updateTitle()
            return nil
        case "\r":
            engineClock.step()
            return nil
        case "m":
            maxSpeed.toggle()
            engineClock.speedMultiplier = maxSpeed ? 50 : 1
            updateTitle()
            return nil
        case "d":
            skipToNextDay()
            return nil
        case "f":
            window.toggleFullScreen(nil)
            return nil
        case "q", "\u{1b}":
            NSApp.terminate(nil)
            return nil
        default:
            return event
        }
    }

    func toggleHelp() {
        if let overlay = helpOverlay {
            overlay.removeFromSuperview()
            helpOverlay = nil
            return
        }
        let overlay = HelpOverlay()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        frameView.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.centerXAnchor.constraint(equalTo: frameView.centerXAnchor),
            overlay.centerYAnchor.constraint(equalTo: frameView.centerYAnchor),
        ])
        helpOverlay = overlay
    }

    /// D key: advance Johnny's story to the next day (wraps 11 → 1) and
    /// restart the loop so the island reflects it immediately.
    func skipToNextDay() {
        guard case .story = mode else { return }

        var day = max(storyStore.currentDay, 1) + 1
        if day > 11 { day = 1 }
        storyStore.currentDay = day
        // Pin today's date so the date-change check doesn't double-advance.
        storyStore.lastDate = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1

        restartEngine()
        updateTitle()
    }

    func restartEngine() {
        engineClock.cancel()
        engineClock = RealTimeClock()
        if paused { engineClock.setPaused(true) }
        if maxSpeed { engineClock.speedMultiplier = 50 }
        startEngine(skipIntro: true)
    }

    func startEngine(skipIntro: Bool) {
        let engine = Engine(
            library: library, clock: engineClock, presenter: frameView,
            sound: soundPlayer, storyStore: storyStore)
        let mode = self.mode

        engineGeneration += 1
        let generation = engineGeneration
        let thread = Thread { [weak self] in
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
                    try engine.storyPlay(skipIntro: skipIntro)
                }
                print("scene finished")
            } catch is EngineCancelled {
                // shutdown or restart
            } catch {
                print("engine error: \(error)")
            }
            DispatchQueue.main.async {
                guard let self else { return }
                if self.engineGeneration == generation {
                    NSApp.terminate(nil)
                }
            }
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
