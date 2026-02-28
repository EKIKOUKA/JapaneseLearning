//
//  KanjiWordsStore.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/19.
//

import Foundation
import Combine

struct KanjiWordsItem: Codable, Identifiable {
    var id: Int? = nil
    var word: String
    var ruby: String
    var meaning: String
}

class KanjiWordsStore: ObservableObject {

    @Published var KanjiWordsList: [KanjiWordsItem] = []
    @Published var expandedIDs: Set<Int> = []
    @Published var isLoading = false

    func toggleExpand(_ id: Int) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }
    func expandAll() {
        let allIDs = KanjiWordsList.compactMap { $0.id }
        expandedIDs = Set(allIDs)
    }
    func collapseAll() {
        expandedIDs.removeAll()
    }

    @MainActor
    func fetchAll() async {
        do {
            let url = URL(string: "\(Cloudflare_Workers_URL)/fetch_kanji_word")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode([KanjiWordsItem].self, from: data)
            KanjiWordsList = response
        } catch {
            isLoading = false
            print("❌ Fetch Error：\(error)")
        }
    }

    @MainActor
    func KanjiWordsAdd(_ addItem: KanjiWordsItem) async {
        KanjiWordsList.append(addItem)

        do {
            let url = URL(string: "\(Cloudflare_Workers_URL)/add_kanji_word")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(addItem)
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("❌ Add failed:", error)
            KanjiWordsList.removeAll { $0.id == addItem.id }
        }
    }
    @MainActor
    func KanjiWordsUpdate(_ updatedItem: KanjiWordsItem) async {
        guard let index = KanjiWordsList.firstIndex(where: { $0.id == updatedItem.id }) else { return }

        let original = KanjiWordsList[index]
        KanjiWordsList[index] = updatedItem

        do {
            let url = URL(string: "\(Cloudflare_Workers_URL)/update_kanji_word")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(updatedItem)
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("❌ Update failed:", error)
            KanjiWordsList[index] = original
        }
    }
}
