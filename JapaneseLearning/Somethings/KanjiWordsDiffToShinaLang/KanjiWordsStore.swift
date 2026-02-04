//
//  KanjiWordsStore.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/19.
//

import Foundation
import Supabase
import Combine

class KanjiWordsStore: ObservableObject {

    @Published var KanjiWordsList: [KanjiWordsItem] = []
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
        expandedIDs = Set(KanjiWordsList.map(\.id))
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
            let response: [KanjiWordsItem] = try await client
                .from("japanese_kanji_word")
                .select()
                .order("word")
                .execute()
                .value

            KanjiWordsList = response
            isLoading = false
        } catch {
            isLoading = false
            print("❌ Supabase Fetch Error：\(error)")
        }
    }

    @MainActor
    func KanjiWordsAdd(_ addItem: KanjiWordsItem) async {
        KanjiWordsList.append(addItem)

        do {
            try await client
                .from("japanese_kanji_word")
                .insert([
                    "word": addItem.word,
                    "ruby": addItem.ruby,
                    "meaning": addItem.meaning
                ])
                .execute()
        } catch {
            print("❌ Add failed:", error)
            KanjiWordsList.removeAll { $0.id == addItem.id }
        }
    }
    @MainActor
    func KanjiWordsUpdate(_ updatedItem: KanjiWordsItem) async {
        guard let index = KanjiWordsList.firstIndex(where: { $0.id == updatedItem.id }) else { return }

        let original = KanjiWordsList[index]
        KanjiWordsList[index] = updatedItem

        do {
            try await client
                .from("japanese_kanji_word")
                .update([
                    "word": updatedItem.word,
                    "ruby": updatedItem.ruby,
                    "meaning": updatedItem.meaning
                ])
                .eq("id", value: updatedItem.id.uuidString)
                .execute()
        } catch {
            print("❌ Update failed:", error)
            KanjiWordsList[index] = original
        }
    }
}
