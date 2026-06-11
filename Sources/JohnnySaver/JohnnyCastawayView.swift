//
//  Johnny Castaway for macOS — the screensaver view.
//
//  Implements the modern (Sonoma/Sequoia/Tahoe) legacyScreenSaver
//  survival kit, per the workarounds proven by the Aerial project:
//   - never rely on animateOneFrame/animationTimeInterval — the engine
//     runs on its own thread and pushes frames to the layer
//   - stopAnimation is never called in normal operation on Sonoma+, so
//     listen for com.apple.screensaver.willstop and exit(0)
//   - isPreview is unreliable; small frames are treated as previews
//   - each view (one per monitor, plus leaked stale instances) gets its
//     own Engine with a distinct RNG seed
//
//  GPL-3.0-or-later; see LICENSE.
//

import AppKit
import ScreenSaver
import JohnnyEngine
import JohnnyEngineAppKit

@objc(JohnnyCastawayView)
public final class JohnnyCastawayView: ScreenSaverView, FramePresenter {

    private var engineClock: RealTimeClock?
    private var engineThread: Thread?
    private var soundPlayer: WavSamplePlayer?
    private var wasStarted = false
    private var occlusionObserver: NSObjectProtocol?

    /// True while the actual screensaver session runs (as opposed to the
    /// wallpaper-companion rendering of the very same view).
    private static var screensaverEngineRunning: Bool {
        !NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.ScreenSaver.Engine").isEmpty
    }

    private var treatAsPreview: Bool {
        // System Settings on Sonoma+ sometimes hands out isPreview=false
        // for the thumbnail; Aerial's width heuristic catches it.
        isPreview || frame.width < 400
    }

    public override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.contentsGravity = .resizeAspect
        layer?.magnificationFilter = .nearest

        animationTimeInterval = 1.0  // unused; the engine paces itself

