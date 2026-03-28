import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    var currentSong: Song?
    var isPlaying: Bool = false
    var queue: [Song] = []
    var queueIndex: Int = 0
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var shuffleEnabled: Bool = false
    var repeatEnabled: Bool = false

    let audioPlayer = AudioPlayer()
    let databaseManager = DatabaseManager()
    let nowPlayingManager = NowPlayingManager()

    init() {
        setupCallbacks()
    }

    private func setupCallbacks() {
        audioPlayer.onTimeUpdate = { [weak self] currentTime, duration in
            guard let self else { return }
            self.currentTime = currentTime
            self.duration = duration
        }

        audioPlayer.onSongFinished = { [weak self] in
            guard let self else { return }
            if self.repeatEnabled, let song = self.currentSong {
                self.play(song: song)
            } else {
                self.skipNext()
            }
        }

        nowPlayingManager.onPlay = { [weak self] in
            self?.resume()
        }
        nowPlayingManager.onPause = { [weak self] in
            self?.pause()
        }
        nowPlayingManager.onNextTrack = { [weak self] in
            self?.skipNext()
        }
        nowPlayingManager.onPreviousTrack = { [weak self] in
            self?.skipPrevious()
        }
        nowPlayingManager.onSeek = { [weak self] time in
            self?.audioPlayer.seek(to: time)
            self?.currentTime = time
        }
    }

    func play(song: Song, queue: [Song]? = nil) {
        currentSong = song
        isPlaying = true
        if let queue {
            self.queue = queue
            self.queueIndex = queue.firstIndex(of: song) ?? 0
        }
        audioPlayer.play(song: song)
        let songDuration = Double(song.durationMs) / 1000.0
        nowPlayingManager.update(song: song, isPlaying: true, currentTime: currentTime, duration: songDuration)
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    private func pause() {
        audioPlayer.pause()
        isPlaying = false
        if let song = currentSong {
            nowPlayingManager.update(song: song, isPlaying: false, currentTime: currentTime, duration: duration)
        }
    }

    private func resume() {
        audioPlayer.resume()
        isPlaying = true
        if let song = currentSong {
            nowPlayingManager.update(song: song, isPlaying: true, currentTime: currentTime, duration: duration)
        }
    }

    func skipNext() {
        guard !queue.isEmpty else { return }
        queueIndex = (queueIndex + 1) % queue.count
        let song = queue[queueIndex]
        play(song: song)
    }

    func skipPrevious() {
        guard !queue.isEmpty else { return }
        if currentTime > 3 {
            audioPlayer.seek(to: 0)
            currentTime = 0
            return
        }
        queueIndex = (queueIndex - 1 + queue.count) % queue.count
        let song = queue[queueIndex]
        play(song: song)
    }
}
