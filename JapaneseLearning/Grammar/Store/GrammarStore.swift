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
            let url = URL(string: "\(Cloudflare_Workers_URL)/fetch_grammars")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode([GrammarItem].self, from: data)
            self.grammars = response
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
            let url = URL(string: "\(Cloudflare_Workers_URL)/grammars_toggle_important")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: updatedItem)

            _ = try await URLSession.shared.data(for: request)
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
            let url = URL(string: "\(Cloudflare_Workers_URL)/grammars_toggle_marked")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: updatedItem)

            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("❌ Update failed:", error)
            grammars[index].isMarked = originValue
        }
    }

    @MainActor
    func grammarAdd(_ addItem: GrammarItem) async {
        grammars.append(addItem)

        do {
            let url = URL(string: "\(Cloudflare_Workers_URL)/add_grammars")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(addItem)
            _ = try await URLSession.shared.data(for: request)
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
            let url = URL(string: "\(Cloudflare_Workers_URL)/update_grammars")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(updatedItem)
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("❌ Update failed:", error)
            grammars[index] = original
        }
    }
}
