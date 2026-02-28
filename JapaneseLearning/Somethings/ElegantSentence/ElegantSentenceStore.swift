//
//  ElegantSentenceStore.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/19.
//

import Foundation
import Combine

struct ElegantSentenceItem: Codable, Identifiable {
    var id: Int? = nil
    var sentence: String

    var height: CGFloat = .zero

    enum CodingKeys: String, CodingKey {
        case id
        case sentence
    }
}

class ElegantSentenceStore: ObservableObject {
    @Published var ElegantSentenceList: [ElegantSentenceItem] = []
    @Published var isLoading = false
    @Published var isReady: Bool = false

    @MainActor
    func fetchAll() async {
        do {
            let url = URL(string: "\(Cloudflare_Workers_URL)/fetch_elegant_sentence")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode([ElegantSentenceItem].self, from: data)
            ElegantSentenceList = response
            try? await Task.sleep(nanoseconds: 100_000_000)
            isReady = true
        } catch {
            isLoading = true
            isReady = false
            print("❌ Fetch Error：\(error)")
        }
    }

    @MainActor
    func ElegantSentenceAdd(_ addItem: ElegantSentenceItem) async {
        ElegantSentenceList.append(addItem)

        do {
            let url = URL(string: "\(Cloudflare_Workers_URL)/add_elegant_sentence")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(addItem)
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("❌ Add failed:", error)
            ElegantSentenceList.removeAll { $0.id == addItem.id }
        }
    }
    @MainActor
    func ElegantSentenceUpdate(_ updatedItem: ElegantSentenceItem) async {
        guard let index = ElegantSentenceList.firstIndex(where: { $0.id == updatedItem.id }) else { return }

        let original = ElegantSentenceList[index]
        ElegantSentenceList[index] = updatedItem

        do {
            let url = URL(string: "\(Cloudflare_Workers_URL)/update_elegant_sentence")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(updatedItem)
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("❌ Update failed:", error)
            ElegantSentenceList[index] = original
        }
    }
}
