//
//  PlayerViewModel.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/28.
//

import Foundation
import AVFoundation
import Combine
import UIKit
import MediaPlayer

@MainActor
final class PlayerViewModel: ObservableObject {

    // Core Components
    let player = AVPlayer()
    var videoStore: VideoStore!
    var settingsStore: SettingsStore?
    private let fetchVideoService = FetchVideoService()
    private var loadStartTime: Date?

    // Data Source (Runtime Only)
    @Published var currentVideoItem: VideoItem?

    // Subtitle
    @Published var captions: [CaptionLine] = []

    // Playback State
    @Published var isPlaying = false
    @Published var isVideoLoading = true
    @Published var rate: Float = 1.0
    @Published var tempRate: Float = 1.0

    // Subtitle Status about
    @Published var currentLineID: String? = nil
    @Published private(set) var isLoopingSingleLine = false
    private(set) var lockedLoopLine: CaptionLine?
    private var currentCaptionIndex: Int = 0
    private var currentLoopEndTime: CMTime?

    // UI about
    @Published var nowPlayingTitle: String = ""
    @Published var nowPlayingArtwork: UIImage?

    // Loopup Status
    struct WordIdentifiable: Identifiable {
        let id = UUID()
        let word: String
    }
    @Published var activeLookUpWordIdentifiable: WordIdentifiable? = nil

    // Private Observers
    private var timeObserver: Any?
    private var playerItemObservation: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    private var isSeeking = false
    private var boundaryObserver: Any?
    private var loopObserver: Any?
    private var captionBoundaryObservers: [Any] = []


    init() {
        setupAudioSession()
        setupRemoteCommand()
        observePlaybackState()
    }
    func inject(videoStore: VideoStore, settingsStore: SettingsStore) {
        self.videoStore = videoStore
        self.settingsStore = settingsStore
    }


    func startLoadVideo(for item: VideoItem) {
        print("startLoadVide...")
        // 停止舊影片
        player.pause()
        isPlaying = false

        // 清字幕與狀態
        captions = []
        currentLineID = nil
        currentCaptionIndex = 0
        isLoopingSingleLine = false
        lockedLoopLine = nil

        self.currentVideoItem = item
        self.nowPlayingTitle = item.title

        Task {
            await loadVideoProcess(for: item)
        }
    }

    // 入り口
    func loadVideoProcess(for videoItem: VideoItem) async {
        print("isVideoLoading: \(isVideoLoading)")
        loadStartTime = Date()
        self.currentVideoItem = videoItem

        do {
            let videoData = try await fetchVideoService.fetchVideoDataFromServer(videoItem.id)
            self.setupPlayer(with: videoData.videoURL)
            self.loadCaptions(videoID: videoItem.id, captions: videoData.captions)
        } catch {
            self.isVideoLoading = false
            print("❌ 載入失敗: \(error.localizedDescription)")
        }
    }

