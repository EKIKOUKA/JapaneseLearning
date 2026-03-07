//
//  SubtitleModels.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/28.
//

import Foundation

// Captions
struct VideoData {
    let url: URL
    let captions: [CaptionLine]
}

struct VideoResponse: Codable {
    let url: String
    let captions: String
}

struct CaptionLine: Identifiable, Equatable, Codable {
    let id: String
    let start: Double
    let end: Double
    let text: String
    let ruby: [RubyWord]?
}

// RubyModels
struct RubyWordRange {
    let range: NSRange
    let surface: String
}

struct RubyWord: Codable, Equatable {
    let surface: String
    let reading: String?

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        surface = try container.decode(String.self)
        reading = try container.decodeIfPresent(String.self)
    }
}


// Subtitle
enum VideoSubtitleLineWithAnimation: String, Codable, CaseIterable {
    case natural
    case easeInOut

    var displayName: String {
        switch self {
            case .natural: return "ナチュラル"
            case .easeInOut: return "スムーズ"
        }
    }
}

enum VideoSubtitleRubyFontStyle: String, Codable, CaseIterable {
    case system
    case HiraginoSans = "HiraginoSans-W6"
    case HiraMinProN = "HiraMinProN-W6"

    var displayName: String {
        switch self {
            case .system: return "システム"
            case .HiraginoSans: return "ヒラギノ角ゴ"
            case .HiraMinProN: return "ヒラギノ明朝"
        }
    }
}
