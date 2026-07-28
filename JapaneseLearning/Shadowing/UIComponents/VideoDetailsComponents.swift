//
//  VideoDetailsComponents.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 7/20/R8.
//

import SwiftUI

struct videoCoverView: View {
    let playerVM: PlayerViewManager
    let sizeClass_regular: Bool

    var body: some View {
        if let image = playerVM.playerNowPlaying.nowPlayingArtwork {
            Canvas { context, size in
                context.draw(
                    Image(uiImage: image)
                        .resizable(),
                    in: CGRect(origin: .zero, size: size)
                )
            }
            .ignoresSafeArea()
            .blur(radius: sizeClass_regular ? 100 : 64, opaque: true)
            .overlay(Color.black.opacity(0.2))
        } else {
            Color.black.opacity(0.1)
        }
    }
}

struct playResumeVideoView: View {
    @Environment(PlayerViewManager.self) private var playerVM
    @Binding var drawerOffset: CGFloat
    @Binding var lastDragOffset: CGFloat
    let maxDrawerOffset: CGFloat

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.3, extraBounce: 0.2)) {
                drawerOffset = 0
                lastDragOffset = 0

                playerVM.requestScrollToCurrentLine()
            }
        } label: {
            Label("ビデオを表示", systemImage: "chevron.down")
                .font(.system(size: 16))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .foregroundColor(.primary.opacity(0.89))
        }
        .padding(.top, 5)
        .buttonStyle(.glass)
        .transition(
            .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.8)),
                removal: .opacity.combined(with: .scale(scale: 0.8))
            )
        )
    }
}

struct CustomToolbarHeader: View {
    let title: String
    @Binding var showSettingSheet: Bool

    var body: some View {
        ZStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.leading, 32)
                .padding(.trailing, 36)

            HStack {
                Spacer()

                Button {
                    showSettingSheet = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 54)
        .background(Color.clear)
    }
}

struct VideoControlView: View {
    let playerVM: PlayerViewManager

    var body: some View {
        @Bindable var playerVM = playerVM

        HStack {
            Button {
                playerVM.requestScrollToCurrentLine()
            } label: {
                Image(systemName: "scope")
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)

            PlaybackRateSliderView(
                rateValue: $playerVM.tempRate,
                minValue: 0.70,
                maxValue: 1.50,
                step: 0.05
            ) { rate in
                playerVM.setRate(rate)
            }

            Button(action: {
                playerVM.toggleSingleLineLoop()
            }) {
                Image(systemName: "repeat")
                    .foregroundColor(playerVM.isLoopingSingleLine ? .accentColor : .gray)
                    .contentShape(Rectangle())
                    .padding(.horizontal, 0)
            }
            .buttonStyle(.plain)
        }
    }
}

struct VideoSubtitleFontSizeSliderView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @State private var tempFontSize: Double = 1.0

    var body: some View {
        @Bindable var settingsStoreBindable = settingsStore

        HStack {
            Image(systemName: "textformat.size.smaller")
                .foregroundColor(.secondary)
                .onTapGesture {
                    if settingsStoreBindable.videoSubtitleFontSizeScale > 0.70 {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        let newValue = max(
                            settingsStoreBindable.videoSubtitleFontSizeScale - 0.05,
                            0.70
                        )
                        settingsStoreBindable.videoSubtitleFontSizeScale = newValue
                        tempFontSize = newValue
                    }
                }

            ZStack {
                GeometryReader { geo in
                    let minTempSizeScale: Double = 0.80
                    let maxTempSizeScale: Double = 1.20
                    let range = maxTempSizeScale - minTempSizeScale
                    let tempSizeScale = max(minTempSizeScale, min(maxTempSizeScale, tempFontSize))

                    let progress = (Double(tempSizeScale) - minTempSizeScale) / range
                    let thumbOffset = CGFloat(progress) * (geo.size.width - 30) + 15

                    let selectionFeedback = UISelectionFeedbackGenerator()

                    Slider(
                        value: $tempFontSize,
                        in: minTempSizeScale...maxTempSizeScale,
                        step: 0.05,
                        onEditingChanged: { editing in
                            if !editing {
                                settingsStoreBindable.videoSubtitleFontSizeScale = tempFontSize
                            }
                            if editing { selectionFeedback.prepare() }
                        }
                    )
                    .onChange(of: tempFontSize) { _, newValue in
                        if newValue == 1.0 {
                            selectionFeedback.selectionChanged()
                        }
                    }

                    Text(String(format: "%.2f", tempFontSize))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.9))
                        .position(x: thumbOffset, y: 15)
                        .allowsHitTesting(false)
                }
                .frame(height: 32)
            }

            Image(systemName: "textformat.size.larger")
                .foregroundColor(.secondary)
                .onTapGesture {
                    if settingsStoreBindable.videoSubtitleFontSizeScale < 1.40 {
                        let newValue = min(
                            settingsStoreBindable.videoSubtitleFontSizeScale + 0.05,
                            1.40
                        )
                        settingsStoreBindable.videoSubtitleFontSizeScale = newValue
                        tempFontSize = newValue
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
        }
        .onAppear {
            tempFontSize = settingsStoreBindable.videoSubtitleFontSizeScale
        }
        .onChange(of: settingsStoreBindable.videoSubtitleFontSizeScale) { _, newValue in
            if tempFontSize != newValue {
                tempFontSize = newValue
            }
        }
    }
}

struct DictionaryView: UIViewControllerRepresentable {
    let word: String

    func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
        return UIReferenceLibraryViewController(term: word)
    }

    func updateUIViewController(_ uiViewController: UIReferenceLibraryViewController, context: Context) {}
}

extension UnitPoint {
    static let subtitleAnchor = UnitPoint(x: 0.5, y: 0.2)
}
