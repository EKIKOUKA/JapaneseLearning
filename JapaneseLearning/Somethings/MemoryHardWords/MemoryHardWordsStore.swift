//
//  MemoryHardWordsStore.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/19.
//

import Foundation
import Supabase
import Combine

class MemoryHardWordsStore: ObservableObject {

    @Published var MemoryHardWordsList: [MemoryHardWordsItem] = []
    @Published var expandedIDs: Set<UUID> = []
    @Published var isLoading = false

    func toggleExpand(_ id: UUID) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }
    func expandAll() {
        expandedIDs = Set(MemoryHardWordsList.map(\.id))
    }
    func collapseAll() {
        expandedIDs.removeAll()
    }

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
            try? await Task.sleep(nanoseconds: 256_000_000)
            let response: [MemoryHardWordsItem] = try await client
                .from("japanese_memory_hard_words")
                .select()
                .order("word")
                .execute()
                .value

            MemoryHardWordsList = response
            isLoading = false
        } catch {
            isLoading = false
            print("❌ Supabase Fetch Error：\(error)")
        }
    }

    @MainActor
    func MemoryHardWordsAdd(_ addItem: MemoryHardWordsItem) async {
        MemoryHardWordsList.append(addItem)

        do {
            try await client
                .from("japanese_memory_hard_words")
                .insert([
                    "word": addItem.word,
                    "ruby": addItem.ruby,
                    "meaning": addItem.meaning
                ])
                .execute()
        } catch {
            print("❌ Add failed:", error)
            MemoryHardWordsList.removeAll { $0.id == addItem.id }
        }
    }
    @MainActor
    func MemoryHardWordsUpdate(_ updatedItem: MemoryHardWordsItem) async {
        guard let index = MemoryHardWordsList.firstIndex(where: { $0.id == updatedItem.id }) else { return }

        let original = MemoryHardWordsList[index]
        MemoryHardWordsList[index] = updatedItem

        do {
            try await client
                .from("japanese_memory_hard_words")
                .update([
                    "word": updatedItem.word,
                    "ruby": updatedItem.ruby,
                    "meaning": updatedItem.meaning
                ])
                .eq("id", value: updatedItem.id.uuidString)
                .execute()
        } catch {
            print("❌ Update failed:", error)
            MemoryHardWordsList[index] = original
        }
    }
}
