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
    private var loadStartTime: Date?

    // Data Source (Runtime Only)
    @Published var currentVideoItem: VideoItem?

    // Subtitle
    @Published var captions: [CaptionLine] = []

    // Playback State
    @Published var isPlaying = false
    @Published var isVideoLoading = true
    @Published var isProgressing = false
    @Published var rate: Float = 1.0
    @Published var tempRate: Float = 1.0

    // Subtitle Status
    @Published private(set) var currentLineID: String? = nil
    private var currentCaptionIndex: Int = 0
    @Published private(set) var isLoopingSingleLine = false
    private(set) var lockedLoopLine: CaptionLine?
    private var currentLoopEndTime: CMTime?

    // nowPlaying
    @Published var nowPlayingTitle: String = ""
    @Published var nowPlayingArtwork: UIImage?

    // Loopup Status
    struct LookUpWordIdentifiable: Identifiable {
        let id = UUID()
        let word: String
    }
    @Published var activeLookUpWordIdentifiable: LookUpWordIdentifiable? = nil

    // Private Observers
    private var timeObserver: Any?
    private var playerItemObservation: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    private var isSeeking = false
    private var boundaryObserver: Any?
    private var loopObserver: Any?
    private var captionBoundaryObserver: Any?


    init() {
        setupAudioSession()
        setupRemoteCommand()
        observePlaybackState()
    }
    func inject(videoStore: VideoStore, settingsStore: SettingsStore) {
        self.videoStore = videoStore
        self.settingsStore = settingsStore
    }


    func prepareVideo(_ video: VideoItem) {
        nowPlayingTitle = video.title
        loadStartTime = Date()

        if let url = video.thumbnailURL {
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)

                    if let image = UIImage(data: data) {
                        self.nowPlayingArtwork = image
                        self.setupNowPlaying()
                    }
                } catch {
                }
            }
        }

        startLoadVideo(for: video)
    }

    func startLoadVideo(for item: VideoItem) {
        // 停止舊影片
        pausePlayer()

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
        self.currentVideoItem = videoItem

        do {
            let videoData = try await videoStore.fetchVideoDataFromServer(videoItem.id)
            self.setupPlayer(with: videoData.url)
            self.loadCaptions(videoID: videoItem.id, captions: videoData.captions)
        } catch {
            isProgressing = true
            print("❌ 失敗: \(error)")
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
            Task { @MainActor [weak self] in
                guard let self = self else { return }
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
                }
            }
        }
    }

    // Subtitle & Ruby Logic
    func loadCaptions(videoID: String, captions: [CaptionLine]) {
        self.captions = captions
        self.currentCaptionIndex = 0
        self.currentLineID = nil
    }

    func restorePlayProgress() {
        guard let videoItem = currentVideoItem else {
            self.isVideoLoading = false
            return
        }

        let videoProgress = videoItem.currentTime ?? 0
        let videoRate = videoItem.rate ?? 1.0
        rate = videoRate

        let seekTime = CMTime(seconds: videoProgress, preferredTimescale: 600)
        player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                self.updateCaptionIndexForSeek(to: videoProgress)
                self.player.playImmediately(atRate: videoRate)
                self.tempRate = videoRate
                self.isVideoLoading = false

                if videoProgress > 0 {
                    print("🎯 進度恢復成功: \(videoProgress)s, 語速: \(videoRate)x")
                } else {
                    print("▶️ 首次播放，自動開始")
                }
            }
        }
    }

    func saveCurrentProgress() async {
        guard let videoItem = currentVideoItem else { return }

        let currentTime = player.currentTime().seconds
        guard currentTime.isFinite else { return }

        var updatedVideo = videoItem
        updatedVideo.currentTime = currentTime
        updatedVideo.rate = self.rate
        await videoStore.updateVideo(updatedVideo)

        let time_formatted = currentTimeFormatted(Int(currentTime))
        QuickActionManager.shared.updateResumeVideoAction(
            videoID: videoItem.id,
            title: videoItem.title,
            time: time_formatted
        )
        videoStore.currentResumeVideoID = videoItem.id
    }

    @MainActor
    private func updateCaptionIndexForSeek(to time: Double) {
        guard !captions.isEmpty else { return }

        // 🛠️ 容錯値：解決 seek 落在 10.49999 而目標是 10.5 的問題
        let epsilon = 0.05

        // 🔥 優化：快速檢査 (Hot Path)
        // 先檢査「当前正在顯示的這句」是不是還在時間範囲内？如果是，直接 return
        if currentCaptionIndex < captions.count {
            let currentLine = captions[currentCaptionIndex]
            // 稍微放寬一点 epsilon 容錯
            if time >= (currentLine.start - epsilon) &&
                time < currentLine.end &&
                currentLineID != nil {
                return
            }
        }

        var left = 0
        var right = captions.count - 1
        var resultIndex: Int? = nil

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

        if finalIndex != currentCaptionIndex || currentLineID == nil {
            currentCaptionIndex = finalIndex
            currentLineID = captions[finalIndex].id
            // 🔥 重要：重置辺界監聽器，讓它從新位置開始盯哨
            setupNextCaptionBoundaryObserver()
        }
    }

    @objc
    private func handleTimeJumped() {
        guard !isSeeking else { return }

        let time = player.currentTime().seconds
        updateCaptionIndexForSeek(to: time)
    }

    // 1. 動態設置「下一個」辺界監聽
    private func setupNextCaptionBoundaryObserver() {
        // 移除舊的監聽
        if let observer = captionBoundaryObserver {
            player.removeTimeObserver(observer)
            captionBoundaryObserver = nil
        }

        guard currentCaptionIndex < captions.count else { return }
        let currentLine = captions[currentCaptionIndex]
        guard player.currentItem != nil else { return }

        // 如果已経是最後一行，或者没有字幕，就不用設監聽了
        let nextIndex = currentCaptionIndex + 1
        guard nextIndex < captions.count else { return }

        let nextLine = captions[nextIndex]
        let gap = nextLine.start - currentLine.end
        let endTime = CMTime(seconds: currentLine.end, preferredTimescale: 600)

        captionBoundaryObserver = player.addBoundaryTimeObserver(
            forTimes: [NSValue(time: endTime)],
            queue: .main
        ) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard !self.isSeeking else { return }

                if let store = settingsStore, store.videoAutoJumpToNextLine, gap >= 0.5 {
                    // 🔥 立即跳到下一句 start
                    let startTime = CMTime(seconds: nextLine.start, preferredTimescale: 600)
                    self.isSeeking = true
                    await self.player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)

                    self.currentCaptionIndex = nextIndex
                    self.currentLineID = nextLine.id
                    self.isSeeking = false
                    self.setupNextCaptionBoundaryObserver()
                } else {
                    if gap <= 0.05 {
                        // 直接切換到下一行，並重新設置下一行的結束監聽
                        self.currentCaptionIndex = nextIndex
                        self.currentLineID = nextLine.id
                        self.setupNextCaptionBoundaryObserver()
                    } else {
                        // 正常播放模式：兩句之間有微小間隙（例如 0.2 秒），才設置下一個監聽等它自然走到下一句
                        self.observeNaturalStartTime(for: nextLine, at: nextIndex)
                    }
                }
            }
        }
    }

    /// 監聽自然播放到下一句 start
    private func observeNaturalStartTime(for line: CaptionLine, at index: Int) {
        let startTime = CMTime(seconds: line.start, preferredTimescale: 600)
        captionBoundaryObserver = player.addBoundaryTimeObserver(
            forTimes: [NSValue(time: startTime)],
            queue: .main
        ) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.currentCaptionIndex = index
                self.currentLineID = line.id
                setupNextCaptionBoundaryObserver()
            }
        }
    }

    private func observePlaybackState() {
        timeControlObserver = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            guard let self = self else { return }

            Task { @MainActor in
                switch player.timeControlStatus {
                    case .playing:
                        self.isPlaying = true

                        // 🔹 檢查是否被系統修改 rate
                        if player.rate != self.rate {
                            player.playImmediately(atRate: self.rate)
                        }

                        self.updateNowPlayingPlaybackRate(self.rate)
                        self.setupNowPlaying()
                    case .paused:
                        self.isPlaying = false
                        self.updateNowPlayingPlaybackRate(0)
                    case .waitingToPlayAtSpecifiedRate:
                        print("⏳ waitingToPlayAtSpecifiedRate")
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

    func playLine(_ line: CaptionLine, _ index: Int) async {
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
        currentCaptionIndex = index
        currentLineID = line.id
        // 重置監聽器（因為 Index 変了）
        setupNextCaptionBoundaryObserver()

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        await player.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero)

        self.playPlayer()
        // 延遲一個 runloop，避免 boundary observer 在 seek 完成瞬間觸發
        try? await Task.sleep(nanoseconds: 100_000_000)
        self.isSeeking = false
    }

    private func addLoopObserver(endTime: CMTime) {

        loopObserver = player.addBoundaryTimeObserver(
            forTimes: [NSValue(time: endTime)],
            queue: .main
        ) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                guard self.isLoopingSingleLine else { return }

                guard self.currentCaptionIndex < self.captions.count else { return }
                let startSeconds = self.captions[self.currentCaptionIndex].start
                let start = CMTime(seconds: startSeconds, preferredTimescale: 600)

                self.player.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero)
                self.playPlayer()
            }
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
    }

    func pausePlayer() {
        player.pause()
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

    func resetPlayer() {
        print("🧹 reset player")
        // 停止播放
        pausePlayer()

        // 解除 time observer
        if let observer = captionBoundaryObserver {
            player.removeTimeObserver(observer)
            captionBoundaryObserver = nil
        }
        removeLoopObserver()

        // Remove observer for time jumped
        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemTimeJumped,
            object: player.currentItem
        )

        // 解除 KVO
        playerItemObservation?.invalidate()
        playerItemObservation = nil

        timeControlObserver?.invalidate()
        timeControlObserver = nil

        rateObserver?.invalidate()
        rateObserver = nil

        // 清循環狀態
        isLoopingSingleLine = false
        lockedLoopLine = nil
        currentLineID = nil
        captions = []

        // 釋放 player item（關鍵）
        player.replaceCurrentItem(with: nil)

        // 清 Now Playing
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func currentTimeFormatted(_ time: Int) -> String {
        let totalSeconds = time
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let formatted = String(format: "%02d:%02d", minutes, seconds)

        return formatted
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
            self.playPlayer()
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.pausePlayer()
            return .success
        }
    }
    func setupNowPlaying() {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = nowPlayingTitle
        if let duration = player.currentItem?.duration.seconds,
           duration.isFinite {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
        info[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
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

    func handleWordLookup(_ word: String) {
        if activeLookUpWordIdentifiable?.word == word { return }
        if UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: word) {
            pausePlayer()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            DispatchQueue.main.async {
                self.activeLookUpWordIdentifiable = LookUpWordIdentifiable(word: word)
            }
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    func currentLineText() -> String? {
        guard currentCaptionIndex < captions.count else { return nil }
        return captions[currentCaptionIndex].text
    }
}

extension Notification.Name {
    static let scrollToCurrentLine = Notification.Name("scrollToCurrentLine")
}
