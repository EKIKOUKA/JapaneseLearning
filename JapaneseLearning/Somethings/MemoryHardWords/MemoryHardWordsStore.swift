//
//  MemoryHardWordsStore.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/19.
//

import Foundation
import Combine

struct MemoryHardWordsItem: Codable, Identifiable {
    var id: Int? = nil
    var word: String
    var ruby: String
    var meaning: String
}

class MemoryHardWordsStore: ObservableObject {
    @Published var MemoryHardWordsList: [MemoryHardWordsItem] = []
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
        let allIDs = MemoryHardWordsList.compactMap { $0.id }
        expandedIDs = Set(allIDs)
    }
    func collapseAll() {
        expandedIDs.removeAll()
    }

    @MainActor
    func fetchAll() async {
        isLoading = true

        do {
            MemoryHardWordsList = try await WorkersAPI.get("fetch_memory_hard_words")
            isLoading = false
        } catch {
            isLoading = false
            print("❌ Fetch Error：\(error)")
        }
    }

    @MainActor
    func MemoryHardWordsAdd(_ addItem: MemoryHardWordsItem) async {
        MemoryHardWordsList.append(addItem)

        do {
            try await WorkersAPI.post("add_memory_hard_words", body: addItem)
        } catch {
            print("❌ Add failed:", error)
            MemoryHardWordsList.removeAll { $0.id == addItem.id }
        }
    }
    @MainActor
    func MemoryHardWordsUpdate(_ updatedItem: MemoryHardWordsItem) async {
        guard let index = MemoryHardWordsList.firstIndex(where: { $0.id == updatedItem.id }) else { return }

        let original = MemoryHardWordsList[index]
        MemoryHardWordsList[index] = updatedItem

        do {
            try await WorkersAPI.post("update_memory_hard_words", body: updatedItem)
        } catch {
            print("❌ Update failed:", error)
            MemoryHardWordsList[index] = original
        }
    }
}
