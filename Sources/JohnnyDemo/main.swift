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

func locateAssets() -> URL? {
    AssetLocator.find() ?? (AssetLocator.containsAssets(localAssets) ? localAssets : nil)
}

/// The folder to import from, given dropped/selected URLs: the folder
/// itself, or the parent of a dropped RESOURCE.MAP/RESOURCE.001.
func assetSourceDirectory(from urls: [URL]) -> URL? {
    for url in urls {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            continue
        }
        let dir = isDirectory.boolValue ? url : url.deletingLastPathComponent()
        if AssetLocator.containsAssets(dir) { return dir }
    }
    return nil
}

// Windowed launches (Finder double-click, `Johnny story`, --fullscreen) show
// an import window on first run; CLI subcommands keep the terse failure.
let isWindowedLaunch = arguments.allSatisfy { $0.hasPrefix("-") || $0 == "story" }

let assetDir = locateAssets()
let library: ResourceLibrary? = assetDir.flatMap { try? ResourceLibrary(directory: $0) }
if library == nil, !isWindowedLaunch {
    fail("could not find RESOURCE.MAP/RESOURCE.001 (set JC_ASSET_DIR or put them in ./Assets)")
}

if arguments.first == "list", let library {
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

// MARK: - First-run import (drop target)

/// First-run welcome, shown until resource files are imported: drop the
/// folder (or the files) anywhere in the window, or click Choose Folder…
final class SetupDropView: NSView {
    var onURLsDropped: (([URL]) -> Void)?
    var onBrowse: (() -> Void)?

    private let dropZone = NSView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        registerForDraggedTypes([.fileURL])

        let icon = NSImageView(image: NSApp.applicationIconImage ?? NSImage())
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 96).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 96).isActive = true

        let title = NSTextField(labelWithString: "Welcome to Johnny Castaway")
        title.font = .boldSystemFont(ofSize: 20)
        title.textColor = .white
        title.alignment = .center

        let body = NSTextField(wrappingLabelWithString: """
        Johnny plays the artwork from the original 1992 screensaver, which \
        is still copyrighted and isn't bundled. One import sets up both the \
        app and the screensaver.
        """)
        body.font = .systemFont(ofSize: 13)
        body.textColor = NSColor(white: 0.8, alpha: 1)
        body.alignment = .center
        body.preferredMaxLayoutWidth = 430

        let dropHint = NSTextField(labelWithString:
            "Drop the folder with RESOURCE.MAP and RESOURCE.001 here")
        dropHint.font = .systemFont(ofSize: 14, weight: .medium)
        dropHint.textColor = NSColor(white: 0.9, alpha: 1)
        dropHint.alignment = .center

        let dropSub = NSTextField(labelWithString:
            "(sound0–24.wav come along too, if they're next to them)")
        dropSub.font = .systemFont(ofSize: 11)
        dropSub.textColor = .secondaryLabelColor
        dropSub.alignment = .center

        dropZone.wantsLayer = true
        dropZone.layer?.cornerRadius = 12
        dropZone.layer?.borderWidth = 1.5
        dropZone.layer?.borderColor = NSColor(white: 0.45, alpha: 1).cgColor

        let dropStack = NSStackView(views: [dropHint, dropSub])
        dropStack.orientation = .vertical
        dropStack.alignment = .centerX
        dropStack.spacing = 4
        dropStack.translatesAutoresizingMaskIntoConstraints = false
        dropZone.addSubview(dropStack)
        dropZone.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dropStack.centerXAnchor.constraint(equalTo: dropZone.centerXAnchor),
            dropStack.centerYAnchor.constraint(equalTo: dropZone.centerYAnchor),
            dropZone.widthAnchor.constraint(equalToConstant: 460),
            dropZone.heightAnchor.constraint(equalToConstant: 88),
        ])

        let browse = NSButton(title: "Choose Folder…", target: self, action: #selector(browse(_:)))
        browse.keyEquivalent = "\r"
        let help = NSButton(title: "How to Get the Files", target: self, action: #selector(openHelp(_:)))
        let buttons = NSStackView(views: [browse, help])
        buttons.orientation = .horizontal
        buttons.spacing = 12

        let stack = NSStackView(views: [icon, title, body, dropZone, buttons])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16
        stack.setCustomSpacing(10, after: icon)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -60),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func browse(_ sender: NSButton) { onBrowse?() }

    @objc private func openHelp(_ sender: NSButton) {
        NSWorkspace.shared.open(URL(string:
            "https://github.com/d4rkwyng/johnny-castaway-mac#you-must-supply-the-original-game-files")!)
    }

    private func setHighlighted(_ on: Bool) {
        dropZone.layer?.borderColor = (on ? NSColor.controlAccentColor
                                          : NSColor(white: 0.45, alpha: 1)).cgColor
        dropZone.layer?.backgroundColor = (on ? NSColor.controlAccentColor.withAlphaComponent(0.15)
                                              : NSColor.clear).cgColor
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        setHighlighted(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        setHighlighted(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        setHighlighted(false)
        let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        guard !urls.isEmpty else { return false }
        onURLsDropped?(urls)
        return true
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
            ("- or +", "step speed down / up (0.25×–50×)"),
            ("M", "toggle 50× max speed"),
            ("D", "skip to the next story day (1–11)"),
            ("T", "set date & time (holidays, night)"),
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

// MARK: - Date override prompt

/// Accessory for the T-key alert: a date picker with holiday presets.
final class DateOverrideAccessory: NSView {
    let picker = NSDatePicker()
    private let presets = NSPopUpButton()
    private var presetDates: [Date?] = [nil]

    init(initial: Date) {
        super.init(frame: .zero)

        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = [.yearMonthDay, .hourMinute]
        picker.dateValue = initial
        picker.sizeToFit()

        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        func date(month: Int, day: Int, hour: Int) -> Date? {
            calendar.date(from: DateComponents(
                year: year, month: month, day: day, hour: hour))
        }
        let tonight = calendar.date(
            bySettingHour: 23, minute: 30, second: 0, of: Date())

        presets.addItem(withTitle: "Presets")
        for (title, presetDate) in [
            ("Halloween — Oct 31", date(month: 10, day: 31, hour: 12)),
            ("St. Patrick's Day — Mar 17", date(month: 3, day: 17, hour: 12)),
            ("Christmas — Dec 24", date(month: 12, day: 24, hour: 12)),
            ("New Year's Eve — Dec 31", date(month: 12, day: 31, hour: 12)),
            ("Night — today 11:30 pm", tonight),
        ] {
            presets.addItem(withTitle: title)
            presetDates.append(presetDate)
        }
        presets.target = self
        presets.action = #selector(presetPicked(_:))
        presets.sizeToFit()

        let height = max(picker.frame.height, presets.frame.height)
        picker.frame.origin = NSPoint(x: 0, y: (height - picker.frame.height) / 2)
        presets.frame.origin = NSPoint(
            x: picker.frame.maxX + 8, y: (height - presets.frame.height) / 2)
        frame = NSRect(x: 0, y: 0, width: presets.frame.maxX, height: height)
        addSubview(picker)
        addSubview(presets)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func presetPicked(_ sender: NSPopUpButton) {
        if let date = presetDates[sender.indexOfSelectedItem] {
            picker.dateValue = date
        }
    }
}

// MARK: - App

final class DemoAppDelegate: NSObject, NSApplicationDelegate {
    let mode: DemoMode
    // Nil until the first-run import succeeds (windowed launches only).
    var library: ResourceLibrary?
    var soundPlayer: WavSamplePlayer?
    var setupView: SetupDropView?
    // The story day persists across launches, like the real screensaver.
    let storyStore = UserDefaultsStoryStore(defaults: .standard)
    var window: NSWindow!
    var frameView: FrameView!
    var helpOverlay: HelpOverlay?
    var engineClock = RealTimeClock()
    var engineThread: Thread?
    static let speedSteps: [Double] = [0.25, 0.5, 1, 2, 5, 10, 25, 50]
    var paused = false
    var speed: Double = 1
    /// Pretend "now" is shifted by this much (T key) — previews holidays
    /// and night scenes without touching the persisted story day.
    var dateOverrideOffset: TimeInterval?
    /// Bumped on every engine (re)start; a finishing thread only quits
    /// the app if it is still the current generation (not replaced).
    var engineGeneration = 0

    init(mode: DemoMode, library: ResourceLibrary?, soundPlayer: WavSamplePlayer?) {
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

        if library == nil {
            showSetupUI()
        } else {
            startEngine(skipIntro: false)
        }
    }

    // MARK: First-run import

    func showSetupUI() {
        let setup = SetupDropView(frame: frameView.bounds)
        setup.autoresizingMask = [.width, .height]
        setup.onURLsDropped = { [weak self] urls in
            guard let self else { return }
            if let dir = assetSourceDirectory(from: urls) {
                self.importAssets(from: dir)
            } else {
                self.showImportError(
                    "That doesn't contain RESOURCE.MAP and RESOURCE.001 — "
                    + "drop the folder holding both files (or the files themselves).")
            }
        }
        setup.onBrowse = { [weak self] in self?.browseForAssets() }
        frameView.addSubview(setup)
        setupView = setup
        window.title = "Welcome to Johnny Castaway"
    }

    func browseForAssets() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select the folder containing RESOURCE.MAP and RESOURCE.001"
        panel.prompt = "Import"
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            self.importAssets(from: url)
        }
    }

    func importAssets(from source: URL) {
        do {
            try AssetLocator.importAssets(from: source)
            guard let dir = locateAssets() else {
                throw EngineError.fileNotFound("RESOURCE.MAP")
            }
            library = try ResourceLibrary(directory: dir)
            soundPlayer = WavSamplePlayer(directory: dir)
        } catch {
            showImportError(
                "Those files couldn't be imported — make sure they are the "
                + "original RESOURCE.MAP and RESOURCE.001.\n(\(error))")
            return
        }
        setupView?.removeFromSuperview()
        setupView = nil
        startEngine(skipIntro: false)
        updateTitle()
    }

    func showImportError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Import failed"
        alert.informativeText = message
        alert.beginSheetModal(for: window)
    }

    static let overrideFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter
    }()

    func updateTitle() {
        guard library != nil else { return }
        var title = "Johnny Castaway"
        if case .story = mode {
            title += " — day \(max(storyStore.currentDay, 1))"
        }
        if let offset = dateOverrideOffset {
            title += " — pretending it's "
                + Self.overrideFormatter.string(from: Date().addingTimeInterval(offset))
        }
        if paused { title += " (paused)" }
        if speed != 1 {
            let label = speed == speed.rounded() ? "\(Int(speed))" : "\(speed)"
            title += " (\(label)×)"
        }
        window.title = title
    }

    func handleKey(_ event: NSEvent) -> NSEvent? {
        // Don't swallow keys headed for an alert (e.g. Return, T).
        if NSApp.modalWindow != nil { return event }
        // During first-run import only window-level keys make sense.
        if library == nil {
            switch event.charactersIgnoringModifiers?.lowercased() {
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
            setSpeed(speed == 1 ? 50 : 1)
            return nil
        case "-", "_":
            stepSpeed(by: -1)
            return nil
        case "+", "=":
            stepSpeed(by: 1)
            return nil
        case "d":
            skipToNextDay()
            return nil
        case "t":
            promptDateOverride()
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

    func setSpeed(_ newSpeed: Double) {
        speed = newSpeed
        engineClock.speedMultiplier = newSpeed
        updateTitle()
    }

    /// -/+ keys: walk the speed ladder one step at a time.
    func stepSpeed(by direction: Int) {
        let steps = Self.speedSteps
        // Closest rung to the current speed (M can land us between rungs).
        let index = steps.indices.min(by: {
            abs(steps[$0] - speed) < abs(steps[$1] - speed)
        })!
        let next = min(max(index + direction, 0), steps.count - 1)
        setSpeed(steps[next])
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

    /// T key: run the island on a different date and time — see the
    /// holidays and night scenes without waiting for the real calendar.
    func promptDateOverride() {
        guard case .story = mode else { return }

        let alert = NSAlert()
        alert.messageText = "Set Date & Time"
        alert.informativeText =
            "Preview holiday decorations and night scenes by pretending "
            + "it's another date. The saved story day is not affected."
        let accessory = DateOverrideAccessory(
            initial: Date().addingTimeInterval(dateOverrideOffset ?? 0))
        alert.accessoryView = accessory
        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Use Real Time")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            dateOverrideOffset = accessory.picker.dateValue.timeIntervalSinceNow
        case .alertSecondButtonReturn:
            dateOverrideOffset = nil
        default:
            return
        }
        restartEngine()
        updateTitle()
    }

    func restartEngine() {
        engineClock.cancel()
        engineClock = RealTimeClock()
        if paused { engineClock.setPaused(true) }
        engineClock.speedMultiplier = speed
        startEngine(skipIntro: true)
    }

    func startEngine(skipIntro: Bool) {
        guard let library else { return }
        // With a date override, give the engine a throwaway copy of the
        // story state so the pretend date can't corrupt the real arc.
        let store: StoryStateStore
        let dateProvider: @Sendable () -> Date
        if let offset = dateOverrideOffset {
            let memory = InMemoryStoryStore()
            memory.currentDay = max(storyStore.currentDay, 1)
            memory.lastDate = Calendar.current.ordinality(
                of: .day, in: .year, for: Date().addingTimeInterval(offset)) ?? 1
            store = memory
            dateProvider = { Date().addingTimeInterval(offset) }
        } else {
            store = storyStore
            dateProvider = { Date() }
        }

        let engine = Engine(
            library: library, clock: engineClock, presenter: frameView,
            sound: soundPlayer, storyStore: store, dateProvider: dateProvider)
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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc func showAbout() {
        let credits = NSAttributedString(
            string: """
            A native recreation of Screen Antics: Johnny Castaway \
            (© 1992 Sierra On-Line / Dynamix — not affiliated).
            Engine ported from Jérémie Guillaume's jc_reborn.
            GPL-3.0 — requires the original RESOURCE.MAP / RESOURCE.001.
            """,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
            ])
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    func applicationWillTerminate(_ notification: Notification) {
        engineClock.cancel()
    }
}

func buildMainMenu() -> NSMenu {
    let main = NSMenu()
    let appItem = NSMenuItem()
    main.addItem(appItem)

    let appMenu = NSMenu()
    appItem.submenu = appMenu
    appMenu.addItem(NSMenuItem(
        title: "About Johnny Castaway",
        action: #selector(DemoAppDelegate.showAbout), keyEquivalent: ""))
    appMenu.addItem(.separator())
    appMenu.addItem(NSMenuItem(
        title: "Quit Johnny Castaway",
        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    return main
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.mainMenu = buildMainMenu()
let delegate = DemoAppDelegate(
    mode: mode, library: library,
    soundPlayer: assetDir.map { WavSamplePlayer(directory: $0) })
app.delegate = delegate
app.run()
