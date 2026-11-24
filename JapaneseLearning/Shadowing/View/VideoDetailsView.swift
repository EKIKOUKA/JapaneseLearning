//
//  VideoDetailsView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/22.
//

import SwiftUI
import AVKit

struct VideoDetailsView: View {
    @Environment(AppleAccountStore.self) private var accountStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(VideoStore.self) private var videoStore
    @Environment(PlayerViewManager.self) private var playerVM
    @Environment(\.horizontalSizeClass) var sizeClass

    let videoID: String
    var onDismissDragChanged: (CGFloat) -> Void = { _ in }
    var onDismissDragEnded: (CGFloat, CGFloat) -> Void = { _, _ in }
    var video: VideoItem? {
        videoStore.videos.first { $0.id == videoID }
    }
    @State private var showSettingSheet = false
    @State private var showDictionarySheet = false
    @State private var drawerOffset: CGFloat = 0
    @State private var lastDragOffset: CGFloat = 0

    @State private var youtubePlayerStatus = "Loading YouTube player…"

    private var displayAspectRatio: CGFloat {
        guard let ratio = video?.aspectRatio, ratio > 0 else {
            return 16.0 / 9.0
        }

        return ratio
    }

    var body: some View {
        @Bindable var playerVM = playerVM
        let sizeClassRegular = sizeClass == .regular

        GeometryReader { geo in
            let fullWidth = geo.size.width
            let isLandscape = geo.size.width > geo.size.height
            let usesSideBySide = isLandscape
            let videoLeadingInset: CGFloat = isLandscape ? 16 : 0
            let videoContainerWidth = usesSideBySide
                ? max(0, fullWidth * 0.5 - videoLeadingInset)
                : fullWidth
            let videoWidth = videoContainerWidth
            let currentVideoHeight = videoWidth / displayAspectRatio
            let layout = usesSideBySide
                ? AnyLayout(HStackLayout(spacing: 0))
                : AnyLayout(VStackLayout(spacing: 0))

            Group {
                if video == nil {
                    Color.clear.frame(height: 10)
                } else {
                    ZStack(alignment: .top) {
                        layout {
                            Group {
                                if playerVM.activePlaybackUsesYouTube {
                                    YouTubeVideoContentArea(
                                        videoID: videoID,
                                        playerManager: playerVM,
                                        playerStatus: $youtubePlayerStatus,
                                        drawerOffset: $drawerOffset,
                                        lastDragOffset: $lastDragOffset,
                                        maxDrawerOffset: currentVideoHeight,
                                        containerWidth: videoContainerWidth,
                                        aspectRatio: displayAspectRatio,
                                        isLandscape: usesSideBySide
                                    )
                                } else {
                                    VideoContentArea(
                                        playerVM: playerVM,
                                        videoID: videoID,
                                        drawerOffset: $drawerOffset,
                                        lastDragOffset: $lastDragOffset,
                                        maxDrawerOffset: currentVideoHeight,
                                        containerWidth: videoContainerWidth,
                                        aspectRatio: displayAspectRatio,
                                        isLandscape: usesSideBySide,
                                        isPlayerReady: playerVM.currentVideoItem?.id == videoID && !playerVM.isVideoLoading
                                    )
                                }
                            }
                            .padding(.leading, videoLeadingInset)
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 8, coordinateSpace: .global)
                                    .onChanged { value in
                                        guard value.translation.height > 0 else { return }
                                        onDismissDragChanged(value.translation.height)
                                    }
                                    .onEnded { value in
                                        onDismissDragEnded(
                                            value.translation.height,
                                            value.predictedEndTranslation.height
                                        )
                                    }
                            )

                            if playerVM.isProgressing {
                                Spacer()
                                ProgressLoadingView()
                                Spacer()
                            } else if playerVM.currentLineID != nil {
                                SubtitlesContentView(playerVM: playerVM)
                            } else {
                                Color.clear
                            }
                        }

                        if !usesSideBySide, drawerOffset >= currentVideoHeight {
                            playResumeVideoView(
                                drawerOffset: $drawerOffset,
                                lastDragOffset: $lastDragOffset,
                                maxDrawerOffset: currentVideoHeight
                            )
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            CustomToolbarHeader(
                title: video?.title.cleanedVideoTitle ?? "読み込み中...",
                video: video,
                playerVM: playerVM,
                showSettingSheet: $showSettingSheet
            )
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .toolbarVisibility(.hidden, for: .tabBar)
        .task(id: video?.id) {
            guard let video else { return }
            playerVM.startVideo(video)
        }
        .onChange(of: settingsStore.useNativeVideoPlayer) { _, _ in
            guard let video else { return }
            playerVM.startVideo(video)
        }
        .onChange(of: playerVM.activeLookUpWordIdentifiable?.id) { _, newID in
            guard newID != nil else { return }
            showDictionarySheet = true
        }
        .sheet(isPresented: $showDictionarySheet,
               onDismiss: {
            playerVM.activeLookUpWordIdentifiable = nil
            playerVM.playPlayer()
        }) {
            DictionaryView(word: playerVM.activeLookUpWordIdentifiable?.word ?? "")
                .ignoresSafeArea()
                .presentationDetents(sizeClassRegular ? [.large] : [.medium, .large])
                .presentationDragIndicator(sizeClassRegular ? .hidden : .visible)
        }
        .sheet(isPresented: $showSettingSheet) {
            ShadowingSettingsSheetView(playerVM: playerVM)
                .presentationDetents(sizeClassRegular ? [.large] : [.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $playerVM.activeAIQuestion, onDismiss: {
            playerVM.playPlayer()
        }) { question in
            AIExplanationView(question: question)
                .environment(settingsStore)
                .environment(accountStore)
                .presentationDetents(question.mode == .sentence ? [.large] : [.medium])
        }
    }
}

struct VideoContentArea: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(SettingsStore.self) private var settingsStore
    let playerVM: PlayerViewManager
    let videoID: String
    @Binding var drawerOffset: CGFloat
    @Binding var lastDragOffset: CGFloat
    let maxDrawerOffset: CGFloat
    let containerWidth: CGFloat
    let aspectRatio: CGFloat
    let isLandscape: Bool
    let isPlayerReady: Bool

    var body: some View {
        let videoWidth = max(0, containerWidth)
        let baseHeight = max(0, videoWidth / aspectRatio)

        VStack(spacing: 0) {
            if isLandscape {
                Spacer()
            }

            ZStack {
                if let image = playerVM.playerNowPlaying.nowPlayingArtwork {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: videoWidth, height: baseHeight)
                        .clipped()
                        .opacity(drawerOffset >= maxDrawerOffset ? 0 : 1)
                        .allowsHitTesting(false)
                } else {
                    Color.black.opacity(0.1)
                }

                AVPlayerControllerView(controller: playerVM.nativePlayerController(for: videoID))
                    .opacity(isPlayerReady ? 1 : 0)
                    .animation(.easeInOut(duration: 1), value: isPlayerReady)
                    .opacity(drawerOffset >= maxDrawerOffset ? 0 : 1)
            }
            .frame(width: videoWidth, height: baseHeight)
            .frame(
                height: isLandscape ? baseHeight : max(0, baseHeight - drawerOffset),
                alignment: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: isLandscape ? 16 : 0, style: .continuous))

            if isLandscape {
                Spacer()
            }
        }
        .background(Color.clear)
        .padding(.bottom, 2)
        .highPriorityGesture(
            isLandscape ? nil :
                DragGesture()
                .onChanged { value in
                    let offset = lastDragOffset - value.translation.height
                    drawerOffset = min(max(offset, 0), baseHeight)
                }
                .onEnded { _ in
                    let shouldCollapse = drawerOffset > baseHeight * 0.25

                    if shouldCollapse {
                        withAnimation(.snappy(duration: 0.25, extraBounce: 0.0)) {
                            drawerOffset = baseHeight
                        }
                    } else {
                        withAnimation(.snappy(duration: 0.25, extraBounce: 0.15)) {
                            drawerOffset = 0
                        }
                    }

                    lastDragOffset = drawerOffset
                }
        )
    }
}

// 実際のスクロール軌跡を、字幕行ごとに時間をずらして再現する。

struct SubtitlesContentView: View {
    private struct VisibleCaptionRow: Identifiable {
        let index: Int
        let line: CaptionLine
        let position: Int

        var id: String { line.id }
    }

    let playerVM: PlayerViewManager
    @Environment(SettingsStore.self) private var settingsStore
    @State private var scrollPosition = ScrollPosition(idType: String.self)
    @State private var scrollPhase: ScrollPhase = .idle
    @State private var returnToCurrentLineTask: Task<Void, Never>?
    @State private var isUserScrolling = false
    @State private var isScrollIdle = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // 再生中の行より下では、スクロール方向に関係なく 1 行ごとに遅らせる。
    @State private var scrollHistory = ScrollOffsetHistory()
    @State private var isLagRunning = false
    @State private var lagTask: Task<Void, Never>?
    @State private var isLagMovingBackward = false

    private let scrollDuration = 0.5 // 自動スクロールの所要時間
    private let lagStep = 0.05       // 1 行ごとに加える遅延（秒）0.035
    private let lagMaxRows = 8       // この行数に達したら遅延の加算を止める

    private var effectiveLagStep: Double {
        lagStep * (isLagMovingBackward ? 0.5 : 1)
    }

    var body: some View {
        let showShadowingSubtitlesRuby = settingsStore.showShadowingSubtitlesRuby
        let fontSizeScale = settingsStore.videoSubtitleFontSizeScale
        let fontStyle = settingsStore.videoSubtitleFontStyle
        let fontColor = settingsStore.videoSubtitleFontUIColor
        let visibleCaptions = playerVM.visiableCaptions
        let visibleRows = visibleCaptions.enumerated().map { position, caption in
            VisibleCaptionRow(index: caption.0, line: caption.1, position: position)
        }
        let activePosition = visibleRows.firstIndex { $0.id == playerVM.currentLineID }

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: 10)
                ForEach(visibleRows) { row in
                    SubtitlesRowView(
                        playerVM: playerVM,
                        line: row.line,
                        isActive: playerVM.currentLineID == row.line.id,
                        rubyRanges: showShadowingSubtitlesRuby ? row.line.rubyRanges : [],
                        fontSizeScale: fontSizeScale,
                        fontStyle: fontStyle,
                        fontColor: fontColor,
                        isUserScrolling: isUserScrolling,
                        blurRadius: subtitleBlurRadius(for: row.position, activePosition: activePosition),
                        karaokeEffectsEnabled: settingsStore.videoSubtitleKaraokeEffects,
                        onTapLine: {
                            Task {
                                await playerVM.playLine(row.line, row.index)
                            }
                        }
                    )
                    .equatable()
                    .scrollLag(
                        history: scrollHistory,
                        delay: lagDelay(for: row.position, activePosition: activePosition),
                        isRunning: isLagRunning
                    )
                }
                Color.clear.frame(height: 500)
            }
            .scrollTargetLayout()
        }
        .environment(\.colorScheme, .dark)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .scrollPosition($scrollPosition, anchor: .subtitleAnchor)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, newValue in
            scrollHistory.record(newValue)
        }
        .onScrollPhaseChange { _, newPhase in
            scrollPhase = newPhase

            switch newPhase {
                case .tracking, .interacting, .decelerating:
                    returnToCurrentLineTask?.cancel()
                    stopLag()
                    isUserScrolling = true
                    isScrollIdle = false

                case .idle:
                    guard isUserScrolling else { return }
                    isScrollIdle = true

                case .animating:
                    break
            }
        }
        .task(id: isScrollIdle) {
            guard isScrollIdle, isUserScrolling else { return }

            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, isScrollIdle, scrollPhase == .idle else { return }

            defer { isUserScrolling = false }
            guard playerVM.isPlaying,
                  let currentLineID = playerVM.currentLineID else {
                return
            }

            scroll(to: currentLineID)
        }
        .task {
            if let currentLineID = playerVM.currentLineID {
                scrollPosition.scrollTo(id: currentLineID, anchor: .subtitleAnchor)
            }
        }
        .onChange(of: playerVM.scrollToCurrentLineRequest) {
            returnToCurrentLineTask?.cancel()
            stopLag()
            returnToCurrentLineTask = Task {
                try? await Task.sleep(for: .seconds(0.1))
                
                guard !Task.isCancelled,
                      scrollPhase == .idle || scrollPhase == .animating,
                      let currentLineID = playerVM.currentLineID else { return }

                isUserScrolling = false
                isScrollIdle = false
                scroll(to: currentLineID)
            }
        }
        .onDisappear {
            returnToCurrentLineTask?.cancel()
            stopLag()
        }
        .onChange(of: reduceMotion) { _, enabled in
            if enabled { stopLag() }
        }
        .onChange(of: playerVM.currentLineID) { old, new in
            guard playerVM.isPlaying,
                  !isUserScrolling,
                  let newID = new else {
                return
            }

            // 前後の隣接行への移動では、下側の字幕を順番に追従させる。
            if let previous = visibleRows.firstIndex(where: { $0.id == old }),
               let current = visibleRows.firstIndex(where: { $0.id == newID }),
               abs(current - previous) == 1,
               !reduceMotion {
                isLagMovingBackward = current < previous
                startLag()
            } else {
                stopLag()
            }
            scroll(to: newID)
        }
    }

    private func subtitleBlurRadius(for position: Int, activePosition: Int?) -> CGFloat {
        let previousBlur: CGFloat = 2 // 現在行より上の字幕
        let blurStep: CGFloat = 1     // 下側の字幕 1 行ごとの増加量
        let maximumBlur: CGFloat = 4  // 下側の字幕の上限

        guard let activePosition else { return 0 }
        let distance = position - activePosition
        if (-3 ... -1).contains(distance) { return previousBlur }
        guard (1...10).contains(distance) else { return 0 }
        
        return min(CGFloat(distance) * blurStep, maximumBlur)
    }

    /// 後退時は現在行と直下の行を同じ遅延にし、両者が重ならないようにする。
    private func lagDelay(for position: Int, activePosition: Int?) -> Double {
        guard let activePosition else { return 0 }

        let distance = position - activePosition
        let delaySteps: Int
        if isLagMovingBackward {
            // 上側も現在行と一緒に追従させ、下側ほど先に動かす。
            delaySteps = min(max(lagMaxRows - distance + 1, 0), lagMaxRows)
        } else {
            delaySteps = min(max(distance, 0), lagMaxRows)
        }

        return Double(delaySteps) * effectiveLagStep
    }

    private func startLag() {
        lagTask?.cancel()
        if !isLagRunning { scrollHistory.reset() }
        isLagRunning = true

        let total = scrollDuration + effectiveLagStep * Double(lagMaxRows) + 0.15
        lagTask = Task {
            try? await Task.sleep(for: .seconds(total))
            guard !Task.isCancelled else { return }

            isLagRunning = false
        }
    }

    private func stopLag() {
        lagTask?.cancel()
        isLagRunning = false
    }

    private func scroll(to lineID: String) {
        withAnimation(.timingCurve(0.4, 0.0, 0.2, 1.0, duration: scrollDuration)) {
            scrollPosition.scrollTo(id: lineID, anchor: .subtitleAnchor)
        }
    }
}

