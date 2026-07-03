//
//  ShadowingMiniPlayerView.swift
//  JapaneseLearning
//
//  Created by Codex on 2026/06/30.
//

import SwiftUI
import AVFoundation

struct ShadowingMiniPlayerView: View {
    @Environment(AppNavigationStore.self) private var navigationStore
    @Environment(PlayerViewManager.self) private var playerVM
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.transitionNamespace) private var transitionNamespace
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        if let video = playerVM.currentVideoItem, playerVM.player.currentItem != nil {
            HStack(spacing: 0) {
                miniArtwork

                Text(video.title.cleanedVideoTitle)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)

                Button {
                    if playerVM.isPlaying {
                        playerVM.pausePlayer()
                    } else {
                        playerVM.playPlayer()
                    }
                } label: {
                    Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(PressScaleButtonStyle())

                if placement == .expanded {
                    Button {
                        if playerVM.isPlaying {
                            playerVM.seekForward()
                        }
                    } label: {
                        Image(systemName: "10.arrow.trianglehead.clockwise")
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
            .ModifierApplyIf(
                settingsStore.videoItemNavigationTransition &&
                transitionNamespace != nil &&
                playerVM.currentVideoItem != nil
            ) { view in
                view.matchedTransitionSource(
                    id: playerVM.currentVideoItem!.id,
                    in: transitionNamespace!
                )
            }
            .onTapGesture {
                navigationStore.selectedTab = 0
                navigationStore.quickActionTarget = .resumeVideo(id: video.id)
            }
            .padding(.leading, 14)
            .padding(.trailing, 6)
        }
    }

    private var miniArtwork: some View {
        Group {
            if let artwork = playerVM.nowPlayingArtwork {
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: 56, height: 32)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
