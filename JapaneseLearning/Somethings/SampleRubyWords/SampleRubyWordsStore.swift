//
//  SampleRubyWordsStore.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/19.
//

import Foundation
import Combine

struct SampleRubyWordsItem: Codable, Identifiable {
    var id: Int? = nil
    var word: String
    var ruby: String
    var meaning: String
}

class SampleRubyWordsStore: ObservableObject {

    @Published var SampleRubyWordsList: [SampleRubyWordsItem] = []
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
        let allIDs = SampleRubyWordsList.compactMap { $0.id }
        expandedIDs = Set(allIDs)
    }
    func collapseAll() {
        expandedIDs.removeAll()
    }

    @MainActor
    func fetchAll() async {
        do {
            let url = URL(string: "\(Cloudflare_Workers_URL)/fetch_sample_ruby_words")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode([SampleRubyWordsItem].self, from: data)
            SampleRubyWordsList = response
        } catch {
            isLoading = false
            print("❌ Fetch Error：\(error)")
        }
    }

    @MainActor
    func SampleRubyWordsAdd(_ addItem: SampleRubyWordsItem) async {
        SampleRubyWordsList.append(addItem)

        do {
            let url = URL(string: "\(Cloudflare_Workers_URL)/add_sample_ruby_words")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(addItem)
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("❌ Add failed:", error)
            SampleRubyWordsList.removeAll { $0.id == addItem.id }
        }
    }
    @MainActor
    func SampleRubyWordsUpdate(_ updatedItem: SampleRubyWordsItem) async {
        guard let index = SampleRubyWordsList.firstIndex(where: { $0.id == updatedItem.id }) else { return }

        let original = SampleRubyWordsList[index]
        SampleRubyWordsList[index] = updatedItem

        do {
            let url = URL(string: "\(Cloudflare_Workers_URL)/update_sample_ruby_words")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(updatedItem)
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("❌ Update failed:", error)
            SampleRubyWordsList[index] = original
        }
    }
}
