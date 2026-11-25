import Foundation
import Observation

struct PodcastTranscriptCache: Codable {
    let duration: Double
    let windows: [Int: [CaptionLine]]
}

@MainActor
@Observable
final class PodcastLibrary {
    static let shared = PodcastLibrary()

    private(set) var episodes: [PodcastEpisode] = []
    private(set) var readError: String?
    private let directory: URL

    private init() {
        directory = URL.applicationSupportDirectory.appending(path: "PodcastLibrary", directoryHint: .isDirectory)
        do {
            episodes = try read([PodcastEpisode].self, at: "episodes.json") ?? [.sample]
        } catch {
            readError = error.localizedDescription
        }
    }

    func episode(id: String) -> PodcastEpisode? {
        episodes.first { $0.id == id }
    }

    func add(_ episode: PodcastEpisode) throws {
        guard self.episode(id: episode.id) == nil else { return }
        try saveEpisodes(episodes + [episode])
    }

    func remove(_ episode: PodcastEpisode) throws {
        try saveEpisodes(episodes.filter { $0.id != episode.id })
    }

    func transcript(for episode: PodcastEpisode) throws -> PodcastTranscriptCache? {
        try read(PodcastTranscriptCache.self, at: captionFilename(episode))
    }

    func saveTranscript(_ cache: PodcastTranscriptCache, for episode: PodcastEpisode) throws {
        try write(cache, at: captionFilename(episode))
    }

    private func captionFilename(_ episode: PodcastEpisode) -> String {
        "\(episode.id)-transcript-v2.json"
    }

    private func saveEpisodes(_ updated: [PodcastEpisode]) throws {
        guard readError == nil else { throw CocoaError(.fileReadCorruptFile) }
        try write(updated, at: "episodes.json")
        episodes = updated
    }

    private func read<T: Decodable>(_ type: T.Type, at filename: String) throws -> T? {
        do {
            return try JSONDecoder().decode(type, from: Data(contentsOf: directory.appending(path: filename)))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        }
    }

    private func write<T: Encodable>(_ value: T, at filename: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: directory.appending(path: filename), options: .atomic)
    }
}
