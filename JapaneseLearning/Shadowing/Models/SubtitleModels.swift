//
//  SubtitleModels.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/28.
//

import Foundation
import UIKit
import CoreText

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
    var isSkip: Bool = false

    // 預解析 ruby
    let rubyRanges: [RubyWordRange]

    // 預構建 attributed string cache
    let cachedAttributedString: NSAttributedString

    enum CodingKeys: String, CodingKey {
        case id
        case start
        case end
        case text
        case ruby
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        start = try container.decode(Double.self, forKey: .start)
        end = try container.decode(Double.self, forKey: .end)
        text = try container.decode(String.self, forKey: .text)
        ruby = try container.decodeIfPresent([RubyWord].self, forKey: .ruby)

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

        cachedAttributedString = CaptionLine.buildAttributedString(
            text: cleanText,
            rubyRanges: result
        )
    }

    private static func buildAttributedString(
        text: String,
        rubyRanges: [RubyWordRange]
    ) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 6
        style.alignment = .left

        let baseFont = UIFont.systemFont(ofSize: 28, weight: .medium)
        let attr = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: baseFont,
                .foregroundColor: UIColor.white,
                .paragraphStyle: style
            ]
        )

        for ruby in rubyRanges {
            guard let reading = ruby.reading,
                  !reading.isEmpty,
                  reading != ruby.surface
            else { continue }

            var rubyAnnotations: [Unmanaged<CFString>?] = [
                Unmanaged.passRetained(reading as CFString),
                nil, nil, nil
            ]

            let annotation = CTRubyAnnotationCreate(
                .center,
                .auto,
                0.45,
                &rubyAnnotations
            )

            attr.addAttribute(
                kCTRubyAnnotationAttributeName as NSAttributedString.Key,
                value: annotation,
                range: ruby.range
            )
        }

        return attr
    }
}

// RubyModels
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
