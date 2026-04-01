import SwiftUI

struct AmbientBackgroundView: View {
    let colors: AlbumColors
    let image: UIImage?
    var overlayOpacity: Double = 0.0

    var body: some View {
        ZStack {
            Color.black

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 80)
                    .opacity(0.2)
                    .scaleEffect(1.5)
                    .clipped()
            }

            LinearGradient(
                colors: [
                    colors.primary.opacity(0.25),
                    .clear,
                    colors.secondary.opacity(0.15),
                    .clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [colors.primary.opacity(0.12), .clear],
                center: .init(x: 0.5, y: 0.3),
                startRadius: 10,
                endRadius: 350
            )

            if overlayOpacity > 0 {
                Color.black.opacity(overlayOpacity)
            }
        }
        .ignoresSafeArea()
    }
}
