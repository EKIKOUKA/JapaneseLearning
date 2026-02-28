//
//  MediaProductsStore.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 8/01/14.
//

import Foundation
import Combine

class MediaProductsStore: ObservableObject {
    @Published var MediaProductsList: [MediaProductsItem] = []
    @Published var isLoading = false
    @Published var isReady: Bool = false

    @MainActor
    func fetchAll() async {
        do {
            let url = URL(string: "\(Cloudflare_Workers_URL)/fetch_video_products")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode([MediaProductsItem].self, from: data)
            MediaProductsList = response
            try? await Task.sleep(nanoseconds: 100_000_000)
            isReady = true
        } catch {
            isLoading = true
            isReady = false
            print("❌ Fetch Error：\(error)")
        }
    }
    @MainActor
    func MediaProductsAdd(_ addItem: MediaProductsItem) async {
        MediaProductsList.append(addItem)

        do {
            let url = URL(string: "\(Cloudflare_Workers_URL)/add_video_products")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(addItem)
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("❌ Add failed:", error)
            MediaProductsList.removeAll { $0.id == addItem.id }
        }
    }
    @MainActor
    func MediaProductsUpdate(_ updatedItem: MediaProductsItem) async {
        guard let index = MediaProductsList.firstIndex(where: { $0.id == updatedItem.id }) else { return }

        let original = MediaProductsList[index]
        MediaProductsList[index] = updatedItem

        do {
            let url = URL(string: "\(Cloudflare_Workers_URL)/update_video_products")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(updatedItem)
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("❌ Update failed:", error)
            MediaProductsList[index] = original
        }
    }
}