private struct SubtitlesRowView: View, Equatable {
    @Environment(\.scenePhase) private var scenePhase

    static func == (lhs: SubtitlesRowView, rhs: SubtitlesRowView) -> Bool {
        lhs.line == rhs.line &&
        lhs.isActive == rhs.isActive &&
        lhs.rubyRanges == rhs.rubyRanges &&
        lhs.fontSizeScale == rhs.fontSizeScale &&
        lhs.fontStyle == rhs.fontStyle &&
        lhs.fontColor == rhs.fontColor &&
        lhs.isUserScrolling == rhs.isUserScrolling &&
        lhs.blurRadius == rhs.blurRadius &&
        lhs.karaokeEffectsEnabled == rhs.karaokeEffectsEnabled
    }

    let playerVM: PlayerViewManager
    let line: CaptionLine
    let isActive: Bool
    let rubyRanges: [RubyWordRange]
    let fontSizeScale: Double
    let fontStyle: VideoSubtitleRubyFontStyle
    let fontColor: UIColor
    let isUserScrolling: Bool
    let blurRadius: CGFloat
    let karaokeEffectsEnabled: Bool
    let onTapLine: () -> Void

    @State private var tapHighlight = false

    var body: some View {
        // 行内に異なる開始時刻がなければ、行全体を一度に強調する。
        let timedSegments = (karaokeEffectsEnabled ? line.segments : nil)?.filter {
            $0.start.isFinite && $0.end.isFinite && $0.end > $0.start &&
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } ?? []
        let supportsKaraokeEffects = Set(timedSegments.map(\.start)).count > 1
        let hasFragmentTiming = isActive && supportsKaraokeEffects
        let usesKeyframes = KaraokeLayerRenderer.isEnabled && KaraokeLayerRenderer.usesKeyframes &&
            !playerVM.activePlaybackUsesYouTube

        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(tapHighlight ? 0.15 : 0))
                .padding(.horizontal, 10)

