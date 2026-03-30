import SwiftUI

@main
struct LipsterApp: App {
    @State private var appState = AppState()
    @State private var showNowPlaying = false
    @Namespace private var playerTransition

    var body: some Scene {
        WindowGroup {
            TabView {
                LibraryView()
                    .tabItem { Label("Library", systemImage: "music.note.house") }

                FlipBrowserView()
                    .tabItem { Label("Flip", systemImage: "rectangle.stack") }

                SearchView()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gear") }
            }
            .tabViewBottomAccessory {
                if appState.currentSong != nil {
                    MiniPlayerView(showNowPlaying: $showNowPlaying, namespace: playerTransition)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .environment(appState)
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showNowPlaying) {
                NowPlayingView()
                    .environment(appState)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .navigationTransition(.zoom(sourceID: "nowPlaying", in: playerTransition))
            }
        }
    }
}
