//
//  SampleRubyWordsStore.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/19.
//

import Foundation
import Supabase
import Combine

class SampleRubyWordsStore: ObservableObject {

    @Published var SampleRubyWordsList: [SampleRubyWordsItem] = []
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
        expandedIDs = Set(SampleRubyWordsList.map(\.id))
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
            let response: [SampleRubyWordsItem] = try await client
                .from("japanese_sample_ruby_words")
                .select()
                .order("word")
                .execute()
                .value

            SampleRubyWordsList = response
            isLoading = false
        } catch {
            isLoading = false
            print("❌ Supabase Fetch Error：\(error)")
        }
    }

    @MainActor
    func SampleRubyWordsAdd(_ addItem: SampleRubyWordsItem) async {
        SampleRubyWordsList.append(addItem)

        do {
            try await client
                .from("japanese_sample_ruby_words")
                .insert([
                    "word": addItem.word,
                    "ruby": addItem.ruby,
                    "meaning": addItem.meaning
                ])
                .execute()
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
            try await client
                .from("japanese_sample_ruby_words")
                .update([
                    "word": updatedItem.word,
                    "ruby": updatedItem.ruby,
                    "meaning": updatedItem.meaning
                ])
                .eq("id", value: updatedItem.id.uuidString)
                .execute()
        } catch {
            print("❌ Update failed:", error)
            SampleRubyWordsList[index] = original
        }
    }
}
