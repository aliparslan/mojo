import SwiftUI

struct NowPlayingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var sliderValue: Double = 0
    @State private var isDragging: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            Spacer()

            // Album art
            Group {
                if let song = appState.currentSong, let uiImage = song.coverArtImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: 300, maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: 300)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .shadow(radius: 10)

            Spacer().frame(height: 32)

            // Song info
            VStack(spacing: 4) {
                Text(appState.currentSong?.title ?? "Not Playing")
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)

                Text(appState.currentSong?.artist ?? "")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let album = appState.currentSong?.album {
                    Text(album)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 24)

            // Progress slider
            VStack(spacing: 4) {
                Slider(
                    value: $sliderValue,
                    in: 0...max(appState.duration, 1),
                    onEditingChanged: { editing in
                        isDragging = editing
                        if !editing {
                            appState.audioPlayer.seek(to: sliderValue)
                        }
                    }
                )
                .tint(.primary)

                HStack {
                    Text(formatTime(isDragging ? sliderValue : appState.currentTime))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Spacer()
                    Text("-\(formatTime(max(0, appState.duration - (isDragging ? sliderValue : appState.currentTime))))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 24)

            // Controls
            HStack(spacing: 40) {
                Button {
                    appState.shuffleEnabled.toggle()
                } label: {
                    Image(systemName: "shuffle")
                        .font(.title3)
                        .foregroundStyle(appState.shuffleEnabled ? .primary : .secondary)
                }

                Button {
                    appState.skipPrevious()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title)
                }

                Button {
                    appState.togglePlayPause()
                } label: {
                    Image(systemName: appState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                }

                Button {
                    appState.skipNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title)
                }

                Button {
                    appState.repeatEnabled.toggle()
                } label: {
                    Image(systemName: "repeat")
                        .font(.title3)
                        .foregroundStyle(appState.repeatEnabled ? .primary : .secondary)
                }
            }
            .foregroundStyle(.primary)

            Spacer()
        }
        .onChange(of: appState.currentTime) { _, newValue in
            if !isDragging {
                sliderValue = newValue
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    NowPlayingView()
        .environment(AppState())
}
