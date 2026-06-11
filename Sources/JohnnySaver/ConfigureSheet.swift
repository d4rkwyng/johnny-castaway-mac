//
//  Johnny Castaway for macOS — options sheet (programmatic, no XIB).
//
//  Lets the user import RESOURCE.MAP/RESOURCE.001 (NSOpenPanel works in
//  the legacyScreenSaver sandbox via the powerbox), toggle sound, and
//  reset the story.
//
//  GPL-3.0-or-later; see LICENSE.
//

import AppKit
import ScreenSaver
import JohnnyEngine
import JohnnyEngineAppKit

struct SaverSettings {
    static let moduleName = "net.cyduck.JohnnyCastaway"

    private var defaults: UserDefaults? {
        ScreenSaverDefaults(forModuleWithName: Self.moduleName)
    }

    var soundEnabled: Bool {
        get { defaults?.object(forKey: "soundEnabled") == nil ? true : defaults!.bool(forKey: "soundEnabled") }
        nonmutating set {
            defaults?.set(newValue, forKey: "soundEnabled")
            defaults?.synchronize()
        }
    }

    func resetStory() {
        defaults?.removeObject(forKey: "storyCurrentDay")
        defaults?.removeObject(forKey: "storyLastDate")
        defaults?.synchronize()
    }
}

final class ConfigureSheet: NSObject {

    let window: NSWindow
    private let statusLabel = NSTextField(labelWithString: "")
    private let soundCheckbox = NSButton(
        checkboxWithTitle: "Play sounds", target: nil, action: nil)
    private let settings = SaverSettings()

    override init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
            styleMask: [.titled], backing: .buffered, defer: false)
        super.init()
        window.title = "Johnny Castaway Options"
        buildUI()
        refreshStatus()
    }

    private func buildUI() {
        let title = NSTextField(labelWithString: "Johnny Castaway")
        title.font = .boldSystemFont(ofSize: 16)

        soundCheckbox.target = self
        soundCheckbox.action = #selector(toggleSound(_:))
        soundCheckbox.state = settings.soundEnabled ? .on : .off

        let importButton = NSButton(
            title: "Import Resource Files…", target: self, action: #selector(importAssets(_:)))
        let resetButton = NSButton(
            title: "Reset Story to Day 1", target: self, action: #selector(resetStory(_:)))
        let doneButton = NSButton(title: "Done", target: self, action: #selector(close(_:)))
        doneButton.keyEquivalent = "\r"

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 3

        let stack = NSStackView(views: [
            title, statusLabel, importButton, soundCheckbox, resetButton, doneButton,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        window.contentView = NSView(frame: window.frame)
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
        ])
    }

    private func refreshStatus() {
        if AssetLocator.find() != nil {
            statusLabel.stringValue = "Resource files imported — Johnny is ready."
        } else {
            statusLabel.stringValue =
                "Resource files not imported yet. Click “Import Resource Files…” "
                + "and select the folder containing RESOURCE.MAP and RESOURCE.001."
        }
    }

    @objc private func toggleSound(_ sender: NSButton) {
        settings.soundEnabled = sender.state == .on
    }

    @objc private func importAssets(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select the folder containing RESOURCE.MAP and RESOURCE.001"
        panel.prompt = "Import"

        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            do {
                try AssetLocator.importAssets(from: url)
                // Validate by parsing.
                _ = try ResourceLibrary(directory: AssetLocator.saverContainerDirectory)
                self.statusLabel.stringValue = "Imported successfully."
            } catch {
                self.statusLabel.stringValue = "Import failed: \(error)"
            }
            self.refreshStatus()
        }
    }

    @objc private func resetStory(_ sender: NSButton) {
        settings.resetStory()
        statusLabel.stringValue = "Story reset — Johnny starts over on day 1."
    }

    @objc private func close(_ sender: NSButton) {
        window.sheetParent?.endSheet(window)
    }
}
