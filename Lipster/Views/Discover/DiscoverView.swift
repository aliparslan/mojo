import SwiftUI

struct DiscoverView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            AmbientBackgroundView(
                colors: appState.albumColors,
                image: appState.currentSong?.coverArtImage
            )

            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.3))
                Text("Discover")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text("Coming soon")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
