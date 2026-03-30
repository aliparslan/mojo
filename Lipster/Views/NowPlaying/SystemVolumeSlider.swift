import MediaPlayer
import SwiftUI

struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.showsRouteButton = false
        volumeView.setVolumeThumbImage(UIImage(), for: .normal)
        volumeView.tintColor = UIColor.white.withAlphaComponent(0.45)
        return volumeView
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
