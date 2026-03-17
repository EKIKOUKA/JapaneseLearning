//
//  ElegantSentenceStore.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/12/19.
//

import SwiftUI
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
            ElegantSentenceList = try await WorkersAPI.get("fetch_elegant_sentence")
            withAnimation(.easeIn(duration: 0.2)) {
                isReady = true
            }
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
            try await WorkersAPI.post("add_elegant_sentence", body: addItem)
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
            try await WorkersAPI.post("update_elegant_sentence", body: updatedItem)
        } catch {
            print("❌ Update failed:", error)
            ElegantSentenceList[index] = original
        }
    }
}
