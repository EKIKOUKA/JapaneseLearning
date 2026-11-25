import AVFoundation
import Foundation
import NaturalLanguage
import Speech

struct PodcastTimedWord: Sendable {
    let text: String
    let start: Double?
    let end: Double?
}

enum PodcastSpeechProbe {
    static let openingDuration: Double = 10
    static let batchDuration: Double = 40
    static let lookahead: Double = 90

    static func start(of index: Int) -> Double {
        index == 0 ? 0 : openingDuration + Double(index - 1) * batchDuration
    }

    static func windowIndex(at time: Double) -> Int {
        time < openingDuration ? 0 : 1 + Int((time - openingDuration) / batchDuration)
    }

    static func prepare(language: VideoContentLanguage) async throws -> Locale {
        guard SpeechTranscriber.isAvailable else {
            throw ProbeError("この実行環境では SpeechTranscriber を利用できません。")
        }
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: language == .ja ? "ja-JP" : "en-US")) else {
            throw ProbeError("この端末では選択した言語を認識できません。")
        }
        let transcriber = makeTranscriber(locale)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
        return locale
    }

    static func download(audioURL: URL, to folder: URL) async throws -> URL {
        let (download, response) = try await URLSession.shared.download(from: audioURL)
        defer { try? FileManager.default.removeItem(at: download) }
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let sourceURL = folder.appendingPathComponent("episode").appendingPathExtension(audioURL.pathExtension.isEmpty ? "mp3" : audioURL.pathExtension)
        try FileManager.default.moveItem(at: download, to: sourceURL)
        return sourceURL
    }

    static func recognize(source: AVAudioFile, locale: Locale, language: VideoContentLanguage, windowIndex: Int, folder: URL) async throws -> [[PodcastTimedWord]] {
        let start = Self.start(of: windowIndex)
        let end = Self.start(of: windowIndex + 1)
        let sampleRate = source.processingFormat.sampleRate
        let firstFrame = AVAudioFramePosition(max(0, start - 1) * sampleRate)
        let lastFrame = min(source.length, AVAudioFramePosition((end + 1) * sampleRate))
        guard firstFrame < lastFrame else { return [] }

        let excerptURL = folder.appendingPathComponent("excerpt.caf")
        defer { try? FileManager.default.removeItem(at: excerptURL) }
        try writeExcerpt(source: source, frames: firstFrame..<lastFrame, to: excerptURL)
        let excerpt = try AVAudioFile(forReading: excerptURL)
        let transcriber = makeTranscriber(locale)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let offset = Double(firstFrame) / sampleRate
        async let rows = collect(from: transcriber, offset: offset, ownership: start..<end, language: language)

        do {
            if let lastTime = try await analyzer.analyzeSequence(from: excerpt) {
                try await analyzer.finalizeAndFinish(through: lastTime)
            } else {
                await analyzer.cancelAndFinishNow()
            }
            return try await rows
        } catch {
            await analyzer.cancelAndFinishNow()
            throw error
        }
    }

    private static func makeTranscriber(_ locale: Locale) -> SpeechTranscriber {
        SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [.audioTimeRange])
    }

    private static func writeExcerpt(source: AVAudioFile, frames: Range<AVAudioFramePosition>, to url: URL) throws {
        let format = source.processingFormat
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_096) else {
            throw ProbeError("音声バッファを作成できませんでした。")
        }
        let excerpt = try AVAudioFile(forWriting: url, settings: format.settings)
        source.framePosition = frames.lowerBound
        while source.framePosition < frames.upperBound {
            try Task.checkCancellation()
            let remaining = frames.upperBound - source.framePosition
            try source.read(into: buffer, frameCount: AVAudioFrameCount(min(remaining, 4_096)))
            guard buffer.frameLength > 0 else { break }
            try excerpt.write(from: buffer)
        }
    }

    private static func collect(
        from transcriber: SpeechTranscriber,
        offset: Double,
        ownership: Range<Double>,
        language: VideoContentLanguage
    ) async throws -> [[PodcastTimedWord]] {
        var rows: [[PodcastTimedWord]] = []
        for try await result in transcriber.results where result.isFinal {
            let words = timedWords(in: result.text, offset: offset, ownership: ownership, language: language)
            rows.append(contentsOf: captionRows(from: words, language: language))
            #if DEBUG
            for word in words {
                if let start = word.start, let end = word.end {
                    print("[Podcast Speech] \(String(format: "%.3f | %.3f", start, end)) | \(word.text)")
                }
            }
            #endif
        }
        return rows
    }

    private static func timedWords(
        in transcript: AttributedString,
        offset: Double,
        ownership: Range<Double>,
        language: VideoContentLanguage
    ) -> [PodcastTimedWord] {
        let text = String(transcript.characters)
        let timings = transcript.runs.flatMap { run in
            let count = String(transcript[run.range].characters).utf16.count
            return Array(repeating: run.audioTimeRange, count: count)
        }

        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.setLanguage(language == .ja ? .japanese : .english)

        var words: [PodcastTimedWord] = []
        var cursor = text.startIndex
        for token in tokenizer.tokens(for: text.startIndex..<text.endIndex) {
            let first = token.lowerBound.utf16Offset(in: text)
            let last = token.upperBound.utf16Offset(in: text)
            guard last <= timings.count else { break }
            let ranges = timings[first..<last].compactMap { $0 }
            let start = ranges.first.map { $0.start.seconds + offset }
            let end = ranges.last.map { $0.end.seconds + offset }
            if let start, let end, start.isFinite, end.isFinite, end > start,
               ownership.contains((start + end) / 2) {
                if cursor < token.lowerBound, !words.isEmpty {
                    words.append(PodcastTimedWord(text: String(text[cursor..<token.lowerBound]), start: nil, end: nil))
                }
                words.append(PodcastTimedWord(text: String(text[token]), start: start, end: end))
            }
            cursor = token.upperBound
        }
        if cursor < text.endIndex, !words.isEmpty {
            words.append(PodcastTimedWord(text: String(text[cursor...]), start: nil, end: nil))
        }
        return words
    }

    private static func captionRows(
        from words: [PodcastTimedWord],
        language: VideoContentLanguage
    ) -> [[PodcastTimedWord]] {
        guard !words.isEmpty else { return [] }

        let isJapanese = language == .ja
        let maximumLength = isJapanese ? 45 : 100
        var rows: [[PodcastTimedWord]] = []
        var current: [PodcastTimedWord] = []

        for word in words {
            current.append(word)
            let text = current.map(\.text).joined()
            let length = text.filter { !$0.isWhitespace }.count
            let shouldSplit = isJapanese
                ? word.text.contains("。") || (length >= maximumLength && word.text.contains("、"))
                : length >= maximumLength && word.text.contains(",")

            if shouldSplit {
                rows.append(current)
                current = []
            }
        }

        if !current.isEmpty {
            rows.append(current)
        }
        return rows
    }

    private struct ProbeError: LocalizedError {
        let errorDescription: String?

        init(_ message: String) {
            errorDescription = message
        }
    }
}
