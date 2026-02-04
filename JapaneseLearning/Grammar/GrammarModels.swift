//
//  GrammarModels.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/11/27.
//

import Foundation

struct GrammarData: Codable {
    var N1: [GrammarItem]
    var N2: [GrammarItem]
    var N3: [GrammarItem]
    var N4: [GrammarItem]
    var N5: [GrammarItem]
    var Others: [GrammarItem]
}

struct GrammarItem: Codable, Identifiable {
    var id: UUID
    var title: String
    var level: String
    var meaning: String
    var connection: String?
    var notes: String?
    var examples: String
    var isImportant: Bool
    var isMarked: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case level
        case meaning
        case connection
        case notes
        case examples
        case isImportant = "is_important"
        case isMarked = "is_marked"
    }
}

struct GrammarListItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let level: String
}

struct GrammarAllLevels {
    static let grammarList: [GrammarListItem] = [
        GrammarListItem(title: "N1 文法", icon: "star.fill", level: "N1"),
        GrammarListItem(title: "N2 文法", icon: "bolt.fill", level: "N2"),
        GrammarListItem(title: "N3 文法", icon: "book.fill", level: "N3"),
        GrammarListItem(title: "N4 文法", icon: "airplane", level: "N4"),
        GrammarListItem(title: "N5 文法", icon: "leaf.fill", level: "N5"),
        GrammarListItem(title: "その他 文法", icon: "tag.fill", level: "Others")
    ]
}
