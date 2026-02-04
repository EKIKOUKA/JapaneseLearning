//
//  ElegantSentenceStore.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/19.
//

import Foundation
import Supabase
import Combine

class ElegantSentenceStore: ObservableObject {

    @Published var ElegantSentenceList: [ElegantSentenceItem] = []
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
            let response: [ElegantSentenceItem] = try await client
                .from("japanese_elegant_sentence")
                .select()
                .order("sentence")
                .execute()
                .value

            ElegantSentenceList = response
            try? await Task.sleep(nanoseconds: 300_000_000)
            isLoading = false
        } catch {
            isLoading = false
            print("❌ Supabase Fetch Error：\(error)")
        }
    }

    @MainActor
    func ElegantSentenceAdd(_ addItem: ElegantSentenceItem) async {
        ElegantSentenceList.append(addItem)

        do {
            try await client
                .from("japanese_elegant_sentence")
                .insert([
                    "sentence": addItem.sentence
                ])
                .execute()
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
            try await client
                .from("japanese_elegant_sentence")
                .update([
                    "sentence": updatedItem.sentence
                ])
                .eq("id", value: updatedItem.id.uuidString)
                .execute()
        } catch {
            print("❌ Update failed:", error)
            ElegantSentenceList[index] = original
        }
    }
}
