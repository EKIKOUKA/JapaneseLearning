//
//  GrammarModels.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/11/27.
//

import Foundation

@propertyWrapper
struct BoolFromInt: Codable {
    var wrappedValue: Bool

    init(wrappedValue: Bool) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let boolValue = try? container.decode(Bool.self) {
            wrappedValue = boolValue
        } else if let intValue = try? container.decode(Int.self) {
            wrappedValue = intValue == 1
        } else {
            wrappedValue = false
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue ? 1 : 0)
    }
}

struct GrammarData: Codable {
    var N1: [GrammarItem]
    var N2: [GrammarItem]
    var N3: [GrammarItem]
    var N4: [GrammarItem]
    var N5: [GrammarItem]
    var Others: [GrammarItem]
}

struct GrammarItem: Codable, Identifiable {
    var id: Int
    var title: String
    var level: String
    var meaning: String
    var connection: String?
    var notes: String?
    var examples: String
    @BoolFromInt
    var isImportant: Bool
    @BoolFromInt
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
