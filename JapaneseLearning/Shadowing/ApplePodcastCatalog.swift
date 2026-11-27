import Foundation

enum ApplePodcastCatalog {
    struct Show: Decodable, Identifiable {
        let collectionId: Int
        let collectionName: String
        let artistName: String?
        let collectionViewUrl: URL?
        let feedUrl: URL?
        let artworkUrl600: URL?
        let artworkUrl100: URL?

        var artworkURL: URL? { artworkUrl600 ?? artworkUrl100 }

        var id: Int { collectionId }
    }

    private struct SearchResponse: Decodable {
        let results: [Show]
    }

    static func search(_ query: String, language: VideoContentLanguage) async throws -> [Show] {
        let term = query.isEmpty ? (language == .ja ? "ニュース" : "podcast") : query
        var request = URLComponents(string: "https://itunes.apple.com/search")!
        request.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "country", value: language == .ja ? "JP" : "US"),
            URLQueryItem(name: "media", value: "podcast"),
            URLQueryItem(name: "entity", value: "podcast"),
            URLQueryItem(name: "limit", value: "100")
        ]
        request.percentEncodedQuery = request.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        let (data, _) = try await fetch(request.url!)
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)
        var ids = Set<Int>()
        return response.results.filter { isWebURL($0.feedUrl) && ids.insert($0.id).inserted }
    }

    static func episodes(for show: Show, language: VideoContentLanguage) async throws -> [PodcastEpisode] {
        guard let feed = show.feedUrl, isWebURL(feed) else { throw URLError(.unsupportedURL) }
        let (data, resolvedURL) = try await fetch(feed)
        let delegate = FeedParser()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse() else { throw URLError(.cannotParseResponse) }

        let code = delegate.language.lowercased().split(separator: "-").first
        let episodeLanguage: VideoContentLanguage = switch code {
        case "ja", "jpn": .ja
        case "en", "eng": .en
        default: language
        }
        func artwork(_ value: String) -> URL? {
            let url = URL(string: value, relativeTo: resolvedURL)?.absoluteURL
            return !value.isEmpty && isWebURL(url) ? url : nil
        }

        let showArtwork = artwork(delegate.artwork) ?? show.artworkURL
        let dateParser = DateFormatter()
        dateParser.locale = Locale(identifier: "en_US_POSIX")
        dateParser.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        var seen = Set<URL>()
        return delegate.items.compactMap { item in
            guard let url = URL(string: item.audio, relativeTo: resolvedURL)?.absoluteURL,
                  isWebURL(url), seen.insert(url).inserted else { return nil }
            return PodcastEpisode(
                title: item.title.isEmpty ? show.collectionName : item.title,
                show: show.collectionName,
                language: episodeLanguage,
                source: show.collectionViewUrl ?? feed,
                feed: feed,
                audioURL: url,
                reader: show.artistName,
                durationSeconds: item.duration,
                artworkURL: artwork(item.artwork),
                showArtworkURL: showArtwork,
                summary: item.summary,
                showSummary: delegate.summary,
                publishedDate: dateParser.date(from: item.published)
            )
        }
    }

    private static func isWebURL(_ url: URL?) -> Bool {
        guard let url, let scheme = url.scheme?.lowercased(), url.host != nil else { return false }
        return scheme == "https" || scheme == "http"
    }

    private static func fetch(_ url: URL) async throws -> (Data, URL) {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else { throw URLError(.badServerResponse) }
        return (data, response.url ?? url)
    }

    private final class FeedParser: NSObject, XMLParserDelegate {
        struct Item {
            var title = ""
            var audio = ""
            var duration: Double?
            var artwork = ""
            var summary: String?
            var published = ""
        }

        var language = ""
        var artwork = ""
        var summary: String?
        var items: [Item] = []
        private var item: Item?
        private var path: [String] = []
        private var fragments: [String] = []

        func parser(_ parser: XMLParser, didStartElement name: String,
                    namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
            path.append(name)
            fragments.append("")
            if path == ["rss", "channel", "itunes:image"] {
                artwork = attributes["href"] ?? artwork
            } else if path == ["rss", "channel", "item", "itunes:image"] {
                item?.artwork = attributes["href"] ?? ""
            }
            if path == ["rss", "channel", "item"] {
                item = Item()
            } else if path == ["rss", "channel", "item", "enclosure"],
                      let url = attributes["url"], !url.isEmpty {
                let mime = attributes["type"]?.lowercased() ?? ""
                if mime.hasPrefix("audio/") || mime == "application/octet-stream" || mime.isEmpty {
                    item?.audio = url
                }
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            append(string)
        }

        func parser(_ parser: XMLParser, foundCDATA data: Data) {
            append(String(decoding: data, as: UTF8.self))
        }

        private func append(_ text: String) {
            guard !fragments.isEmpty else { return }
            fragments[fragments.count - 1] += text
        }

        func parser(_ parser: XMLParser, didEndElement name: String,
                    namespaceURI: String?, qualifiedName: String?) {
            let text = fragments.removeLast()
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            switch path {
            case ["rss", "channel", "image", "url"]:
                if artwork.isEmpty { artwork = value }
            case ["rss", "channel", "description"], ["rss", "channel", "itunes:summary"]:
                if !value.isEmpty, summary == nil { summary = value }
            case ["rss", "channel", "item", "description"], ["rss", "channel", "item", "itunes:summary"]:
                if !value.isEmpty, item?.summary == nil { item?.summary = value }
            case ["rss", "channel", "item", "pubDate"]:
                item?.published = value
            case ["rss", "channel", "language"]:
                language = value
            case ["rss", "channel", "item", "title"]:
                item?.title = value
            case ["rss", "channel", "item", "itunes:duration"]:
                let parts = value.split(separator: ":", omittingEmptySubsequences: false)
                let numbers = parts.compactMap { Double($0) }
                if !numbers.isEmpty, numbers.count == parts.count,
                   numbers.allSatisfy({ $0.isFinite && $0 >= 0 }) {
                    let duration = numbers.reduce(0) { $0 * 60 + $1 }
                    item?.duration = duration.isFinite ? duration : nil
                }
            case ["rss", "channel", "item"]:
                if let item, !item.audio.isEmpty { items.append(item) }
                item = nil
            default:
                break
            }
            path.removeLast()
            if path.contains("description") || path.contains("itunes:summary") {
                append(text)
            }
        }
    }
}
