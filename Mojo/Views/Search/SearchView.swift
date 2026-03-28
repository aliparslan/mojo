import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText: String = ""
    @State private var results: [Song] = []

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    ContentUnavailableView(
                        "Search Music",
                        systemImage: "magnifyingglass",
                        description: Text("Search by song title, artist, or album.")
                    )
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(results) { song in
                        SongRow(song: song)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                appState.play(song: song, queue: results)
                            }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Songs, artists, albums")
            .onChange(of: searchText) { _, newValue in
                if newValue.count >= 2 {
                    results = appState.databaseManager.searchSongs(query: newValue)
                } else {
                    results = []
                }
            }
        }
    }
}

#Preview {
    SearchView()
        .environment(AppState())
}
