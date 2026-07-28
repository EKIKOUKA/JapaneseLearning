import Foundation

/// Main app and Live Activity extension share thumbnails through this container.
enum AppGroupThumbnailStorage {
    static let groupIdentifier = "group.com.makoto.JapaneseLearning"

    private static var directoryURL: URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupIdentifier
        ) else {
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

    static func remove(for videoID: String) {
        guard let url = fileURL(for: videoID) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
