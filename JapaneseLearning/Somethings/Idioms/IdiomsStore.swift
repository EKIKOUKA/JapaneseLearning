//
//  IdiomsStore.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/19.
//

import Foundation
import Combine

struct IdiomsItem: Codable, Identifiable {
    var id: Int? = nil
    var word: String
    var ruby: String
    var meaning: String
}

class IdiomsStore: ObservableObject {
    @Published var IdiomsList: [IdiomsItem] = []
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
        let allIDs = IdiomsList.compactMap { $0.id }
        expandedIDs = Set(allIDs)
    }
    func collapseAll() {
        expandedIDs.removeAll()
    }

    @MainActor
    func fetchAll() async {
        do {
            IdiomsList = try await WorkersAPI.get("fetch_idioms")
        } catch {
            isLoading = true
            print("❌ Fetch Error：\(error)")
        }
    }

    @MainActor
    func IdiomsAdd(_ addItem: IdiomsItem) async {
        IdiomsList.append(addItem)

        do {
            try await WorkersAPI.post("add_idioms", body: addItem)
        } catch {
            print("❌ Add failed:", error)
            IdiomsList.removeAll { $0.id == addItem.id }
        }
    }
    @MainActor
    func IdiomsUpdate(_ updatedItem: IdiomsItem) async {
        guard let index = IdiomsList.firstIndex(where: { $0.id == updatedItem.id }) else { return }

        let original = IdiomsList[index]
        IdiomsList[index] = updatedItem

        do {
            try await WorkersAPI.post("update_idioms", body: updatedItem)
        } catch {
            print("❌ Update failed:", error)
            IdiomsList[index] = original
        }
    }
}
