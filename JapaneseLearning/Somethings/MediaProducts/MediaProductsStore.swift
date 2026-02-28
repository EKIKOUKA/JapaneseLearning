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
            MediaProductsList = try await WorkersAPI.get("fetch_video_products")
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
            try await WorkersAPI.post("add_video_products", body: addItem)
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
            try await WorkersAPI.post("update_video_products", body: updatedItem)
        } catch {
            print("❌ Update failed:", error)
            MediaProductsList[index] = original
        }
    }
}
