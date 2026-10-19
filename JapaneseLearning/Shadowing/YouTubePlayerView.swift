//
//  YouTubePlayerView.swift
//  JapaneseLearning
//
//  Temporary native SwiftUI test entry for the official YouTube IFrame Player.
//

import SwiftUI
import WebKit

struct YouTubeVideoContentArea: View {
    let videoID: String
    let playerManager: PlayerViewManager
    @Binding var playerStatus: String
    @Binding var drawerOffset: CGFloat
    @Binding var lastDragOffset: CGFloat
    let maxDrawerOffset: CGFloat
    let containerWidth: CGFloat
    let aspectRatio: CGFloat
    let isLandscape: Bool

    var body: some View {
        let videoWidth = max(0, isLandscape ? containerWidth * 0.5 : containerWidth)
        let baseHeight = max(0, videoWidth / aspectRatio)

        VStack(spacing: 0) {
            if isLandscape {
                Spacer()
            }

            ZStack {
                YouTubePlayerView(
                    videoID: videoID,
                    playerStatus: $playerStatus,
                    playerManager: playerManager
                )

                YouTubePlaybackOverlay(playerManager: playerManager)
            }
            .frame(width: videoWidth, height: baseHeight)
            .frame(
                height: isLandscape ? baseHeight : max(0, baseHeight - drawerOffset),
                alignment: .bottom
            )
            .background(Color.black)
            .clipped()

            if isLandscape {
                Spacer()
            }
        }
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

                    withAnimation(.snappy(duration: 0.25, extraBounce: 0.1)) {
                        drawerOffset = shouldCollapse ? baseHeight : 0
                    }
                    lastDragOffset = drawerOffset
                }
        )
    }
}

private struct YouTubePlaybackOverlay: View {
    let playerManager: PlayerViewManager
    @State private var controlsAreVisible = true
    @State private var autoHideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // This full-size layer stays above WKWebView even when the controls
            // are hidden, so taps never reach YouTube's own player controls.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !playerManager.isYouTubePlaybackWaiting else { return }
                    revealControls()
                }

            if playerManager.isYouTubePlaybackWaiting {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.black.opacity(0.16), in: Circle())
                    .overlay {
                        Circle().strokeBorder(.white.opacity(0.78), lineWidth: 1)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.88)))
            } else if controlsAreVisible {
                HStack(spacing: 20) {
                    controlButton(
                        systemName: "gobackward.10",
                        accessibilityLabel: "10秒戻る",
                        size: 50,
                        iconSize: 34
                    ) {
                        revealControls()
                        playerManager.seekForward(seconds: -10)
                    }

                    controlButton(
                        systemName: playerManager.isPlaying ? "pause.fill" : "play.fill",
                        accessibilityLabel: playerManager.isPlaying ? "一時停止" : "再生",
                        size: 72,
                        iconSize: 40
                    ) {
                        revealControls()
                        if playerManager.isPlaying {
                            playerManager.pausePlayer()
                        } else {
                            playerManager.playPlayer()
                        }
                    }

                    controlButton(
                        systemName: "goforward.10",
                        accessibilityLabel: "10秒進む",
                        size: 50,
                        iconSize: 34
                    ) {
                        revealControls()
                        playerManager.seekForward(seconds: 10)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.12), value: controlsAreVisible)
        .animation(.easeOut(duration: 0.12), value: playerManager.isYouTubePlaybackWaiting)
        .onAppear {
            if playerManager.isPlaying {
                scheduleAutoHide()
            }
        }
        .onChange(of: playerManager.isPlaying) { _, isPlaying in
            if isPlaying {
                scheduleAutoHide()
            } else {
                autoHideTask?.cancel()
                withAnimation(.easeOut(duration: 0.12)) {
                    controlsAreVisible = true
                }
            }
        }
        .onChange(of: playerManager.isYouTubePlaybackWaiting) { _, isWaiting in
            if isWaiting {
                autoHideTask?.cancel()
            } else if playerManager.isPlaying {
                scheduleAutoHide()
            }
        }
        .onDisappear {
            autoHideTask?.cancel()
        }
    }

    private func controlButton(
        systemName: String,
        accessibilityLabel: String,
        size: CGFloat,
        iconSize: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize))
                .foregroundStyle(Color.white)
                .frame(width: size, height: size)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(accessibilityLabel)
    }

    private func revealControls() {
        autoHideTask?.cancel()
        withAnimation(.easeOut(duration: 0.12)) {
            controlsAreVisible = true
        }

        if playerManager.isPlaying {
            scheduleAutoHide()
        }
    }

    private func scheduleAutoHide() {
        autoHideTask?.cancel()
        autoHideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.8))
            guard !Task.isCancelled,
                  playerManager.isPlaying,
                  !playerManager.isYouTubePlaybackWaiting else {
                return
            }

            withAnimation(.easeOut(duration: 0.12)) {
                controlsAreVisible = false
            }
        }
    }
}

struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    @Binding var playerStatus: String
    let playerManager: PlayerViewManager?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            playerStatus: $playerStatus,
            playerManager: playerManager
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = [.audio, .video]
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.add(
            context.coordinator,
            name: Coordinator.messageHandlerName
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.allowsBackForwardNavigationGestures = false

        context.coordinator.webView = webView
        context.coordinator.loadedVideoID = videoID
        playerManager?.attachYouTubeController(context.coordinator)
        loadPlayer(in: webView, videoID: videoID)
        
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedVideoID != videoID else { return }

        context.coordinator.loadedVideoID = videoID
        loadPlayer(in: webView, videoID: videoID)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.pause()
        coordinator.playerManager?.detachYouTubeController(coordinator)
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: Coordinator.messageHandlerName
        )
        webView.navigationDelegate = nil
    }

    private func loadPlayer(in webView: WKWebView, videoID: String) {
        // YouTube requires an identifiable HTTP Referer for embedded players.
        // For a bundled local HTML page, loadHTMLString(baseURL:) supplies it.
        let bundleID = Bundle.main.bundleIdentifier?.lowercased()
            ?? "com.example.japaneselearning"
        let appOrigin = "https://\(bundleID)"
        let baseURL = URL(string: appOrigin)!

        webView.loadHTMLString(
            Self.html(videoID: videoID, origin: appOrigin),
            baseURL: baseURL
        )
    }

    private static func html(videoID: String, origin: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
          <style>
            html, body, #player {
              width: 100%;
              height: 100%;
              margin: 0;
              padding: 0;
              overflow: hidden;
              background: #000;
            }
          </style>
        </head>
        <body>
          <div id="player"></div>
          <script>
            const nativeHandler = window.webkit.messageHandlers.youtubePlayer;

            function send(type, value) {
              nativeHandler.postMessage({ type: type, value: String(value ?? '') });
            }

            const apiScript = document.createElement('script');
            apiScript.src = 'https://www.youtube.com/iframe_api';
            apiScript.onerror = function() { send('error', 'iframe_api_load_failed'); };
            document.head.appendChild(apiScript);

            let player;
            function onYouTubeIframeAPIReady() {
              player = new YT.Player('player', {
                width: '100%',
                height: '100%',
                videoId: '\(videoID)',
                playerVars: {
                  playsinline: 1,
                  controls: 0,
                  origin: '\(origin)'
                },
                events: {
                  onReady: function(event) {
                    send('ready', event.target.getDuration());
                    window.youtubeProgressTimer = window.setInterval(function() {
                      if (!player || typeof player.getCurrentTime !== 'function') return;
                      send('time', player.getCurrentTime() + ',' + player.getDuration());
                    }, 250);
                  },
                  onStateChange: function(event) { send('state', event.data); },
                  onPlaybackRateChange: function(event) { send('rate', event.data); },
                  onError: function(event) { send('error', event.data); }
                }
              });
            }
          </script>
        </body>
        </html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, YouTubePlayerControlling {
        static let messageHandlerName = "youtubePlayer"

        @Binding private var playerStatus: String
        weak var playerManager: PlayerViewManager?
        weak var webView: WKWebView?
        var loadedVideoID: String?

        init(
            playerStatus: Binding<String>,
            playerManager: PlayerViewManager?
        ) {
            _playerStatus = playerStatus
            self.playerManager = playerManager
        }

        func play() {
            evaluate("if (player && player.playVideo) { player.playVideo(); }")
        }

        func pause() {
            evaluate("if (player && player.pauseVideo) { player.pauseVideo(); }")
        }

        func seek(to seconds: Double) {
            evaluate("if (player && player.seekTo) { player.seekTo(\(seconds), true); }")
        }

        func setPlaybackRate(_ rate: Float) {
            evaluate(
                """
                if (player && player.getAvailablePlaybackRates) {
                  const rates = player.getAvailablePlaybackRates();
                  if (rates.length > 0) {
                    const requested = \(rate);
                    const closest = rates.reduce(function(best, item) {
                      return Math.abs(item - requested) < Math.abs(best - requested) ? item : best;
                    }, rates[0]);
                    player.setPlaybackRate(closest);
                    send('rate', closest);
                  }
                }
                """
            )
        }

        private func evaluate(_ script: String) {
            webView?.evaluateJavaScript(script)
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == Self.messageHandlerName,
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String else {
                return
            }

            let value = body["value"] as? String ?? ""

            switch type {
                case "ready":
                    playerStatus = "Ready — tap the YouTube play button"
                    playerManager?.youtubePlayerDidBecomeReady(
                        duration: Double(value) ?? 0
                    )
                case "state":
                    playerStatus = Self.description(forPlayerState: value)
                    playerManager?.youtubePlayerDidChangeState(Int(value) ?? -1)
                case "rate":
                    if let rate = Float(value) {
                        playerManager?.youtubePlayerDidChangeRate(rate)
                    }
                case "time":
                    let values = value.split(separator: ",", maxSplits: 1)
                    if let first = values.first,
                       let time = Double(first) {
                        let duration = values.count > 1
                            ? Double(values[1]) ?? 0
                            : 0
                        playerManager?.youtubePlayerDidUpdateTime(
                            time,
                            duration: duration
                        )
                    }
                case "error":
                    playerStatus = Self.description(forError: value)
                default:
                    playerStatus = "YouTube message: \(type) \(value)"
            }
        }

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            self.webView = webView
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            playerStatus = "WebView error: \(error.localizedDescription)"
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            playerStatus = "Network error: \(error.localizedDescription)"
        }

        private static func description(forPlayerState value: String) -> String {
            switch value {
                case "-1": "Unstarted"
                case "0": "Ended"
                case "1": "Playing"
                case "2": "Paused"
                case "3": "Buffering…"
                case "5": "Video cued"
                default: "Player state: \(value)"
            }
        }

        private static func description(forError value: String) -> String {
            switch value {
                case "2": "YouTube error 2: invalid video ID"
                case "5": "YouTube error 5: HTML5 player failed"
                case "100": "YouTube error 100: video unavailable"
                case "101", "150": "YouTube error \(value): embedding is disabled"
                case "153": "YouTube error 153: missing app identity / Referer"
                default: "YouTube error: \(value)"
            }
        }
    }
}

struct YouTubePlayerDebugView: View {
    private let videoID = "M7lc1UVf-VE"
    @State private var playerStatus = "Loading YouTube player…"

    var body: some View {
        VStack(spacing: 20) {
            Text("YouTube Player Test")
                .font(.title2.bold())

            YouTubePlayerView(
                videoID: videoID,
                playerStatus: $playerStatus,
                playerManager: nil
            )
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(playerStatus)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Fixed video ID: \(videoID)")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

#Preview {
    YouTubePlayerDebugView()
}
