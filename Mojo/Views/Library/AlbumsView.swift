import SwiftUI

struct AlbumsView: View {
    @Environment(AppState.self) private var appState
    @State private var albums: [Album] = []

    var body: some View {
        Group {
            if albums.isEmpty {
                ContentUnavailableView(
                    "No Albums",
                    systemImage: "square.stack",
                    description: Text("Albums will appear once ripper.db is loaded.")
                )
            } else {
                List(albums) { album in
                    NavigationLink(value: album) {
                        AlbumRow(album: album)
                    }
                }
                .listStyle(.plain)
                .navigationDestination(for: Album.self) { album in
                    AlbumDetailView(album: album)
                }
            }
        }
        .task {
            albums = appState.databaseManager.loadAlbums()
        }
    }
}

struct AlbumRow: View {
    let album: Album

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let uiImage = album.coverArtImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(width: 50, height: 50)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                        }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(album.name)
                    .font(.body)
                    .lineLimit(1)
                Text(album.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let year = album.year {
                    Text(String(year))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct AlbumDetailView: View {
    @Environment(AppState.self) private var appState
    let album: Album
    @State private var songs: [Song] = []

    var body: some View {
        List(songs) { song in
            HStack {
                if let trackNumber = song.trackNumber {
                    Text("\(trackNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.body)
                        .lineLimit(1)
                    Text(song.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(song.durationFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                appState.play(song: song, queue: songs)
            }
        }
        .listStyle(.plain)
        .navigationTitle(album.name)
        .task {
            songs = appState.databaseManager.loadSongsForAlbum(albumId: album.id)
        }
    }
}
