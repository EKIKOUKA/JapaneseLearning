//
//  SubtitleModels.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/28.
//

import Foundation

// 字幕データ
struct VideoData {
    let url: URL
    let captionsUrl: URL
}

struct VideoResponse: Codable {
    let url: String
    let captions: String
}

struct CaptionSegment: Codable, Equatable {
    let text: String
    let start: Double
    let end: Double
}

struct CaptionLine: Identifiable, Equatable, Codable {
    let id: String
    let start: Double
    let end: Double
    let text: String
    let ruby: [RubyWord]?
    let segments: [CaptionSegment]?
    var isSkip: Bool = false

    // ルビの対象範囲はデコード時に確定する。
    let rubyRanges: [RubyWordRange]

    enum CodingKeys: String, CodingKey {
        case id
        case start
        case end
        case text
        case ruby
        case segments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        start = try container.decode(Double.self, forKey: .start)
        end = try container.decode(Double.self, forKey: .end)
        text = try container.decode(String.self, forKey: .text)
        ruby = try container.decodeIfPresent([RubyWord].self, forKey: .ruby)

        // 古い字幕に時刻付きの断片がなくても、本文はそのまま表示できる。
        segments = try? container.decode([CaptionSegment].self, forKey: .segments)

        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        var result: [RubyWordRange] = []
        var searchStart = cleanText.startIndex

        if let ruby {
            for item in ruby {
                guard !item.surface.isEmpty else { continue }

                if let range = cleanText.range(
                    of: item.surface,
                    range: searchStart..<cleanText.endIndex
                ) {
                    result.append(
                        RubyWordRange(
                            range: NSRange(range, in: cleanText),
                            surface: item.surface,
                            reading: item.reading
                        )
                    )

                    searchStart = range.upperBound
                }
            }
        }

        rubyRanges = result
    }
}

// ルビのデータ
struct RubyWordRange: Equatable {
    let range: NSRange
    let surface: String
    let reading: String?
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


// 字幕表示用データ
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
