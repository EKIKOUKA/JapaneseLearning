//
//  IdiomsStore.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/19.
//

import Foundation
import Supabase
import Combine

class IdiomsStore: ObservableObject {

    @Published var IdiomsList: [IdiomsItem] = []
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
        expandedIDs = Set(IdiomsList.map(\.id))
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
            let response: [IdiomsItem] = try await client
                .from("japanese_idioms")
                .select()
                .order("word")
                .execute()
                .value

            IdiomsList = response
            isLoading = false
        } catch {
            isLoading = false
            print("❌ Supabase Fetch Error：\(error)")
        }
    }

    @MainActor
    func IdiomsAdd(_ addItem: IdiomsItem) async {
        IdiomsList.append(addItem)

        do {
            try await client
                .from("japanese_idioms")
                .insert([
                    "word": addItem.word,
                    "ruby": addItem.ruby,
                    "meaning": addItem.meaning
                ])
                .execute()
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
            try await client
                .from("japanese_idioms")
                .update([
                    "word": updatedItem.word,
                    "ruby": updatedItem.ruby,
                    "meaning": updatedItem.meaning
                ])
                .eq("id", value: updatedItem.id.uuidString)
                .execute()
        } catch {
            print("❌ Update failed:", error)
            IdiomsList[index] = original
        }
    }
}
