//
//  ContentLanguageSelectView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 5/30/R8.
//

import SwiftUI

struct ContentVideoUploadOptionsView: View {
    @State private var selectedLanguage: VideoContentLanguage = .ja
    @State private var createCaptionByAi: Bool = false
    @State private var playbackRate: Float = 1.0

    let onConfirm: (VideoContentLanguage, Bool, Float) -> Void

    var body: some View {
        Form {
            Section(footer: Text("動画の言語を選択しましょう")) {
                Picker("動画の言語", selection: $selectedLanguage) {
                    ForEach(VideoContentLanguage.allCases, id: \.self) { language in
                        Text(language.displayName)
                            .tag(language)
                    }
                }
            }
            Section(footer: Text("動画の再生速度を調整しましょう")) {
                PlaybackRateSliderView(
                    rateValue: $playbackRate,
                    minValue: 0.50,
                    maxValue: 1.50,
                    step: 0.05
                )
            }
            Section(footer: Text("人工字幕が無い場合、AIを使って字幕を生成します")) {
                Toggle(isOn: $createCaptionByAi) {
                    Text("AIを使って字幕を生成します")
                }
            }
        }
        .navigationTitle("動画のアップロード設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    onConfirm(selectedLanguage, createCaptionByAi, playbackRate)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
}
