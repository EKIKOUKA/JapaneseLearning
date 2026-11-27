import AVFoundation
import SwiftUI

struct PodcastTranscriptView: View {
    let playerVM: PlayerViewManager
    let episode: PodcastEpisode

    @State private var windows: [Int: [CaptionLine]] = [:]
    @State private var errorMessage: String?
    @State private var attempt = 0

    var body: some View {
        VStack(spacing: 8) {
            if let errorMessage {
                Text(errorMessage)
                Button("字幕の生成を再試行") {
                    attempt += 1
                }
            }

            if !playerVM.captions.isEmpty, playerVM.currentVideoItem?.id == episode.id {
                SubtitlesContentView(playerVM: playerVM)
            } else if errorMessage == nil {
                ProgressView("字幕を生成中")
                    .frame(maxHeight: .infinity)
                    .foregroundStyle(.white)
            }
        }
        .task(id: attempt) {
            await recognizeWhileOpen()
        }
    }

    private func recognizeWhileOpen() async {
        errorMessage = nil
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        do {
            let cache = try PodcastLibrary.shared.transcript(for: episode)
            windows = cache?.windows ?? [:]
            // The parent starts playback in its own view task.
            while playerVM.currentVideoItem?.id != episode.id {
                try await Task.sleep(for: .milliseconds(20))
            }
            publishCaptions()
            if let cache, PodcastSpeechProbe.start(of: windows.count) >= cache.duration { return }

            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }

            async let locale = PodcastSpeechProbe.prepare(language: episode.language)
            async let url = PodcastSpeechProbe.download(audioURL: episode.audioURL, to: folder)
            let source = try await AVAudioFile(forReading: url)
            let supportedLocale = try await locale
            let duration = Double(source.length) / source.processingFormat.sampleRate

            while !Task.isCancelled {
                let playback = playerVM.playbackCurrentTime
                let time = playback.isFinite ? min(max(0, playback), max(0, duration - 0.001)) : 0
                let current = PodcastSpeechProbe.windowIndex(at: time)
                let prefetchEnd = min(duration, time + PodcastSpeechProbe.lookahead)
                let last = PodcastSpeechProbe.windowIndex(at: prefetchEnd)
                let index = windows[0] == nil ? 0 : (current...last).first {
                    windows[$0] == nil && PodcastSpeechProbe.start(of: $0) < prefetchEnd
                }
                guard let index else {
                    if PodcastSpeechProbe.start(of: windows.count) >= duration { return }
                    try await Task.sleep(for: .milliseconds(100))
                    continue
                }

                let rows = try await PodcastSpeechProbe.recognize(
                    source: source, locale: supportedLocale, language: episode.language, windowIndex: index, folder: folder
                )
                try Task.checkCancellation()

                var updated = windows
                updated[index] = rows.enumerated().compactMap { rowIndex, words -> CaptionLine? in
                    guard let start = words.compactMap(\.start).first,
                          let end = words.compactMap(\.end).last else { return nil }
                    return CaptionLine(
                        id: "podcast-\(index)-\(rowIndex)",
                        start: start,
                        end: end,
                        text: words.map(\.text).joined()
                    )
                }
                try PodcastLibrary.shared.saveTranscript(
                    PodcastTranscriptCache(duration: duration, windows: updated), for: episode
                )
                windows = updated
                publishCaptions()
            }
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
            print("[Podcast Speech] Failed: \(error)")
        }
    }

    private func publishCaptions() {
        let lines = windows.values.flatMap { $0 }.sorted { $0.start < $1.start }
        playerVM.updatePodcastCaptions(lines, episodeID: episode.id)
    }
}
