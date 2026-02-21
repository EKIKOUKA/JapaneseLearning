//
//  SettingsSheetView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/17.
//

import SwiftUI

struct SettingsSheetGrammarView: View {

    @Environment(SettingsStore.self) private var settingsStore
    @ObservedObject var store: GrammarStore

    let isoCountries: [(code: String, name: String)] = {
        let overrides: [String: String] = [
            "TW": "台湾（中華民国）",
            "CN": "中国（支那、西朝鮮）",
            "JP": "大日本帝国"
        ]

        return Locale.Region.isoRegions.compactMap { region in
            let code = region.identifier
            guard code.count == 2 else { return nil }
            let name = overrides[code] ?? Locale.current.localizedString(forRegionCode: code)
            if let name = name {
                return (code: code, name: name)
            }
            return nil
        }
    } ()

    var body: some View {
        @Bindable var settingsStoreBindable = settingsStore

        NavigationStack {

            Form {

                Section(header: Text("表示設定")) {

                    Toggle(isOn: $settingsStoreBindable.settings.showGrammarListAddButton) {
                        VStack(alignment: .leading) {
                            Text("新規追加ボタンを表示")
                            Text("文法リストに新規追加ボタンを表示する")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $settingsStoreBindable.settings.showGrammarEditorButton) {
                        VStack(alignment: .leading) {
                            Text("編集ボタンを表示")
                            Text("文法画面に編集ボタンを表示")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $settingsStoreBindable.settings.showGrammarListItemSwipeActions) {
                        VStack(alignment: .leading) {
                            Text("スワイプアクションを表示")
                            Text("文法リストにスワイプアクションを表示")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $settingsStoreBindable.settings.showGrammarListItemImportantImage) {
                        VStack(alignment: .leading) {
                            Text("重要アイコンを表示")
                            Text("文法リストに重要アイコンを表示")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $settingsStoreBindable.settings.showGrammarListCount) {
                        VStack(alignment: .leading) {
                            Text("件数を表示")
                            Text("文法リスト底に件数を表示する")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $settingsStoreBindable.settings.showGrammarListAllItemTag) {
                        VStack(alignment: .leading) {
                            Text("タグを表示")
                            Text("すべての文法リストにレベルタグを表示する")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(header: Text("機能設定"), footer: Text("文法リストの変更のRealtime機能を有効にする")) {

                    HStack {
                        Text("Realtimeの状態")
                        Spacer()
                        Text(store.isRealtimeConnected ? "接続中..." : "停止中")
                            .foregroundStyle(store.isRealtimeConnected ? .green : .secondary)
                    }

                    Button {
                        Task {
                            if store.isRealtimeConnected {
                                await store.stopRealtime()
                            } else {
                                store.startRealtime()
                            }
                        }
                    } label: {
                        Text(store.isRealtimeConnected ? "停止" : "開始")
                    }
                }

                Section(header: Text("国籍")) {
                    Picker("国籍", selection: $settingsStoreBindable.settings.Nationality) {
                        ForEach(isoCountries, id: \.code) { country in
                            Text(country.name).tag(country.code)
                        }
                    }
                }
            }
            .navigationTitle("日本語文法設定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