        if !treatAsPreview {
            // legacyScreenSaver never tells us to stop on Sonoma+;
            // exit(0) when the system says the saver is going away.
            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(willStop(_:)),
                name: Notification.Name("com.apple.screensaver.willstop"),
                object: nil)
            // The same long-lived process can transition between the
            // muted wallpaper companion and the real screensaver.
            DistributedNotificationCenter.default().addObserver(
                self, selector: #selector(saverDidStart(_:)),
                name: Notification.Name("com.apple.screensaver.didstart"),
                object: nil)
            DistributedNotificationCenter.default().addObserver(
                self, selector: #selector(saverDidStop(_:)),
                name: Notification.Name("com.apple.screensaver.didstop"),
                object: nil)
        }
    }

    @objc private func saverDidStart(_ note: Notification) {
        soundPlayer?.isMuted = false
    }

    @objc private func saverDidStop(_ note: Notification) {
        soundPlayer?.isMuted = true
    }

    @objc private func willStop(_ note: Notification) {
        engineClock?.cancel()
        // Give the engine thread a beat to unwind, then take the whole
        // appex down — the documented-but-broken teardown never comes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            exit(0)
        }
    }

    // MARK: - Animation lifecycle

    public override func startAnimation() {
        super.startAnimation()
        if treatAsPreview {
            showStaticPreview()
        } else if engineThread == nil {
            wasStarted = true
            startEngine()
        }
    }

    /// Sonoma+ never calls stopAnimation when a saver is dismissed; it
    /// detaches the view and leaks it with the engine still running —
    /// invisible, but audible and burning CPU. Stop the engine whenever
    /// the system pulls the view off screen.
    public override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            stopEngine()
        }
    }

    /// Same leak, second shape: the window stays attached but is ordered
    /// out or occluded (System Settings preview dismissed, display asleep).
    /// Restarts happen here (not viewWillMove) so `window` is set.
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let observer = occlusionObserver {
            NotificationCenter.default.removeObserver(observer)
            occlusionObserver = nil
        }
        guard let window, !treatAsPreview else { return }
        if wasStarted, engineThread == nil {
            startEngine()
        }
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window, queue: .main) { [weak self] _ in
            guard let self else { return }
            if self.window?.occlusionState.contains(.visible) == true {
                if self.wasStarted, self.engineThread == nil { self.startEngine() }
            } else {
                self.stopEngine()
            }
        }
    }

    private func stopEngine() {
        engineClock?.cancel()
        engineClock = nil
        engineThread = nil
    }

    public override func stopAnimation() {
        super.stopAnimation()
        stopEngine()
    }

    deinit {
        engineClock?.cancel()
        if let observer = occlusionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Engine

    private func startEngine() {
        guard let assetDir = AssetLocator.find(),
              let library = try? ResourceLibrary(directory: assetDir) else {
            showMissingAssetsMessage()
            return
        }

        let defaults = ScreenSaverDefaults(forModuleWithName: SaverSettings.moduleName)
        let settings = SaverSettings()

        let clock = RealTimeClock()
        engineClock = clock

        // Sonoma+ also runs this same view permanently as the desktop
        // wallpaper companion (hosted by WallpaperAgent). The hosting
        // window looks identical in-process either way, so the only
        // reliable signal that we're really screensaving is the
        // ScreenSaverEngine process / its didstart notification. Animate
        // as wallpaper, but never play audio under the user's desktop.
        let sound: WavSamplePlayer? = settings.soundEnabled
            ? WavSamplePlayer(directory: assetDir) : nil
        sound?.isMuted = !Self.screensaverEngineRunning
        soundPlayer = sound

        let store: StoryStateStore = defaults.map { UserDefaultsStoryStore(defaults: $0) }
            ?? InMemoryStoryStore()

        let engine = Engine(
            library: library,
            clock: clock,
            presenter: self,
            sound: sound,
            rng: SeededRandom(),  // distinct seed per view/monitor
            storyStore: store)

        let thread = Thread {
            do {
                try engine.storyPlay()
            } catch {
                // EngineCancelled on teardown — nothing to do.
            }
        }
        thread.name = "JohnnyEngine"
        thread.qualityOfService = .userInteractive
        thread.start()
        engineThread = thread
    }

    public func present(_ frame: [Pixel]) {
        let image = FrameImage.make(frame)
        DispatchQueue.main.async { [weak self] in
            self?.layer?.contents = image
        }
    }

    // MARK: - Preview / fallback content

    private func showStaticPreview() {
        // A cheap static card — never spin up a full engine inside
        // System Settings, where instances leak.
        if let assetDir = AssetLocator.find(),
           let library = try? ResourceLibrary(directory: assetDir),
           let scr = try? library.scr("ISLETEMP.SCR") {
            let layerImage = PixelDecoder.decodeScreen(scr, palette: Palette(library.palResources[0]))
            present(layerImage.pixels)
        } else {
            showMissingAssetsMessage()
        }
    }

    private func showMissingAssetsMessage() {
        let text = "Johnny Castaway\n\nResource files not imported.\nOpen Options… to import\nRESOURCE.MAP / RESOURCE.001."
        let size = NSSize(width: 640, height: 480)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            rect.fill()
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 24, weight: .medium),
                .paragraphStyle: style,
            ]
            let str = NSAttributedString(string: text, attributes: attrs)
            let bounds = str.boundingRect(
                with: rect.size, options: [.usesLineFragmentOrigin])
            str.draw(in: NSRect(
                x: 0, y: (rect.height - bounds.height) / 2,
                width: rect.width, height: bounds.height))
            return true
        }
        DispatchQueue.main.async { [weak self] in
            self?.layer?.contents = image
        }
    }

    // MARK: - Configure sheet

    public override var hasConfigureSheet: Bool { true }

    public override var configureSheet: NSWindow? {
        let sheet = ConfigureSheet()
        self.configureSheetController = sheet
        return sheet.window
    }

    private var configureSheetController: ConfigureSheet?
}
