//
//  ShadowingSettingsSheetView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/27.
//

import SwiftUI

struct ShadowingSettingsSheetView: View {

    @Environment(SettingsStore.self) private var settingsStore
    var playerVM: PlayerViewModel?

    var body: some View {
        @Bindable var settingsStoreBindable = settingsStore

        NavigationStack {

            Form {

                if let player_vm = playerVM {
                    Section(header: Text("動画の再生コントロール")) {
                        VideoControlView(playerVM: player_vm)
                    }
                }

                Section(header: Text("動画字幕のサイズ")) {
                    VideoSubtitleFontSizeSliderView()
                }

                Section(header: Text("字幕のフォント")) {
                    Picker("フォント", selection: $settingsStoreBindable.settings.videoSubtitleFontStyle) {
                        ForEach(VideoSubtitleRubyFontStyle.allCases, id: \.self) { fontStyle in
                            Text(fontStyle.displayName).tag(fontStyle)
                        }
                    }
                }

                Section(header: Text("動画字幕表示の強調")) {
                    Toggle(isOn: $settingsStoreBindable.settings.videoSubtitleDimInactiveLines) {
                        VStack(alignment: .leading) {
                            Text("非表示行を目立たせない")
                            Text("再生中の行を見やすい強調して表示する、他の字幕を弱めます")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(header: Text("スクロールアニメーション")) {
                    Picker("アニメーション", selection: $settingsStoreBindable.settings.videoSubtitleLineWithAnimation) {
                        ForEach(VideoSubtitleLineWithAnimation.allCases, id: \.self) { animation in
                            Text(animation.displayName).tag(animation)
                        }
                    }
                }

                Section(header: Text("振り仮名の表示")) {

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
