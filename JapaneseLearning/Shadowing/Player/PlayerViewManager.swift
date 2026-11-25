//
//  PlayerViewManager.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/28.
//

import Foundation
import AVFoundation
import Observation
import AVKit
import CoreMedia

@Observable
@MainActor
final class PlayerViewManager {
    // Core Components
    let player = AVPlayer()
    @ObservationIgnored private var nativePlayerViewController: AVPlayerViewController?
    @ObservationIgnored private var nativePlayerVideoID: String?

    // 同じ動画の再表示では描画面を保持し、別動画へは操作 UI の状態を持ち越さない。
    func nativePlayerController(for videoID: String) -> AVPlayerViewController {
        if nativePlayerVideoID == videoID, let nativePlayerViewController {
            return nativePlayerViewController
        }

        let controller = AVPlayerViewController()
        controller.player = player
        controller.view.backgroundColor = .clear
        controller.showsPlaybackControls = true
        controller.canStartPictureInPictureAutomaticallyFromInline = false
        controller.updatesNowPlayingInfoCenter = false
        controller.videoGravity = .resizeAspect
        nativePlayerVideoID = videoID
        nativePlayerViewController = controller
        return controller
    }

    private(set) var playerNowPlaying: PlayerNowPlaying!
    var videoStore: VideoStore!
    var settingsStore: SettingsStore?

    let synthesizer = AVSpeechSynthesizer()

    // Data Source (Runtime Only)
    var currentVideoItem: VideoItem?

    // Subtitle
    var captions: [CaptionLine] = []

    // Playback State
    var isPlaying = false
    var isVideoLoading = true
    var isProgressing = false
    var rate: Float = 1.0
    var tempRate: Float = 1.0
    var isDetailVisible = false
    // Subtitle Status
    private(set) var currentLineID: String? = nil
    private(set) var scrollToCurrentLineRequest = 0
    private var currentCaptionIndex: Int = 0
    private(set) var isLoopingSingleLine = false

    var hasActivePlayback: Bool = false

    // Loopup Status
    struct LookUpWordIdentifiable: Identifiable {
        let id = UUID()
        let word: String
    }
    var activeLookUpWordIdentifiable: LookUpWordIdentifiable? = nil
    var activeAIQuestion: AIExplanationQuestion?

    // Private Observers
    private var playbackObservationTask: Task<Void, Never>?
    private var playerItemStatusTask: Task<Void, Never>?
    private var presentationSizeTask: Task<Void, Never>?
    private var isSeeking = false
    @ObservationIgnored private var subtitleSeekID: UUID?
    private var periodicTimeObserver: Any?

    // 練習タイマー
    var practiceStartedAt: Date?

    init() {
        playerNowPlaying = PlayerNowPlaying(playerManager: self)

        player.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        playerNowPlaying.setupRemoteCommandCenter()
        observePlaybackState()
    }
    func inject(videoStore: VideoStore, settingsStore: SettingsStore) {
        self.videoStore = videoStore
        self.settingsStore = settingsStore
    }

    func startVideo(_ video: VideoItem) {
        let isDifferentVideo = currentVideoItem?.id != video.id
        if !isDifferentVideo && hasActivePlayback {
            isDetailVisible = true
            syncCaptionToCurrentPlayback()
            return
        }

        var playbackVideo = video
        if isDifferentVideo {
            saveCurrentProgressBeforeSwitch()
        } else {
            let time = playbackCurrentTime
            if time.isFinite, !isVideoLoading {
                playbackVideo.currentTime = time
            } else {
                playbackVideo.currentTime = currentVideoItem?.currentTime ?? video.currentTime
            }
            playbackVideo.rate = rate
        }

        isDetailVisible = true
        setupAudioSession()
        prepareVideo(playbackVideo)
        syncCaptionToCurrentPlayback()
    }

    var playbackCurrentTime: Double {
        player.currentTime().seconds
    }

    var playbackDuration: Double {
        let duration = player.currentItem?.duration.seconds ?? 0
        return duration.isFinite ? duration : 0
    }