    // Player Setup & Restoration
    private func setupPlayer(with url: URL) {
        print("setupPlaye()")
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        item.audioTimePitchAlgorithm = .timeDomain

        item.preferredForwardBufferDuration = 6
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true

        player.replaceCurrentItem(with: item)
        // 監聽系統拖動進度條或任何時間跳躍
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTimeJumped),
            name: .AVPlayerItemTimeJumped,
            object: item
        )
        player.automaticallyWaitsToMinimizeStalling = true

        playerItemObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self else { return }
            if item.status == .readyToPlay {
                print("readyToPlay")
                if let startTime = self.loadStartTime {
                    let duration = Date().timeIntervalSince(startTime)
                    print("⏱️ 視頻加載耗時: \(String(format: "%.2f", duration)) 秒")
                    self.loadStartTime = nil
                }

                self.restorePlayProgress()
                self.setupNowPlaying()
            } else if item.status == .failed {
                print("❌ Player Item Failed: \(String(describing: item.error?.localizedDescription))")
                print("❌ Error Detail: \(String(describing: item.error))")
                self.isVideoLoading = false
            }
        }
    }

    // Subtitle & Ruby Logic
    func loadCaptions(videoID: String, captions: [CaptionLine]) {
        self.captions = captions
        print("captions: \(captions.prefix(2))")
        self.currentCaptionIndex = 0
        self.currentLineID = nil

        setupCaptionBoundaryObservers()

        let time = self.player.currentTime().seconds
        // 強制執行一次査找
        self.updateCaptionIndexForSeek(to: time)
        print("✅ Captions Loaded: \(captions.count) lines. Start Index: \(currentCaptionIndex)")
    }

    func restorePlayProgress() {
        guard let videoItem = currentVideoItem else { // , let cachedItem = videoStore.videos.first(where: { $0.id == videoItem.id }) else
            self.isVideoLoading = false
            return
        }

        let videoProgress = videoItem.currentTime ?? 0
        let videoRate = videoItem.rate ?? 1.0
        rate = videoRate

        if videoProgress > 0 {
            let seekTime = CMTime(seconds: videoProgress, preferredTimescale: 600)
            player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                guard let self = self else { return }

                self.updateCaptionIndexForSeek(to: videoProgress)
                self.player.playImmediately(atRate: videoRate)
                self.tempRate = videoRate
                self.isVideoLoading = false
                print("🎯 進度恢復成功: \(videoProgress)s, 語速: \(videoRate)x")
            }
        } else {
            isVideoLoading = false
        }
    }

    func resetPlayer() {
        print("🧹 reset player")
        saveCurrentProgress()

        // 停止播放
        player.pause()
        isPlaying = false

        // 解除 time observer
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }

        // 解除 KVO
        playerItemObservation = nil
        timeControlObserver = nil
        rateObserver = nil

        // 清循環狀態
        isLoopingSingleLine = false
        lockedLoopLine = nil
        currentLineID = nil

        for observer in captionBoundaryObservers {
            player.removeTimeObserver(observer)
        }
        captionBoundaryObservers.removeAll()

        // Remove observer for time jumped
        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemTimeJumped,
            object: player.currentItem
        )

        // 釋放 player item（關鍵）
        player.replaceCurrentItem(with: nil)

        // 清 Now Playing
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func saveCurrentProgress() {
        guard let videoItem = currentVideoItem else { return }

        let currentTime = player.currentTime().seconds
        guard currentTime.isFinite else { return }

        if let video_index = videoStore.videos.firstIndex(where: { $0.id == videoItem.id }) {

            videoStore.videos[video_index].currentTime = currentTime
            videoStore.videos[video_index].rate = self.rate
            print("videoStore.videos[video_index]: \(videoStore.videos[video_index])")
            print("💾 已保存 - 進度: \(currentTime)s, 語速: \(self.rate)x")

            let time_formatted = currentTimeFormatted(Int(currentTime))
            print("time_formatted: \(time_formatted)")
            QuickActionManager.shared.updateResumeVideoAction(
                videoID: videoItem.id,
                title: videoItem.title,
                time: time_formatted
            )
            videoStore.currentResumeVideoID = videoItem.id
        }
    }

    @MainActor
    private func updateCaptionIndexForSeek(to time: Double) {
        guard !captions.isEmpty else { return }

        var left = 0
        var right = captions.count - 1
        var resultIndex: Int? = nil

        // 🛠️ 容錯値：解決 seek 落在 10.49999 而目標是 10.5 的問題
        let epsilon = 0.05

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

        // 如果沒有精確落在區間內，則取「最後一個 start <= time 的行」
        if resultIndex == nil {
            let fallbackIndex = max(0, min(right, captions.count - 1))
            resultIndex = fallbackIndex
        }

        guard let finalIndex = resultIndex else { return }
        if currentCaptionIndex != finalIndex {
            currentCaptionIndex = finalIndex
            currentLineID = captions[finalIndex].id
        }
    }

    @objc
    private func handleTimeJumped() {
        guard !isSeeking else { return }

        let time = player.currentTime().seconds
        updateCaptionIndexForSeek(to: time)
    }

    private func setupCaptionBoundaryObservers() {

        for observer in captionBoundaryObservers {
            player.removeTimeObserver(observer)
        }
        captionBoundaryObservers.removeAll()

        guard !captions.isEmpty else { return }

        for (index, line) in captions.enumerated() {
            let time = CMTime(seconds: line.start, preferredTimescale: 600)

            let observer = player.addBoundaryTimeObserver(
                forTimes: [NSValue(time: time)],
                queue: .main
            ) { [weak self] in
                guard let self else { return }
                guard !self.isSeeking else { return }

                self.currentCaptionIndex = index
                self.currentLineID = line.id
            }

            captionBoundaryObservers.append(observer)
        }
    }

    private func observePlaybackState() {
        timeControlObserver = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            guard let self else { return }

            Task { @MainActor in
                switch player.timeControlStatus {
                    case .playing:
                        self.isPlaying = true
                        self.updateNowPlayingPlaybackRate(self.rate)
                        self.setupNowPlaying()
                    case .paused:
                        self.isPlaying = false
                        self.updateNowPlayingPlaybackRate(0)
                    case .waitingToPlayAtSpecifiedRate:
                        print("⏳ 等待緩衝，自動恢復播放")
                    @unknown default:
                        break
                }
            }
        }
    }

    func setRate(_ newRate: Float) {
        rate = newRate
        tempRate = newRate

        if isPlaying {
            player.playImmediately(atRate: newRate)
        }

        updateNowPlayingPlaybackRate(newRate)
    }

    func playLine(_ line: CaptionLine) {
        // 🔒 1️⃣ 先鎖住 timeObserver
        isSeeking = true

        let start = CMTime(seconds: line.start, preferredTimescale: 600)
        let end = CMTime(seconds: line.end, preferredTimescale: 600)

        currentLoopEndTime = end

        if isLoopingSingleLine {
            removeLoopObserver()
            addLoopObserver(endTime: end)
        }

        // 🟢 2️⃣ 立即同步 index（避免閃一下）,這是用戸点撃的瞬間反饋
        if let idx = captions.firstIndex(where: { $0.id == line.id }) {
            currentCaptionIndex = idx
            currentLineID = line.id
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        player.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard let self, finished else { return }

            Task { @MainActor in
                self.playPlayer()

                // 延遲一個 runloop，避免 boundary observer 在 seek 完成瞬間觸發
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let actualTime = self.player.currentTime().seconds
                    self.updateCaptionIndexForSeek(to: actualTime)
                    self.isSeeking = false
                }
            }
        }

        let time = currentTimeFormatted(Int(line.start))
        print("🔄 手動切換循環目標: \(line)")
        print("time: \(time)")
    }

    private func addLoopObserver(endTime: CMTime) {

        loopObserver = player.addBoundaryTimeObserver(
            forTimes: [NSValue(time: endTime)],
            queue: .main
        ) { [weak self] in
            guard let self else { return }

            guard self.isLoopingSingleLine else { return }

            guard self.currentCaptionIndex < self.captions.count else { return }
            let startSeconds = self.captions[self.currentCaptionIndex].start
            let start = CMTime(seconds: startSeconds, preferredTimescale: 600)

            self.player.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero)
            self.playPlayer()
        }
    }

    private func removeLoopObserver() {
        if let observer = loopObserver {
            player.removeTimeObserver(observer)
            loopObserver = nil
        }
    }

    func playPlayer() {
        player.playImmediately(atRate: rate)
        isPlaying = true
    }

    func pausePlayer() {
        player.pause()
        isPlaying = false
    }
    func currentTimeFormatted(_ time: Int) -> String {
        let totalSeconds = time
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let formatted = String(format: "%02d:%02d", minutes, seconds)

        return formatted
    }

    func toggleSingleLineLoop() {
        isLoopingSingleLine.toggle()

        if isLoopingSingleLine {
            guard currentCaptionIndex < captions.count else { return }

            let endSeconds = captions[currentCaptionIndex].end
            let endTime = CMTime(seconds: endSeconds, preferredTimescale: 600)

            currentLoopEndTime = endTime
            removeLoopObserver()
            addLoopObserver(endTime: endTime)
        } else {
            removeLoopObserver()
        }
    }

    func seek(to seconds: Double, completion: (@Sendable (Bool) -> Void)? = nil) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)

        isSeeking = true

        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard let self, finished else { return }

            Task { @MainActor in
                let actualTime = self.player.currentTime().seconds
                self.updateCaptionIndexForSeek(to: actualTime)
                self.isSeeking = false
                completion?(true)
            }
        }
    }

    func currentLineText() -> String? {
        guard let id = currentLineID, let line = captions.first(where: { $0.id == id }) else { return nil }
        return line.text
    }


    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: []
            )
            try session.setActive(true)
        } catch {
            print("Audio Session 設定失敗: \(error)")
        }
    }
    private func setupRemoteCommand() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true

        center.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.player.rate = self.rate
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            self?.player.pause()
            self?.isPlaying = false
            return .success
        }
    }
    func setupNowPlaying() {
        var info: [String: Any] = [:]

        // title
        info[MPMediaItemPropertyTitle] = nowPlayingTitle

        // duration
        if let duration = player.currentItem?.duration.seconds,
           duration.isFinite {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }

        // current time
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds

        // rate
        info[MPNowPlayingInfoPropertyPlaybackRate] = player.rate

        // artwork
        if let image = nowPlayingArtwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    private func updateNowPlayingPlaybackRate(_ rate: Float) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[
            MPNowPlayingInfoPropertyPlaybackRate
        ] = rate
    }


    private func rubyWord(in line: CaptionLine, at charIndex: Int) -> RubyWord? {
        guard let rubyWords = line.ruby else { return nil }

        return rubyWords.first {
            $0.start <= charIndex &&
            charIndex < ($0.start + $0.length)
        }
    }
    func handleWordLookup(_ lineID: String, _ charIndex: Int) {
        guard let line = captions.first(where: { $0.id == lineID }),
           let rubyWord = rubyWord(in: line, at: charIndex) else { return }

        let word = rubyWord.surface
        print("word: \(word)")

        if activeLookUpWordIdentifiable?.word == word { return }
        if UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: word) {
            print("✨ 系統詞典確認有定義，📖 開始查詢系統詞典: \(word)")

            player.pause()
            isPlaying = false

            DispatchQueue.main.async {
                self.activeLookUpWordIdentifiable = WordIdentifiable(word: word)
            }
        } else {
            print("⚠️ 系統詞典未找到定義: \(word)")
        }
    }
}

extension Notification.Name {
    static let scrollToCurrentLine = Notification.Name("scrollToCurrentLine")
}
