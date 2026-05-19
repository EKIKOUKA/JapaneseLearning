//
//  KanjiWordsStore.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/19.
//

import SwiftUI
import Foundation
import Combine

struct KanjiWordsItem: Codable, Identifiable {
    var id: Int?
    var word: String
    var ruby: String
    var meaning: String
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case word
        case ruby
        case meaning
        case createdAt = "created_at"
    }
}

enum KanjiWordsSortOrder: String, CaseIterable, Identifiable {
    case createdAt
    case word

    var id: String { rawValue }

    var displayName: String {
        switch self {
            case .createdAt:
                return "作成日"
            case .word:
                return "タイトル"
        }
    }
}

class KanjiWordsStore: ObservableObject {
    @Published var KanjiWordsList: [KanjiWordsItem] = []
    @Published var expandedIDs: Set<Int> = []
    @Published var isLoading = false
    @Published var isReady: Bool = false

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
            KanjiWordsList = try await WorkersAPI.get("fetch_kanji_word")
            withAnimation(.easeIn(duration: 0.2)) {
                isReady = true
            }
        } catch {
            isLoading = false
            print("❌ Fetch Error：\(error)")
        }
    }

    @MainActor
    func KanjiWordsAdd(_ addItem: KanjiWordsItem) async {
        KanjiWordsList.append(addItem)

        do {
            try await WorkersAPI.post("add_kanji_word", body: addItem)
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
            try await WorkersAPI.post("update_kanji_word", body: updatedItem)
        } catch {
            print("❌ Update failed:", error)
            KanjiWordsList[index] = original
        }
    }
}
