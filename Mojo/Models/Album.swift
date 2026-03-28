import Foundation
import UIKit

struct Album: Identifiable, Hashable, Sendable {
    let id: Int64
    let spotifyId: String?
    let name: String
    let artist: String
    let year: Int?
    let coverPath: String?

    /// Loads cover art from the album's cover.jpg via the spotifyId-based path,
    /// or falls back to finding it via the music folder structure.
    var coverArtImage: UIImage? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        // Try the cover_path stored in DB (e.g. "covers/albums/xyz.jpg")
        if let coverPath, !coverPath.isEmpty {
            let url = docs.appendingPathComponent(coverPath)
            if let img = UIImage(contentsOfFile: url.path) {
                return img
            }
        }
        // Fallback: look for cover.jpg in music/Artist/Album/
        let safe = { (s: String) -> String in
            let illegal = "\\/:*?\"<>|"
            var result = s
            for ch in illegal { result = result.replacingOccurrences(of: String(ch), with: "_") }
            return result.trimmingCharacters(in: .whitespaces)
        }
        let albumFolder = docs
            .appendingPathComponent("music")
            .appendingPathComponent(safe(artist))
            .appendingPathComponent(safe(name))
            .appendingPathComponent("cover.jpg")
        return UIImage(contentsOfFile: albumFolder.path)
    }
}
