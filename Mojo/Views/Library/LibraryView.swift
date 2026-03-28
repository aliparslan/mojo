import SwiftUI

struct LibraryView: View {
    @State private var selectedTab: LibraryTab = .songs

    enum LibraryTab: String, CaseIterable {
        case songs = "Songs"
        case albums = "Albums"
        case artists = "Artists"
        case playlists = "Playlists"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Library", selection: $selectedTab) {
                    ForEach(LibraryTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                switch selectedTab {
                case .songs:
                    SongsView()
                case .albums:
                    AlbumsView()
                case .artists:
                    ArtistsView()
                case .playlists:
                    PlaylistsView()
                }
            }
            .navigationTitle("Library")
        }
    }
}

#Preview {
    LibraryView()
        .environment(AppState())
}
