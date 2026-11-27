import CryptoKit
import Foundation

struct PodcastEpisode: Codable, Hashable, Identifiable {
    let title: String
    let show: String
    let language: VideoContentLanguage
    let source: URL
    let feed: URL?
    let audioURL: URL
    var reader: String?
    var durationSeconds: Double?
    var artworkURL: URL?
    var showArtworkURL: URL?
    var summary: String?
    var showSummary: String?
    var publishedDate: Date?

    var id: String {
        let bytes = SHA256.hash(data: Data(audioURL.absoluteString.utf8))
        return "podcast-" + bytes.map { String(format: "%02x", $0) }.joined()
    }

    var video: VideoItem {
        VideoItem(id: id, title: title, durationSeconds: durationSeconds, aspectRatio: 16.0 / 9.0, contentLanguage: language)
    }

    static let sample = PodcastEpisode(
        title: "おくのほそ道 · 第10〜18章",
        show: "おくのほそ道",
        language: .ja,
        source: URL(string: "https://librivox.org/oku-no-hosomichi-by-matsuo-basho/")!,
        feed: URL(string: "https://librivox.org/rss/206")!,
        audioURL: URL(string: "https://archive.org/download/oku_no_hosomichi_librivox/okunohosomichi_10-18_basho.mp3")!
    )
}