    private func seekPlayer(to seconds: Double) {
        guard seconds.isFinite else { return }
        player.seek(
            to: CMTime(seconds: seconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    func prepareVideo(_ video: VideoItem) {
        let isSameVideo = currentVideoItem?.id == video.id

        if isSameVideo,
           player.currentItem != nil,
           !isVideoLoading {
            currentVideoItem = video
            playerNowPlaying.nowPlayingTitle = video.title.cleanedVideoTitle
            playerNowPlaying.nowPlayingVideoID = video.id
            isProgressing = false
            isVideoLoading = false
            return
        }

        currentVideoItem = video
        playerNowPlaying.nowPlayingTitle = video.title.cleanedVideoTitle
        playerNowPlaying.nowPlayingVideoID = video.id
        rate = video.rate
        tempRate = video.rate

        if !isSameVideo {
            playerNowPlaying.nowPlayingArtwork = nil
            playerNowPlaying.updateNowPlayingMetadata()
        }

        if !isSameVideo,
           let thumbnailURL = LocalThumbnailStorage.existingFileURL(for: video.id),
           let image = UIImage(contentsOfFile: thumbnailURL.path) {
                self.playerNowPlaying.nowPlayingArtwork = image
                self.playerNowPlaying.updateNowPlayingMetadata()
        }

        startLoadVideo(for: video)
    }

    func startLoadVideo(for item: VideoItem) {
        isProgressing = false
        isVideoLoading = true
        captions = []
        currentLineID = nil
        currentCaptionIndex = 0
        isLoopingSingleLine = false

        Task {
            await loadVideoProcess(for: item)
        }
    }

    // 入り口
    func loadVideoProcess(for videoItem: VideoItem) async {
        guard currentVideoItem?.id == videoItem.id else { return }

        if let episode = PodcastLibrary.shared.episode(id: videoItem.id) {
            setupPlayer(with: episode.audioURL)
            isProgressing = false
            return
        }

        do {
            let sources = try await videoStore.fetchVideoSources(videoItem.id)
            guard currentVideoItem?.id == videoItem.id else { return }

            self.setupPlayer(with: sources.url)
            self.isProgressing = false

            Task { [weak self, videoItem, captionsURL = sources.captionsUrl] in
                guard let self else { return }

                await fetchAndApplyCaptions(videoID: videoItem.id, url: captionsURL)
            }
        } catch {
            guard currentVideoItem?.id == videoItem.id else { return }
            isProgressing = true
            print("❌ 失敗: \(error.localizedDescription)")
        }
    }

    // Player Setup & Restoration
    private func setupPlayer(with url: URL) {
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)

        playerItem.audioTimePitchAlgorithm = .timeDomain
        playerItem.preferredForwardBufferDuration = 6
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true

        player.replaceCurrentItem(with: playerItem)
        player.actionAtItemEnd = .pause

        hasActivePlayback = true

        playerNowPlaying.updateNowPlayingMetadata()
        setupPeriodicObserver()
        guard let video = currentVideoItem else { return }
        setPresentationObserver(playerItem, video: video)
        setupPlayerStatusObserver(playerItem)

        player.automaticallyWaitsToMinimizeStalling = true
    }

    func setupPeriodicObserver() {
        if let periodic_time_observer = periodicTimeObserver {
            player.removeTimeObserver(periodic_time_observer)
            periodicTimeObserver = nil
        }

        periodicTimeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.10, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }

                self.playerNowPlaying.updateNowPlayingProgress()

                guard self.player.currentItem != nil else { return }
                let currentTime = time.seconds
                guard currentTime.isFinite else { return }
                self.updatePlaybackLogic(currentTime)
            }
        }
    }

    func setPresentationObserver(_ playerItem: AVPlayerItem, video: VideoItem) {
        presentationSizeTask?.cancel()
        presentationSizeTask = nil

        guard video.aspectRatio <= 0 else { return }
        let videoID = video.id

        presentationSizeTask = Task { @MainActor [weak self, playerItem] in
            for await size in Observations({ playerItem.presentationSize }) {
                guard let self, !Task.isCancelled else { return }
                guard size.width > 0, size.height > 0 else { continue }

                self.saveVideoAspectRatioIfNeeded(
                    videoID: videoID,
                    resolvedRatio: size.width / size.height
                )
                return
            }
        }
    }

    func setupPlayerStatusObserver(_ playerItem: AVPlayerItem) {
        playerItemStatusTask?.cancel()
        playerItemStatusTask = Task { @MainActor [weak self, playerItem] in
            for await status in Observations({ playerItem.status }) {
                guard let self, !Task.isCancelled else { return }

                switch status {
                case .readyToPlay:
                    self.restorePlayProgress()
                    return

                case .failed:
                    self.isVideoLoading = false
                    print("❌ Player Item Failed: \(String(describing: playerItem.error?.localizedDescription))")
                    print("❌ Error Detail: \(String(describing: playerItem.error))")
                    return

                case .unknown:
                    continue

                @unknown default:
                    continue
                }
            }
        }
    }

    // Subtitle & Ruby Logic
    // 非同期取得の前後で対象を確認し、切り替え前の字幕が混ざるのを防ぐ。
    private func fetchAndApplyCaptions(videoID: String, url: URL) async {
        guard currentVideoItem?.id == videoID else { return }

        do {
            let captions = try await videoStore.fetchCaptions(from: url)
            guard currentVideoItem?.id == videoID else { return }
            loadCaptions(videoID: videoID, captions: captions)
        } catch {
            guard currentVideoItem?.id == videoID else { return }
            print("字幕の取得に失敗しました: \(error.localizedDescription)")
        }
    }

    func updatePodcastCaptions(_ lines: [CaptionLine], episodeID: String) {
        guard currentVideoItem?.id == episodeID else { return }
        let activeID = currentLineID
        captions = lines
        currentCaptionIndex = lines.firstIndex { $0.id == activeID } ?? 0
        syncCaptionToCurrentPlayback()
    }

    func loadCaptions(videoID: String, captions: [CaptionLine]) {
        guard currentVideoItem?.id == videoID else { return }

        self.captions = markIntroLines(captions)
        self.currentCaptionIndex = 0
        self.currentLineID = nil
        syncCaptionToCurrentPlayback()
    }

    func restorePlayProgress() {
        guard let videoItem = currentVideoItem else {
            self.isVideoLoading = false
            self.isProgressing = false
            return
        }

        // The newly-created AVPlayerItem starts at zero. Restore from the
        // persisted video model instead of reading the fresh item's time.
        let videoProgress = videoItem.currentTime ?? 0
        let videoRate = videoItem.rate
        rate = videoRate

        let seekTime = CMTime(seconds: videoProgress, preferredTimescale: 600)
        player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self,
                      self.currentVideoItem?.id == videoItem.id else { return }

                self.isVideoLoading = false
                self.updateCaptionIndexForSeek(to: videoProgress)
                self.player.playImmediately(atRate: videoRate)
                self.isPlaying = true
                playerNowPlaying.updateNowPlayingMetadata()
                self.tempRate = videoRate
            }
        }
    }

    func saveCurrentProgress(currentTimeOverride: Double? = nil) async {
        guard let videoItem = currentVideoItem else { return }

        let currentTime = currentTimeOverride ?? playbackCurrentTime
        await saveProgress(videoItem: videoItem, currentTime: currentTime, rate: rate)
    }

    private func saveCurrentProgressBeforeSwitch() {
        guard let videoItem = currentVideoItem else { return }

        let backendTime = playbackCurrentTime
        let currentTime = backendTime.isFinite ? backendTime : (videoItem.currentTime ?? 0)
        let currentRate = rate

        Task { [weak self, videoItem, currentTime, currentRate] in
            await self?.saveProgress(
                videoItem: videoItem,
                currentTime: currentTime,
                rate: currentRate
            )
        }
    }

    private func saveProgress(videoItem: VideoItem, currentTime: Double, rate: Float) async {
        guard PodcastLibrary.shared.episode(id: videoItem.id) == nil else { return }
        guard currentTime.isFinite else { return }

        var updatedVideo = videoItem
        updatedVideo.currentTime = currentTime
        updatedVideo.rate = rate
        await videoStore.updateVideo(updatedVideo)

        let time_formatted = currentTimeFormatted(Int(currentTime))
        QuickActionManager.shared.updateResumeVideoAction(
            videoID: videoItem.id,
            title: videoItem.title,
            time: time_formatted
        )
    }

    func saveVideoAspectRatioIfNeeded(videoID: String, resolvedRatio: CGFloat) {
        guard currentVideoItem?.id == videoID else { return }
        guard var updatedVideo = currentVideoItem else { return }

        updatedVideo.aspectRatio = resolvedRatio
        currentVideoItem = updatedVideo
        videoStore.updateVideoAspectRatio(updatedVideo)
    }

    @MainActor
    private func updateCaptionIndexForSeek(to time: Double) {
        guard !isSeeking, !captions.isEmpty else { return }
        let epsilon = 0.05

        if isLoopingSingleLine, captions.indices.contains(currentCaptionIndex) {
            let line = captions[currentCaptionIndex]
            if time >= line.end - epsilon {
                seekPlayer(to: line.start)
                player.playImmediately(atRate: rate)
                return
            }
        }

        if currentCaptionIndex >= captions.count {
            currentCaptionIndex = captions.count - 1
        }

        // 🔥 Hot Path
        // current
        if currentCaptionIndex < captions.count {
            let current = captions[currentCaptionIndex]

            if time >= (current.start - epsilon) && time < current.end {
                setCurrentCaption(index: currentCaptionIndex)
                return
            }
        }

        // previous
        if currentCaptionIndex > 0 {
            let previousIndex = currentCaptionIndex - 1
            let previous = captions[previousIndex]

            if time >= (previous.start - epsilon) && time < previous.end {
                setCurrentCaption(index: previousIndex)
                return
            }
        }

        // next
        if currentCaptionIndex + 1 < captions.count {
            let nextIndex = currentCaptionIndex + 1
            let next = captions[nextIndex]

            if time >= (next.start - epsilon) && time < next.end {
                setCurrentCaption(index: nextIndex)
                return
            }
        }

        // 🔥 Fallback Binary Search
        let targetIndex = binarySearchCaptionIndex(time: time)
        guard let targetIndex else { return }

        if captions[targetIndex].isSkip, let nextIndex = nextPlayableIndex(from: targetIndex + 1) {
            seekToCaption(index: nextIndex)
            return
        }

        setCurrentCaption(index: targetIndex)
    }

    private func binarySearchCaptionIndex(time: Double) -> Int? {
        guard !captions.isEmpty else { return nil }

        let epsilon = 0.05

        var left = 0
        var right = captions.count - 1
        var resultIndex: Int?

        while left <= right {
            let mid = (left + right) / 2
            let line = captions[mid]

            if time >= (line.start - epsilon) && time < line.end {
                resultIndex = mid
                break
            } else if time < (line.start - epsilon) {
                right = mid - 1
            } else {
                left = mid + 1
            }
        }

        if resultIndex == nil {
            let fallbackIndex = max(0, min(right, captions.count - 1))
            resultIndex = fallbackIndex
        }
        return resultIndex
    }

    private func setCurrentCaption(index: Int) {
        guard captions.indices.contains(index) else { return }
        currentCaptionIndex = index
        syncCurrentSubtitleLine()
    }

    func syncCurrentSubtitleLine() {
        guard isDetailVisible else { return }
        guard captions.indices.contains(currentCaptionIndex) else { return }

        let line = captions[currentCaptionIndex]
        if currentLineID != line.id {
            currentLineID = line.id
        }
    }

    func syncCaptionToCurrentPlayback() {
        updateCaptionIndexForSeek(to: playbackCurrentTime)
        syncCurrentSubtitleLine()
    }

    private func updatePlaybackLogic(_ time: Double) {
        guard !isSeeking, !captions.isEmpty else { return }
        let epsilon = 0.05

        if currentCaptionIndex >= captions.count {
            currentCaptionIndex = captions.count - 1
        }
        let currentLine = captions[currentCaptionIndex]

        if currentCaptionIndex + 1 < captions.count {
            let nextLine = captions[currentCaptionIndex + 1]

            if nextLine.isSkip,
               let nextPlayable = nextPlayableIndex(from: currentCaptionIndex + 2),
                time > nextLine.start - 1.5 { // 1.5秒前からスキップして
                seekToCaption(index: nextPlayable)
                return
            }
        }

        if time >= (currentLine.start - epsilon) && time < currentLine.end {
            if currentCaptionIndex + 1 < captions.count {
                let nextIndex = currentCaptionIndex + 1
                let nextLine = captions[nextIndex]
                if nextLine.start < currentLine.end && time >= (nextLine.start - epsilon) {
                    currentCaptionIndex = nextIndex
                    syncCurrentSubtitleLine()
                }
            }

            syncCurrentSubtitleLine()
            return
        }

        if currentCaptionIndex + 1 < captions.count {
            let nextIndex = currentCaptionIndex + 1
            let nextLine = captions[nextIndex]

            let gap = nextLine.start - currentLine.end
            if let store = settingsStore,
               store.videoAutoJumpToNextLine,
               gap >= 0.5,
               time >= (currentLine.end - epsilon),
               time < nextLine.start {
                isSeeking = true
                seekPlayer(to: nextLine.start)
                setCurrentCaption(index: nextIndex)
                isSeeking = false

                return
            }
        }
        updateCaptionIndexForSeek(to: time)
    }

    private func nextPlayableIndex(from index: Int) -> Int? {
        guard index < captions.count else { return nil }
        return captions.indices.first(where: { $0 >= index && !captions[$0].isSkip })
    }

    private func seekToCaption(index: Int) {
        guard captions.indices.contains(index) else { return }

        isSeeking = true
        let startTime = captions[index].start
        seekPlayer(to: startTime)
        setCurrentCaption(index: index)
        isSeeking = false
    }

    private func observePlaybackState() {
        playbackObservationTask = Task { @MainActor [weak self, player] in
            for await status in Observations({ player.timeControlStatus }) {
                guard let self, !Task.isCancelled else { return }

                switch status {
                case .playing:
                    self.isPlaying = true

                    if player.rate != self.rate {
                        player.playImmediately(atRate: self.rate)
                    }

                case .paused:
                    self.isPlaying = false

                case .waitingToPlayAtSpecifiedRate:
                    print("⏳ waitingToPlayAtSpecifiedRate")

                @unknown default:
                    break
                }
            }
        }
    }

    func requestScrollToCurrentLine() {
        scrollToCurrentLineRequest &+= 1
    }

    func setRate(_ newRate: Float) {
        rate = newRate
        tempRate = newRate
        if player.timeControlStatus == .playing {
            player.rate = newRate
        }
    }

    func playLine(_ line: CaptionLine, _ index: Int) async {
        guard captions.indices.contains(index), captions[index].id == line.id else { return }
        let requestID = UUID()
        subtitleSeekID = requestID
        isSeeking = true
        currentCaptionIndex = index
        currentLineID = line.id

        let item = player.currentItem
        let finished = await player.seek(
            to: CMTime(seconds: line.start, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        guard subtitleSeekID == requestID else { return }
        isSeeking = false
        guard finished, player.currentItem === item else { return }
        playPlayer()
    }

    func playPlayer() {
        player.playImmediately(atRate: rate)
    }

    func pausePlayer() {
        player.pause()
    }

    func handleDeletedVideo(id: String) {
        guard currentVideoItem?.id == id else { return }
        resetPlayer()
        currentVideoItem = nil
        isDetailVisible = false
    }

    func endVideo(videoID: String) async {
        guard currentVideoItem?.id == videoID else { return }

        isDetailVisible = false

        await saveCurrentProgress()
        await stopPracticeTimingAndSync()
    }

    func toggleSingleLineLoop() {
        guard isLoopingSingleLine || captions.indices.contains(currentCaptionIndex) else { return }
        isLoopingSingleLine.toggle()
    }

    func seek(to seconds: Double, completion: (@Sendable (Bool) -> Void)? = nil) {
        isSeeking = true
        let target = max(0, playbackDuration > 0 ? min(seconds, playbackDuration) : seconds)
        seekPlayer(to: target)
        updateCaptionIndexForSeek(to: target)
        isSeeking = false
        completion?(true)
    }

    func seekForward(seconds: Double = 10) {
        let target = min(
            playbackCurrentTime + seconds,
            playbackDuration > 0 ? playbackDuration : playbackCurrentTime + seconds
        )
        seek(to: target)
    }

    var visiableCaptions: [(Int, CaptionLine)] {
        captions.enumerated()
            .filter { !$0.element.isSkip }
            .map { ($0.offset, $0.element) }
    }
    private func markIntroLines(_ captions: [CaptionLine]) -> [CaptionLine] {
        var result = captions

        let skipWithPreviousLines = videoStore.videoSubtitleSkipWords?.skipWithPreviousLines
        let skipWithNextLines = videoStore.videoSubtitleSkipWords?.skipWithNextLines
        let skipOnlyCurrentLine = videoStore.videoSubtitleSkipWords?.skipOnlyCurrentLine

        for index in result.indices {
            let text = result[index].text
                .lowercased()
                .replacingOccurrences(of: " ", with: "")

            if let skipWithPreviousLines, skipWithPreviousLines.contains(where: { text.contains($0) }) {
                for offset in 0...3 {
                    let target = index - offset

                    if target >= 0 {
                        result[target].isSkip = true
                    }
                }

                continue
            }

            if let skipWithNextLines, skipWithNextLines.contains(where: { text.contains($0) }) {
                for offset in 0...3 {
                    let target = index + offset

                    if target < result.count {
                        result[target].isSkip = true
                    }
                }

                continue
            }

            if let skipOnlyCurrentLine, skipOnlyCurrentLine.contains(where: { text.contains($0) }) {
                result[index].isSkip = true
            }
        }

        return result
    }

    // 再生方式の切り替えと終了時に、登録済みの監視をまとめて解除する。
    private func clearPlaybackObservers() {
        subtitleSeekID = nil
        isSeeking = false
        if let periodicTimeObserver {
            player.removeTimeObserver(periodicTimeObserver)
            self.periodicTimeObserver = nil
        }
        playerItemStatusTask?.cancel()
        playerItemStatusTask = nil
        presentationSizeTask?.cancel()
        presentationSizeTask = nil
    }

    func resetPlayer() {
        player.pause()
        player.cancelPendingPrerolls()
        player.currentItem?.cancelPendingSeeks()

        hasActivePlayback = false

        clearPlaybackObservers()

        // 清循環狀態
        isLoopingSingleLine = false
        currentLineID = nil
        captions = []
        playerNowPlaying.nowPlayingTitle = nil
        playerNowPlaying.nowPlayingVideoID = nil
        playerNowPlaying.nowPlayingArtwork = nil

        player.replaceCurrentItem(with: nil)
        isPlaying = false
        playerNowPlaying.clearNowPlayingInfo()
    }


    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()

            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: []
            )

            if #available(iOS 27.0, *) {
                activateAudioSession(session)
            }
        } catch {
            print("Audio Session 設定失敗: \(error)")
        }
    }

    /// システムの非同期 API を使い、音声ルートの準備でメインスレッドをブロックしない。
    @available(iOS 27.0, *)
    private func activateAudioSession(_ session: AVAudioSession) {
        session.activate(options: []) { activated, error in
            if let error {
                print("オーディオセッションの有効化に失敗しました: \(error.localizedDescription)")
            } else if !activated {
                print("オーディオセッションを有効化できませんでした。")
            }
        }
    }

    func handleWordLookup(_ word: String) {
        if activeLookUpWordIdentifiable?.word == word { return }
        if UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: word) {
            pausePlayer()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            self.activeLookUpWordIdentifiable = LookUpWordIdentifiable(word: word)

            Task {
                try? await Task.sleep(for: .seconds(0.45))
                self.speakWork(word)
            }
        } else {
            showAIExplanation(word, mode: .word)
        }
    }

    func showAIExplanation(_ text: String, mode: AIExplanationMode) {
        guard activeAIQuestion == nil else { return }
        pausePlayer()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        activeAIQuestion = AIExplanationQuestion(text: text, mode: mode)
    }

    func speakWork(_ word: String) {
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }


    func startPracticeTimingIfNeeded() {
        guard practiceStartedAt == nil, currentVideoItem != nil else { return }
        practiceStartedAt = Date()
    }

    func stopPracticeTimingAndSync() async {
        guard let start = practiceStartedAt, let videoItem = currentVideoItem else { return }
        practiceStartedAt = nil

        let elapsed = Date().timeIntervalSince(start)
        guard elapsed >= 30 else { return }

        await videoStore.reportPracticeSession(
            contentLanguage: videoItem.contentLanguage,
            practiceDate: sqliteDateString(from: start),
            startedAt: start,
            endedAt: Date(),
            durationSeconds: Int(elapsed.rounded())
        )
    }
}
