import Foundation
import UIKit

struct Playlist: Identifiable, Hashable, Sendable {
    let id: Int64
    let spotifyId: String?
    let name: String
    let description: String?
    let coverPath: String?
    let folderId: Int64?

    var coverArtFilePath: String? {
        guard let coverPath, !coverPath.isEmpty,
              let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let url = docs.appendingPathComponent(coverPath)
        if FileManager.default.fileExists(atPath: url.path) {
            return url.path
        }
        return nil
    }

    var coverArtImage: UIImage? {
        guard let path = coverArtFilePath else { return nil }
        return ImageCache.shared.image(forPath: path)
    }
}
