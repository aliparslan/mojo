import SwiftUI

struct PlaylistsView: View {
    @Environment(AppState.self) private var appState
    @State private var playlists: [Playlist] = []

    var body: some View {
        Group {
            if playlists.isEmpty {
                ContentUnavailableView(
                    "No Playlists",
                    systemImage: "music.note.list",
                    description: Text("Playlists will appear once ripper.db is loaded.")
                )
            } else {
                List(playlists) { playlist in
                    NavigationLink(value: playlist) {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray5))
                                .frame(width: 50, height: 50)
                                .overlay {
                                    Image(systemName: "music.note.list")
                                        .foregroundStyle(.secondary)
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(playlist.name)
                                    .font(.body)
                                    .lineLimit(1)
                                if let description = playlist.description {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .navigationDestination(for: Playlist.self) { playlist in
                    PlaylistDetailView(playlist: playlist)
                }
            }
        }
        .task {
            playlists = appState.databaseManager.loadPlaylists()
        }
    }
}

struct PlaylistDetailView: View {
    @Environment(AppState.self) private var appState
    let playlist: Playlist
    @State private var songs: [Song] = []

    var body: some View {
        List(songs) { song in
            SongRow(song: song)
                .contentShape(Rectangle())
                .onTapGesture {
                    appState.play(song: song, queue: songs)
                }
        }
        .listStyle(.plain)
        .navigationTitle(playlist.name)
        .task {
            songs = appState.databaseManager.loadSongsForPlaylist(playlistId: playlist.id)
        }
    }
}
