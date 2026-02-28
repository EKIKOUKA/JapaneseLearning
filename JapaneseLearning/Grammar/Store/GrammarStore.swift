//
//  GrammarStore.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/11/28.
//

import Foundation
import Combine

class GrammarStore: ObservableObject {
    @Published var grammars: [GrammarItem] = []
    @Published var isLoading = false

    init() {
        Task { @MainActor in
            await fetchAll()
        }
    }

    @MainActor
    func fetchAll() async {
        do {
            self.grammars = try await WorkersAPI.get("fetch_grammars")
        } catch {
            self.isLoading = true
            print("❌ Fetch Error：\(error)")
        }
    }

    @MainActor
    func toggleImportant(_ id: Int) async {
        guard let index = grammars.firstIndex(where: { $0.id == id }) else { return }
        let originValue = grammars[index].isImportant

        grammars[index].isImportant.toggle()

        let updatedItem = [
            "id": id,
            "is_important": grammars[index].isImportant ? 1 : 0
        ]

        do {
            try await WorkersAPI.postRaw(
                "grammars_toggle_important",
                body: updatedItem
            )
        } catch {
            print("❌ Update failed:", error)
            grammars[index].isImportant = originValue
        }
    }

    @MainActor
    func toggleMarked(_ id: Int) async {
        guard let index = grammars.firstIndex(where: { $0.id == id }) else { return }
        let originValue = grammars[index].isMarked
        grammars[index].isMarked.toggle()

        let updatedItem = [
            "id": id,
            "is_marked": grammars[index].isMarked ? 1 : 0
        ]

        do {
            try await WorkersAPI.postRaw(
                "grammars_toggle_marked",
                body: updatedItem
            )
        } catch {
            print("❌ Update failed:", error)
            grammars[index].isMarked = originValue
        }
    }

    @MainActor
    func grammarAdd(_ addItem: GrammarItem) async {
        grammars.append(addItem)

        do {
            try await WorkersAPI.post("add_grammars", body: addItem)
        } catch {
            print("❌ Add failed:", error)
            grammars.removeAll { $0.id == addItem.id }
        }
    }

    @MainActor
    func grammarUpdate(_ id: Int, updatedItem: GrammarItem) async {
        guard let index = grammars.firstIndex(where: { $0.id == id }) else { return }

        let original = grammars[index]
        grammars[index] = updatedItem

        do {
            try await WorkersAPI.post("update_grammars", body: updatedItem)
        } catch {
            print("❌ Update failed:", error)
            grammars[index] = original
        }
    }
}