            // 描画更新時にプレーヤーの時刻を読み、再生速度の変更やシークに追従する。
            TimelineView(.animation(
                minimumInterval: usesKeyframes ? 0.1 : nil,
                paused: scenePhase != .active || !hasFragmentTiming || (!usesKeyframes && !playerVM.isPlaying)
            )) { _ in
                RubyLabel(
                    text: line.text,
                    rubyRanges: rubyRanges,
                    fontSizeScale: fontSizeScale,
                    fontStyle: fontStyle,
                    fontColor: karaokeEffectsEnabled ? fontColor : .white,
                    karaokeSegments: hasFragmentTiming ? line.segments : nil,
                    karaokeTime: hasFragmentTiming ? playerVM.playbackCurrentTime : 0,
                    karaokeAnimationRate: usesKeyframes && hasFragmentTiming
                        ? (scenePhase == .active && playerVM.isPlaying && playerVM.player.timeControlStatus == .playing ? playerVM.player.rate : 0)
                        : nil,
                    onTapWord: { word in
                        if isActive {
                            playerVM.handleWordLookup(word)
                        } else {
                            triggerHighlight()
                            onTapLine()
                        }
                    },
                    onTapLine: {
                        triggerHighlight()
                        onTapLine()
                    }
                )
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .blur(radius: isActive || isUserScrolling || !playerVM.isPlaying ? 0 : blurRadius)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isActive)
            .opacity(isActive ? 1.0 : 0.4)
            .scaleEffect(tapHighlight ? 0.96 : 1.0, anchor: .center)
            .animation(tapHighlight ? .easeOut(duration: 0.1) : .spring(response: 0.4, dampingFraction: 0.6), value: tapHighlight)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                playerVM.showAIExplanation(line.text, mode: .sentence)
            } label: {
                Label("AI 解説", systemImage: "sparkles")
            }
        }
    }

    private func triggerHighlight() {
        withAnimation(.easeOut(duration: 0.08)) {
            tapHighlight = true
        }

        Task {
            try? await Task.sleep(for: .seconds(0.2))

            withAnimation(.easeInOut(duration: 0.5)) {
                tapHighlight = false
            }
        }
    }
}
