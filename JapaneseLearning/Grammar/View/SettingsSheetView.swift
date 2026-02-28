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

    func folderSize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [],
            errorHandler: nil
        ) else { return 0 }

        var total: Int64 = 0

        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }

        return total
    }

    func getAppStorageSize() -> Int64 {
//        let fileManager = FileManager.default
//        let urls: [URL?] = [
//            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
//            fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first,
//            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
//            fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first,
//            URL(fileURLWithPath: NSTemporaryDirectory())
//        ]

//        return urls.compactMap { $0 }.reduce(0) { total, url in
//            total + folderSize(at: url)
//        }

        let homeURL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return folderSize(at: homeURL)
    }

    func formattedStorageSize(_ bytes: Int64) -> String {
        if bytes <= 0 {
            return "0 KB"
        }

        let kb = Double(bytes) / 1024
        let mb = kb / 1024

        if mb >= 1 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.0f KB", kb)
        }
    }

    var body: some View {
        @Bindable var settingsStoreBindable = settingsStore

        @State var storageBytes = getAppStorageSize()

        NavigationStack {

            Form {

                Section(header: Text("表示設定")) {

                    Toggle(isOn: $settingsStoreBindable.showGrammarListAddButton) {
                        VStack(alignment: .leading) {
                            Text("新規追加ボタンを表示")
                            Text("文法リストに新規追加ボタンを表示する")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $settingsStoreBindable.showGrammarEditorButton) {
                        VStack(alignment: .leading) {
                            Text("編集ボタンを表示")
                            Text("文法画面に編集ボタンを表示")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $settingsStoreBindable.showGrammarListItemSwipeActions) {
                        VStack(alignment: .leading) {
                            Text("スワイプアクションを表示")
                            Text("文法リストにスワイプアクションを表示")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $settingsStoreBindable.showGrammarListItemImportantImage) {
                        VStack(alignment: .leading) {
                            Text("重要アイコンを表示")
                            Text("文法リストに重要アイコンを表示")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $settingsStoreBindable.showGrammarListCount) {
                        VStack(alignment: .leading) {
                            Text("件数を表示")
                            Text("文法リスト底に件数を表示する")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $settingsStoreBindable.showGrammarListAllItemTag) {
                        VStack(alignment: .leading) {
                            Text("タグを表示")
                            Text("すべての文法リストにレベルタグを表示する")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(header: Text("機能設定")) {

                    Button {
                        Task {
                            await store.fetchAll()
                        }
                    } label: {
                        Text("再読み込み")
                    }
                }

                Section(header: Text("ストレージ"), footer: Text("キャッシュを削除すると、一時的に保存されたデータが削除されます。")) {

                    HStack {
                        Text("使用容量")
                        Spacer()
                        Text(formattedStorageSize(storageBytes))
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task {
                            clearAppCache()
                            storageBytes = getAppStorageSize()
                        }
                    } label: {
                        Text("キャッシュを削除")
                    }
                }

                Section(header: Text("国籍")) {
                    Picker("国籍", selection: $settingsStoreBindable.Nationality) {
                        ForEach(isoCountries, id: \.code) { country in
                            Text(country.name).tag(country.code)
                        }
                    }
                }
            }
            .navigationTitle("日本語勉学に設定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    func clearAppCache() {
        // 清 URLSession cache
        URLCache.shared.removeAllCachedResponses()

        // 清 tmp
        let fileManager = FileManager.default
        let tmpURL = fileManager.temporaryDirectory
        try? fileManager.removeItem(at: tmpURL)

        // 3️⃣ 重新建立 tmp
        try? fileManager.createDirectory(at: tmpURL, withIntermediateDirectories: true)
    }
}
