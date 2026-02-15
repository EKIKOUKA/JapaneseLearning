//
//  ShadowingSettingsSheetView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/27.
//

import SwiftUI

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

                Section(header: Text("ビデオテキストサイズ")) {
                    VideoSubtitleFontSizeSliderView()
                }

                Section(header: Text("ビデオテキストの表示")) {
                    Toggle(isOn: $settingsStoreBindable.settings.videoSubtitleDimInactiveLines) {
                        VStack(alignment: .leading) {
                            Text("非表示行を目立たせない")
                            Text("再生中の行を見やすい強調して表示する、他の字幕を弱めます")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
            }
            .navigationTitle("シャドーイング設定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
