//
//  VideoContentView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 5/4/R8.
//

import SwiftUI
import ActivityKit

struct VideoContentView: View {
    @Environment(AppNavigationStore.self) private var navigationStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.transitionNamespace) private var transitionNamespace
    @State private var videoPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $videoPath) {
            VideoListView()
                .navigationDestination(for: QuickActionTarget.self) { target in
                    if case .resumeVideo(let id) = target {
                        VideoDetailsView(videoID: id)
                            .ModifierApplyIf(
                                settingsStore.videoItemNavigationTransition &&
                                transitionNamespace != nil
                            ) { view in
                                view.navigationTransition(
                                    .zoom(
                                        sourceID: id,
                                        in: transitionNamespace!
                                    )
                                )
                            }
                    }
                }
        }
        .onChange(of: navigationStore.quickActionTarget) {_, target in
            guard let target else { return }

            if case .resumeVideo = target {
                videoPath.removeLast(videoPath.count)
                videoPath.append(target)

                navigationStore.clearTarget()
            }
        }
    }
}
