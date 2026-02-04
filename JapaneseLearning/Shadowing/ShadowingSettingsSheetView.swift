//
//  ShadowingSettingsSheetView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/27.
//

import SwiftUI

//enum VideoResolveStrategy: String, Codable, CaseIterable {
//    case YouTubeKit
//    case yt_dlp
//
//    var displayName: String {
//        switch self {
//            case .yt_dlp: return "yt-dlp（サーバで）"
//            case .YouTubeKit: return "YouTubeKit（携帯で）"
//        }
//    }
//}

enum VideoSubtitleLineWithAnimation: String, Codable, CaseIterable {
    case easeInOut
    case spring

    var displayName: String {
        switch self {
            case .easeInOut: return "スムーズ"
            case .spring: return "弾む"
        }
    }
}

struct ShadowingSettingsSheetView: View {

    @Environment(SettingsStore.self) private var settingsStore
    var playerVM: PlayerViewModel?

    var body: some View {
        @Bindable var settingsStoreBindable = settingsStore

        NavigationStack {

            Form {

                if let player_vm = playerVM {
                    Section(header: Text("ビデオコントロール")) {
                        VideoControlView(playerVM: player_vm)
                    }
                }

                Section(header: Text("スクロールのアニメーション")) {
                    Picker("アニメーション", selection: $settingsStoreBindable.settings.videoSubtitleLineWithAnimation) {
                        ForEach(VideoSubtitleLineWithAnimation.allCases, id: \.self) { animation in
                            Text(animation.displayName).tag(animation)
                        }
                    }
                }

                Section(header: Text("表示設定")) {

                    Toggle(isOn: $settingsStoreBindable.settings.showShadowingSubtitlesRuby) {
                        VStack(alignment: .leading) {
                            Text("振り仮名を表示")
                            Text("漢字の上に平仮名を表示する")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                /* Section(header: Text("YouTubeビデオ解析方法")) {
                    Picker("解析方法", selection: $settingsStoreBindable.settings.showVideoResolveStrategyPicker) {
                        ForEach(VideoResolveStrategy.allCases, id: \.self) { strategy in
                            Text(strategy.displayName).tag(strategy)
                        }
                    }
                } */
            }
            .navigationTitle("シャドーイング設定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
