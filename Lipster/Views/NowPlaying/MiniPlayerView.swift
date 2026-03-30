import SwiftUI

struct MiniPlayerView: View {
    @Environment(AppState.self) private var appState
    @Binding var showNowPlaying: Bool
    var namespace: Namespace.ID

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar along top edge
            GeometryReader { geo in
                let progress = appState.duration > 0
                    ? appState.currentTime / appState.duration
                    : 0

                Rectangle()
                    .fill(appState.albumColors.primary)
                    .frame(width: geo.size.width * progress, height: 2)
                    .animation(.linear(duration: 0.5), value: appState.currentTime)
            }
            .frame(height: 2)

            HStack(spacing: 12) {
                // Album art
                if let song = appState.currentSong, let uiImage = song.coverArtImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(width: 48, height: 48)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                        }
                }

                // Song info
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.currentSong?.title ?? "Not Playing")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(appState.currentSong?.artist ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Play/Pause
                Button {
                    Haptics.impact(.light)
                    appState.togglePlayPause()
                } label: {
                    Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 44, height: 44)
                }

                // Next
                Button {
                    Haptics.impact(.light)
                    appState.skipNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.body)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .foregroundStyle(.primary)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .matchedTransitionSource(id: "nowPlaying", in: namespace)
        .contentShape(Rectangle())
        .onTapGesture {
            showNowPlaying = true
        }
    }
}
