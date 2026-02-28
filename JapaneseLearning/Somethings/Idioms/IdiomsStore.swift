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
            let url = URL(string: "\(Cloudflare_Workers_URL)/fetch_idioms")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode([IdiomsItem].self, from: data)
            IdiomsList = response
        } catch {
            isLoading = true
            print("❌ Fetch Error：\(error)")
        }
    }

    @MainActor
    func IdiomsAdd(_ addItem: IdiomsItem) async {
        IdiomsList.append(addItem)

        do {
            let url = URL(string: "\(Cloudflare_Workers_URL)/add_idioms")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(addItem)
            _ = try await URLSession.shared.data(for: request)
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
            let url = URL(string: "\(Cloudflare_Workers_URL)/update_idioms")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(updatedItem)
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("❌ Update failed:", error)
            IdiomsList[index] = original
        }
    }
}
