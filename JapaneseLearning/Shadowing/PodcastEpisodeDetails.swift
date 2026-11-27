import SwiftUI
import UIKit

struct PodcastArtwork: View {
    let url: URL?
    var fallbackURL: URL? = nil
    let size: CGFloat

    var body: some View {
        PodcastArtworkImage(url: url, fallbackURL: fallbackURL)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.16))
    }
}

struct PodcastArtworkImage: View {
    let url: URL?
    let fallbackURL: URL?
    var contentMode: ContentMode = .fill

    var body: some View {
        PodcastArtworkLoader(url: url, fallbackURL: fallbackURL) { image in
            image.resizable().aspectRatio(contentMode: contentMode)
        } placeholder: {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(Color(red: 0.12, green: 0.16, blue: 0.22))
            Image(systemName: "waveform")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

private struct PodcastArtworkLoader<Artwork: View, Placeholder: View>: View {
    let url: URL?
    let fallbackURL: URL?
    @ViewBuilder let artwork: (Image) -> Artwork
    @ViewBuilder let placeholder: () -> Placeholder

    var body: some View {
        AsyncImage(url: url ?? fallbackURL) { phase in
            switch phase {
            case .success(let image):
                artwork(image)
            case .failure where url != nil && fallbackURL != nil && url != fallbackURL:
                AsyncImage(url: fallbackURL, content: artwork, placeholder: placeholder)
            default:
                placeholder()
            }
        }
        .accessibilityHidden(true)
    }
}

struct PodcastEpisodeLabel: View {
    let episode: PodcastEpisode

    var body: some View {
        HStack(spacing: 12) {
            PodcastArtwork(url: episode.artworkURL, fallbackURL: episode.showArtworkURL, size: 60)
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(episode.show)
                    .lineLimit(1)
                metadata
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var metadata: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                Text(episode.language.displayName)
                if let date = episode.publishedDate { Text(date.formatted(date: .abbreviated, time: .omitted)) }
                if let duration = episode.durationSeconds {
                    Text(Duration.seconds(duration).formatted(.time(pattern: .hourMinuteSecond)))
                }
            }
            Text(episode.language.displayName)
        }
        .lineLimit(1)
    }
}

struct PodcastEpisodeDetails: View {
    let episode: PodcastEpisode
    let onPlay: () -> Void

    var body: some View {
        PodcastDetailLayout(
            title: episode.title,
            artworkURL: episode.artworkURL,
            fallbackURL: episode.showArtworkURL,
            localVideoID: episode.id
        ) { isArtworkLoading in
            details(isArtworkLoading: isArtworkLoading)
        }
    }

    private func details(isArtworkLoading: Bool) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                if let date = episode.publishedDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                }
                if let duration = episode.durationSeconds {
                    Text(Duration.seconds(duration).formatted(.time(pattern: .hourMinuteSecond)))
                }
            }
            Button(action: onPlay) {
                Label("再生", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isArtworkLoading)
            Link("Apple Podcastsで聴く", destination: episode.source)
            if let summary = episode.summary {
                Text(cleaned(summary))
                    .textSelection(.enabled)
            }
            NavigationLink {
                PodcastShowDetails(episode: episode)
            } label: {
                Label("番組情報", systemImage: "info.circle")
            }
        }
        .frame(maxWidth: 600, alignment: .leading)
        .padding(20)
        .frame(maxWidth: .infinity)
    }

}

private struct PodcastShowDetails: View {
    let episode: PodcastEpisode

