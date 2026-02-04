//
//  MediaProductsStore.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 8/01/14.
//

import Foundation
import Supabase
import Combine

class MediaProductsStore: ObservableObject {

    @Published var MediaProductsList: [MediaProductsItem] = []
    @Published var isLoading = false

    let client = SupabaseClient(
        supabaseURL: URL(string: Config.supabaseJapaneseLearningURL)!,
        supabaseKey: Config.supabaseJapaneseLearningKey,
        options: SupabaseClientOptions(
            auth: .init(
                emitLocalSessionAsInitialSession: true
            )
        )
    )
    @MainActor
    func fetchAll() async {
        isLoading = true

        do {
            try? await Task.sleep(nanoseconds: 300_000_000)
            let response: [MediaProductsItem] = try await client
                .from("japanese_video_products")
                .select()
                .order("created_at")
                .execute()
                .value

            MediaProductsList = response
            isLoading = false
        } catch {
            isLoading = false
            print("❌ Supabase Fetch Error：\(error)")
        }
    }
    @MainActor
    func MediaProductsAdd(_ addItem: MediaProductsItem) async {
        MediaProductsList.append(addItem)

        do {
            try await client
                .from("japanese_video_products")
                .insert([
                    "title": addItem.title,
                    "category": addItem.category.rawValue,
                    "status": addItem.status.rawValue,
                    "details_url": addItem.detailsURL,
                    "memo": addItem.memo
                ])
                .execute()
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
            try await client
                .from("japanese_video_products")
                .update([
                    "title": updatedItem.title,
                    "category": updatedItem.category.rawValue,
                    "status": updatedItem.status.rawValue,
                    "details_url": updatedItem.detailsURL,
                    "memo": updatedItem.memo
                ])
                .eq("id", value: updatedItem.id.uuidString)
                .execute()
        } catch {
            print("❌ Update failed:", error)
            MediaProductsList[index] = original
        }
    }
}
