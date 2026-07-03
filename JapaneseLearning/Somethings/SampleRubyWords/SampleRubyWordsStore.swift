//
//  SampleRubyWordsStore.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/19.
//

import SwiftUI
import Foundation
import Observation
import Combine

struct SampleRubyWordsItem: Codable, Identifiable {
    var id: Int? = nil
    var word: String
    var ruby: String
    var meaning: String
}

@Observable
class SampleRubyWordsStore {
    var SampleRubyWordsList: [SampleRubyWordsItem] = []
    var expandedIDs: Set<Int> = []
    var isLoading = false
    var isReady: Bool = false

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
            SampleRubyWordsList = try await WorkersAPI.get("fetch_sample_ruby_words")
            withAnimation(.easeIn(duration: 0.2)) {
                isReady = true
            }
        } catch {
            isLoading = false
            print("❌ Fetch Error：\(error)")
        }
    }

    @MainActor
    func SampleRubyWordsAdd(_ addItem: SampleRubyWordsItem) async {
        SampleRubyWordsList.append(addItem)

        do {
            try await WorkersAPI.post("add_sample_ruby_words", body: addItem)
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
            try await WorkersAPI.post("update_sample_ruby_words", body: updatedItem)
        } catch {
            print("❌ Update failed:", error)
            SampleRubyWordsList[index] = original
        }
    }
}
