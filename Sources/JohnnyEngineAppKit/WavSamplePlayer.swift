//
//  Johnny Castaway for macOS
//
//  Port of jc_reborn's sound.c sample model: 25 numbered WAV files
//  (sound0.wav … sound24.wav) supplied by the user; missing files are
//  silently skipped.
//  GPL-3.0-or-later; see LICENSE.
//

import AVFoundation
import Foundation
import JohnnyEngine

public final class WavSamplePlayer: SamplePlayer {
    private var players: [Int: AVAudioPlayer] = [:]
    private let queue = DispatchQueue(label: "net.cyduck.johnny.sound")
    private var _isMuted = false

    /// Muted players swallow play() calls — used by the saver, whose
    /// engine also renders the Sonoma+ desktop-wallpaper companion where
    /// audio must never play.
    public var isMuted: Bool {
        get { queue.sync { _isMuted } }
        set { queue.async { self._isMuted = newValue } }
    }

    /// Loads soundN.wav files from `directory`. Always succeeds; absent
    /// or unreadable files simply leave their slot silent.
    public init(directory: URL) {
        for n in 0..<25 {
            let url = directory.appendingPathComponent("sound\(n).wav")
            if let player = try? AVAudioPlayer(contentsOf: url) {
                player.prepareToPlay()
                players[n] = player
            }
        }
    }

    public var loadedSampleCount: Int { players.count }

    public func play(_ sampleNumber: Int) {
        queue.async { [players] in
            guard !self._isMuted, let player = players[sampleNumber] else { return }
            player.currentTime = 0
            player.play()
        }
    }
}