    var body: some View {
        PodcastDetailLayout(title: episode.show, artworkURL: episode.showArtworkURL) { _ in
            VStack(alignment: .leading, spacing: 16) {
                if let reader = episode.reader {
                    Text(reader).foregroundStyle(.secondary)
                }
                if let summary = episode.showSummary {
                    Text(cleaned(summary)).textSelection(.enabled)
                }
                Link("番組ページを開く", destination: episode.source)
            }
            .frame(maxWidth: 600, alignment: .leading)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct PodcastDetailLayout<Content: View>: View {
    let title: String
    let artworkURL: URL?
    var fallbackURL: URL? = nil
    var localVideoID: String? = nil
    @ViewBuilder let content: (Bool) -> Content
    @State private var loadedArtwork: UIImage?
    @State private var isArtworkLoading = true
    @State private var artworkScrollOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let topHeight = min(geometry.safeAreaInsets.top, statusBarHeight)
            let coverSize = min(geometry.size.width, 520)

            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: topHeight + coverSize)
                        Text(title)
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                            .frame(maxWidth: 600, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
                    }
                    .background {
                        GeometryReader { header in
                            let pullDistance = max(0, -artworkScrollOffset)
                            let cropInset = min(max(0, artworkScrollOffset), header.size.height) / 2

                            cover(
                                width: header.size.width,
                                size: coverSize,
                                topHeight: topHeight,
                                bottomHeight: max(100, header.size.height - topHeight - coverSize)
                            )
                            .mask {
                                Rectangle()
                                    .padding(.vertical, cropInset)
                            }
                            .scaleEffect(
                                1 + pullDistance / max(1, header.size.height),
                                anchor: .center
                            )
                            .offset(y: cropInset - pullDistance / 2)
                            .allowsHitTesting(false)
                        }
                    }
                    content(isArtworkLoading)
                }
            }
            .scrollBounceBehavior(.always)
            .onScrollGeometryChange(for: CGFloat.self) { scroll in
                scroll.contentOffset.y + scroll.contentInsets.top
            } action: { _, offset in
                artworkScrollOffset = offset
            }
            .ignoresSafeArea(.container, edges: .top)
        }
        .task(id: [artworkURL, fallbackURL]) {
            if let localVideoID,
               let file = LocalThumbnailStorage.existingFileURL(for: localVideoID),
               let image = UIImage(contentsOfFile: file.path) {
                loadedArtwork = image
            } else {
                let image = await LocalThumbnailStorage.loadPodcastArtwork(url: artworkURL, fallbackURL: fallbackURL)
                guard !Task.isCancelled else { return }
                loadedArtwork = image
            }
            isArtworkLoading = false
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.visible, for: .navigationBar)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .toolbarVisibility(.hidden, for: .tabBar)
    }

    private var statusBarHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.keyWindow != nil && $0.activationState == .foregroundActive }?
            .statusBarManager?.statusBarFrame.height ?? 0
    }

    @ViewBuilder
    private func cover(width: CGFloat, size: CGFloat, topHeight: CGFloat, bottomHeight: CGFloat) -> some View {
        if let loadedArtwork {
            let image = Image(uiImage: loadedArtwork)
            let topBlend = size * 0.1
            let bottomBlend = size * 0.15
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    PodcastArtworkEdge(image: image, width: width, imageHeight: width, height: topHeight + topBlend, alignment: .top)
                    Color.clear.frame(height: max(0, size - topBlend - bottomBlend))
                    PodcastArtworkEdge(image: image, width: width, imageHeight: width, height: bottomHeight + bottomBlend, alignment: .bottom)
                        .mask {
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: bottomBlend / (bottomHeight + bottomBlend)),
                                    .init(color: .clear, location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                }

                image.resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.1),
                                .init(color: .black, location: 0.85),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .padding(.top, topHeight)
            }
        } else {
            Color.clear
                .frame(height: topHeight + size + bottomHeight)
                .overlay {
                    Image(systemName: "waveform")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
        }
    }

}

struct PodcastArtworkEdge: View {
    let image: Image
    let width: CGFloat
    let imageHeight: CGFloat
    let height: CGFloat
    let alignment: Alignment

    var body: some View {
        image.resizable()
            .scaledToFill()
            .frame(width: width, height: imageHeight)
            .clipped()
            .blur(radius: 24, opaque: true)
            .frame(height: height, alignment: alignment)
            .clipped()
    }
}

private func cleaned(_ text: String) -> String {
    text.replacingOccurrences(of: #"(?i)<br\s*/?>|</p>"#, with: "\n", options: .regularExpression)
        .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        .replacingOccurrences(of: "&nbsp;", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}
