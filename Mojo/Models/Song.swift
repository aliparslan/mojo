import Foundation
import UIKit

struct Song: Identifiable, Hashable, Sendable {
    let id: Int64
    let spotifyId: String?
    let title: String
    let artist: String
    let albumArtist: String?
    let album: String?
    let year: Int?
    let trackNumber: Int?
    let discNumber: Int?
    let durationMs: Int
    let filePath: String
    let downloaded: Bool

    var durationFormatted: String {
        let totalSeconds = durationMs / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Resolves the full file URL in the app's Documents directory.
    var fileURL: URL? {
        guard !filePath.isEmpty,
              let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return docs.appendingPathComponent(filePath)
    }

    /// Resolves cover.jpg from the same album folder as this song.
    var coverArtURL: URL? {
        guard let fileURL else { return nil }
        return fileURL.deletingLastPathComponent().appendingPathComponent("cover.jpg")
    }

    /// Loads cover art as a UIImage from the album folder.
    var coverArtImage: UIImage? {
        guard let url = coverArtURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}
