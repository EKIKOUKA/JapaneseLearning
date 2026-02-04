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
//    private let furiganaServerce = FuriganaService()
    private var loadStartTime: Date?

    // Data Source (Runtime Only)
    @Published var currentVideoItem: VideoItem?

    // Subtitle
    @Published var captions: [CaptionLine] = []

    // Playback State
    @Published var isPlaying = false
    @Published var isVideoLoading = false
    @Published var rate: Float = 1.0
    @Published var tempRate: Float = 1.0

    // Subtitle Status about
    @Published var currentLineID: String? = nil
    @Published private(set) var isLoopingSingleLine = false
    private(set) var lockedLoopLine: CaptionLine?
    private var currentCaptionIndex: Int = 0

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


    init() {
        setupAudioSession()
        setupRemoteCommand()
        setupTimeObserver()
        observePlaybackState()
        observeRate()
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
        self.isVideoLoading = true
        self.nowPlayingTitle = item.title

        Task {
            await loadVideoProcess(for: item)
        }
    }
    // 入り口
    func loadVideoProcess(for videoItem: VideoItem) async {
        isVideoLoading = true
        print("isVideoLoading: \(isVideoLoading)")
        loadStartTime = Date()
        self.currentVideoItem = videoItem

        Task {

            do {
                let videoData = try await fetchVideoService.fetchVideoDataFromServer(videoItem.id)

                if let videoItem = self.currentVideoItem,
                   let index = videoStore.videos.firstIndex(where: { $0.id == videoItem.id }) {
                    if videoStore.videos[index].firstLoad {
                        videoStore.videos[index].firstLoad = false
                        videoStore.saveVideo()

                        self.currentVideoItem?.firstLoad = false
                    }
                }

                await MainActor.run {
                    self.setupPlayer(with: videoData.videoURL)
                }
                try? await Task.sleep(nanoseconds: 100_000_000)

                await MainActor.run {
                    self.loadCaptions(videoID: videoItem.id, captions: videoData.captions)
                }
            } catch {
                await MainActor.run {
                    self.isVideoLoading = false
                    print("❌ 載入失敗: \(error.localizedDescription)")
                }
            }
        }
    }

    // Player Setup & Restoration
    private func setupPlayer(with url: URL) {
        print("setupPlaye()")
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": [
                "User-Agent": "com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X;)",
                "Referer": "https://www.youtube.com/",
                "Origin": "https://www.youtube.com"
            ],
            "AVURLAssetAllowsCellularAccessKey": true,
            "AVURLAssetAllowsExpensiveNetworkAccessKey": true
        ])
        let item = AVPlayerItem(asset: asset)
        item.audioTimePitchAlgorithm = .timeDomain

        item.preferredForwardBufferDuration = 1.0
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true

        player.replaceCurrentItem(with: item)
        player.automaticallyWaitsToMinimizeStalling = false

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

        let time = self.player.currentTime().seconds
        // 強制執行一次査找
        self.updateCaptionIndex(for: time, forceSearch: true)
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
//                DispatchQueue.main.async {
                    self.player.rate = videoRate
                    self.tempRate = videoRate
                    self.isVideoLoading = false
                    print("🎯 進度恢復成功: \(videoProgress)s, 語速: \(videoRate)x")
