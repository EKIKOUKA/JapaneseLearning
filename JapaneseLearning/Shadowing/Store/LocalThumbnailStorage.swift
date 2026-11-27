import Foundation
import CryptoKit
import UIKit

/// Stores thumbnails in the main app's private container.
enum LocalThumbnailStorage {
    private static var directoryURL: URL? {
        guard let containerURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }

        let directoryURL = containerURL.appendingPathComponent("Thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        return directoryURL
    }

    static func fileURL(for videoID: String) -> URL? {
        directoryURL?.appendingPathComponent("\(videoID).jpg", isDirectory: false)
    }

    static func existingFileURL(for videoID: String) -> URL? {
        guard let url = fileURL(for: videoID),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              (attributes[.size] as? NSNumber)?.intValue ?? 0 > 0 else {
            return nil
        }

        return url
    }

    static func save(_ data: Data, for videoID: String) throws {
        guard let url = fileURL(for: videoID) else {
            throw CocoaError(.fileNoSuchFile)
        }

        try data.write(to: url, options: .atomic)
    }

    static func podcastArtwork(url: URL?, fallbackURL: URL?) -> UIImage? {
        [url, fallbackURL].compactMap { $0 }.lazy.compactMap { url in
            existingFileURL(for: podcastArtworkID(url)).flatMap { UIImage(contentsOfFile: $0.path) }
        }.first
    }

    static func loadPodcastArtwork(url: URL?, fallbackURL: URL?) async -> UIImage? {
        let candidates = [url, fallbackURL == url ? nil : fallbackURL].compactMap { $0 }
        for candidate in candidates {
            guard !Task.isCancelled else { return nil }
            if let cached = podcastArtwork(url: candidate, fallbackURL: nil) { return cached }
            let request = URLRequest(url: candidate, timeoutInterval: 8)
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode),
                  let image = UIImage(data: data) else { continue }
            try? save(data, for: podcastArtworkID(candidate))
            return image
        }
        return nil
    }

    private static func podcastArtworkID(_ url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return "podcast-artwork-" + digest.map { String(format: "%02x", $0) }.joined()
    }

    static func remove(for videoID: String) {
        guard let url = fileURL(for: videoID) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func removeOrphanedThumbnails(keeping videoIDs: Set<String>) {
        guard let directoryURL,
              let files = try? FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
              ) else {
            return
        }

        for fileURL in files where fileURL.pathExtension.lowercased() == "jpg" {
            let videoID = fileURL.deletingPathExtension().lastPathComponent
            guard !videoIDs.contains(videoID) else { continue }
            remove(for: videoID)
        }
    }
}