//                }
            }
        } else {
            player.rate = videoRate
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
    private func updateCaptionIndex(for time: Double, forceSearch: Bool = false) {
        guard !captions.isEmpty else { return }

        // --- 1. 熱路径 (Hot Path): 播放中最常命中的邏輯 ---
        // 只有在非強制搜索模式下才使用快速檢測
        if !forceSearch {
            // A. 優先檢査：是否已経進入下一句？(貪婪模式，解決延遅)
            if currentCaptionIndex + 1 < captions.count {
                let nextLine = captions[currentCaptionIndex + 1]
                if time >= nextLine.start {
                    currentCaptionIndex += 1
                    currentLineID = nextLine.id

                    // 快速追趕：如果一次跳過多句（比如卡頓後），用循環追上
                    while currentCaptionIndex + 1 < captions.count {
                        let nextNext = captions[currentCaptionIndex + 1]
                        if time >= nextNext.start {
                            currentCaptionIndex += 1
                            currentLineID = nextNext.id
                        } else {
                            break
                        }
                    }
                    return
                }
            }

            // B. 檢査当前行是否依然有効
            if currentCaptionIndex < captions.count {
                let currentLine = captions[currentCaptionIndex]
                // 如果還在当前行範囲内，直接返回，不做任何操作
                if time >= currentLine.start && time < currentLine.end {
                    if currentLineID != currentLine.id { currentLineID = currentLine.id }
                    return
                }

                // C. 処理空隙 (Gap)：如果時間大於当前結束，小於下一句開始
                // 保持索引不変，等待下一句
                if currentCaptionIndex + 1 < captions.count {
                    let nextLine = captions[currentCaptionIndex + 1]
                    if time >= currentLine.end && time < nextLine.start {
                        return
                    }
                }
            }
        }

        // --- 2. 冷路径 (Cold Path): 跳転、回跳或熱路径失効時 ---
        // 使用二分査找 (Binary Search)
        var left = 0
        var right = captions.count - 1
        var foundIndex: Int? = nil

        while left <= right {
            let mid = (left + right) / 2
            let line = captions[mid]

            if time >= line.start && time < line.end {
                foundIndex = mid
                // ⚠️ 這裡不 break，継続往後找！
                // 這是解決「閃爍」的関鍵：如果有重畳，我們希望找到「最晚」開始的那一行
                // 但二分法通常找到任意一個就停。我們這裡簡単処理：找到後先暫存，
                // 但如果我們想要「貪婪」匹配，需要在下面做額外判断。
                break
            } else if time < line.start {
                right = mid - 1
            } else {
                left = mid + 1
            }
        }

        if let idx = foundIndex {
            // ✅ 修正閃爍問題的関鍵邏輯：
            // 二分査找找到了 idx，但可能 idx+1 也同時満足条件（重畳）。
            // 由於我們採用「下一句優先」策略，這裡必須檢査 idx+1。
            var finalIndex = idx

            if finalIndex + 1 < captions.count {
                let nextLine = captions[finalIndex + 1]
                // 如果下一句也已経開始了，説明発生了重畳，強制選下一句
                if time >= nextLine.start {
                    finalIndex += 1
                }
            }

            currentCaptionIndex = finalIndex
            currentLineID = captions[finalIndex].id

        } else {
            // 没命中（在空隙中，或在開頭結尾之外）
            // 讓索引停留在「最接近的前一句」
            if right >= 0 && right < captions.count {
                currentCaptionIndex = right
                // 処於空隙時，你可以選択保留上一句高亮，或者 nil
                // currentLineID = captions[right].id
            } else {
                currentCaptionIndex = 0
                // 時間比第一句還早
                currentLineID = captions[0].id
            }
        }
    }

    @MainActor
    private func handleTimeUpdate(_ time: CMTime) {
        guard !self.isSeeking else { return }
        guard !captions.isEmpty else { return }

        let currentTime = time.seconds

        updateCaptionIndex(for: currentTime)
        let line = captions[currentCaptionIndex]

        if isLoopingSingleLine, let loopLine = lockedLoopLine {
            let loopEnd = CMTime(seconds: loopLine.end, preferredTimescale: 600)

            if currentTime >= loopLine.end {
                print("🔄 觸發回跳: \(loopLine)")
                isSeeking = true

                let seekTime = CMTime(
                    seconds: loopLine.start,
                    preferredTimescale: 600
                )

                player.seek(
                    to: seekTime,
                    toleranceBefore: .zero,
                    toleranceAfter: .zero
                ) { [weak self] _ in
                    guard let self else { return }

                    Task { @MainActor in
                        self.player.rate = self.rate
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        self.isSeeking = false
                    }
                }
            }

            if currentTime >= loopLine.start && currentTime < (loopLine.end + 0.5) {
                if currentLineID != loopLine.id {
                    currentLineID = loopLine.id
                }

                return
            }
        }

        if currentLineID != line.id {
            currentLineID = line.id
        }
    }
    private func setupTimeObserver() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }

            Task { @MainActor in
                self.handleTimeUpdate(time)
            }
        }
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

    private func observePlaybackState() {
        timeControlObserver = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            guard let self else { return }

            Task { @MainActor in
                switch player.timeControlStatus {
                    case .playing:
                        self.isPlaying = true

                        if abs(player.rate - self.rate) > 0.01 && self.rate > 0 {
                            self.player.rate = self.rate
                            print("▶️ 恢復播放，自動應用倍速: \(self.rate)")
                        }

                        self.updateNowPlayingPlaybackRate(self.rate)
                        self.setupNowPlaying()
                    case .paused:
                        self.isPlaying = false
                        self.updateNowPlayingPlaybackRate(0)
                    case .waitingToPlayAtSpecifiedRate:
                        break
                    @unknown default:
                        break
                }
            }
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

    func setRate(_ newRate: Float) {
        rate = newRate
        tempRate = newRate
        player.rate = newRate
        updateNowPlayingPlaybackRate(newRate)
    }
    private func observeRate() {
        rateObserver = player.observe(\.rate, options: [.new, .old]) { [weak self] player, change in
            guard let self else { return }
            let newRate = player.rate

            guard newRate > 0 else { return }

            if abs(newRate - 1.0) < 0.001 && abs(self.rate - 1.0) > 0.01 {
                print("🚨 系統試圖重置為 1.0，強行拉回至: \(self.rate)")
                DispatchQueue.main.async {
                    if self.player.rate != self.rate {
                        self.player.rate = self.rate
                    }
                }
                return
            }

            if abs(self.rate - newRate) > 0.01 {
                print("✅ 用戶手動同步倍速: \(newRate)")
                DispatchQueue.main.async {
                    self.rate = newRate
                    self.tempRate = newRate
                }
            }
        }
    }

    private func updateNowPlayingPlaybackRate(_ rate: Float) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[
            MPNowPlayingInfoPropertyPlaybackRate
        ] = rate
    }

    func playLine(_ line: CaptionLine) {
        seek(to: line.start + 0.01)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        self.player.rate = self.rate

        lockedLoopLine = line
        currentLineID = line.id
        let time = currentTimeFormatted(Int(line.start))
        print("🔄 手動切換循環目標: \(line)")
        print("time: \(time)")
    }

    func playPlayer() {
        player.rate = rate
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
        print("按鈕点撃：循環状態変更為 \(isLoopingSingleLine)")

        if isLoopingSingleLine {
            if captions.isEmpty {
                print("⚠️ 鎖定失敗：captions 数組目前是空的")
            }

            if let currentLine = captions.first(where: { $0.id == currentLineID }) {
                lockedLoopLine = currentLine
                print("lockedLoopLine: \(lockedLoopLine)")
                print("start: \(currentTimeFormatted(Int(lockedLoopLine!.start)))")
                print("📍 VM 内部鎖定循環行: \(currentLine.id)(範囲: \(currentLine.start)-\(currentLine.end))")
            } else {
                print("⚠️ 鎖定失敗：找不到與 currentLineID (\(currentLineID ?? nil)) 匹配的行")
            }
        } else {
            lockedLoopLine = nil
            print("🔓 已解除循環鎖定")
        }
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

    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        isSeeking = true
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard let self, finished else { return }

            Task { @MainActor in
                self.updateCaptionIndex(for: seconds, forceSearch: true)
                self.isSeeking = false
            }
        }
    }

    func currentLineText() -> String? {
        guard let id = currentLineID, let line = captions.first(where: { $0.id == id }) else { return nil }
        return line.text
    }
}

extension Notification.Name {
    static let scrollToCurrentLine = Notification.Name("scrollToCurrentLine")
}
