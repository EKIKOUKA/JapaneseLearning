//
//  FuriganaService.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/28.
//

import Foundation
import UIKit

final class FuriganaService {

    struct RubyResult {
        let rubyMap: [String: Data]
        let rubyWordRanges: [String: [RubyWordRange]]
    }

    struct FuriganaResponse: Decodable {
        let result: Result?
        let error: furiganaError?

        struct Result: Decodable {
            let word: [Word]?
        }

        struct Word: Decodable {
            let surface: String?
            let furigana: String?
            let roman: String?
            let subword: [Word]?
        }

        struct furiganaError: Decodable {
            let code: Int
            let message: String
        }
    }

    enum RubyFontStyle: String, CaseIterable {
        case HiraginoSans = "HiraginoSans-W6"
        case HiraMinProN = "HiraMinProN-W6"

        var displayName: String {
            switch self {
                case .HiraginoSans: return "ヒラギノ角ゴ"
                case .HiraMinProN: return "ヒラギノ明朝"
            }
        }
    }
    struct YahooErrorResponse: Codable {
        struct ErrorDetail: Codable {
            let code: Int
            let message: String
        }
        let error: ErrorDetail
    }

    func requestRuby(
        for lines: [CaptionLine],
        onProgress: (([String: Data], [String: [RubyWordRange]]) -> Void)? = nil
    ) async throws -> RubyResult {
        var rubyMap: [String: Data] = [:]
        var rubyWordRanges: [String: [RubyWordRange]] = [:]

        await requestRubyForCaptions(
            lines,
            rubyMap: &rubyMap,
            rubyWordRanges: &rubyWordRanges,
            onProgress: onProgress
        )

        return RubyResult(
            rubyMap: rubyMap,
            rubyWordRanges: rubyWordRanges
        )
    }
    func requestRubyBatch(
        _ batch: [CaptionLine]
    ) async -> ([String: Data], [String: [RubyWordRange]]) {
        let textToRequest = batch.map { $0.text }.joined()
        guard !textToRequest.isEmpty else { return ([:], [:]) }

        do {
            let response = try await fetchKanjiRubyWithYahoo(text: textToRequest)

            if let apiError = response.error {
                print("❌ Yahoo 業務錯誤 [\(apiError.code)]: \(apiError.message)")
                return ([:], [:])
            }

            guard let result = response.result else {
                print("❌ Yahoo 返回了空結果且無錯誤信息")
                return ([:], [:])
            }

            let (rubyText, ranges) = makeRubyTextWithRanges(from: response)
            let partialMap = distributeRubyText(rubyText, to: batch)

            var partialRanges: [String: [RubyWordRange]] = [:]
            var location = 0
            for line in batch {
                let length = line.text.count
                let lineRanges = ranges.filter {
                    NSIntersectionRange($0.range, NSRange(location: location, length: length)).length > 0
                }.map {
                    RubyWordRange(
                        range: NSRange(
                            location: $0.range.location - location,
                            length: $0.range.length
                        ),
                        surface: $0.surface
                    )
                }

                partialRanges[line.id] = lineRanges
                location += length
            }

            return (partialMap, partialRanges)
        } catch {
            print("Ruby request failed:", error)
            return ([:], [:])
        }
    }
    func distributeRubyText(_ rubyText: NSAttributedString, to batch: [CaptionLine]) -> [String: Data] {
        var tempMap: [String: Data] = [:]
        var location = 0

        for line in batch {
            let length = line.text.count

            if location + length <= rubyText.length {
                let range = NSRange(location: location, length: length)
                let sub = rubyText.attributedSubstring(from: range)

                let data = try? NSKeyedArchiver.archivedData(withRootObject: sub, requiringSecureCoding: false)
                if let data = data {
                    tempMap[line.id] = data
                }
            }

            location += length
        }

        return tempMap
    }
    // 振り仮名
    private func requestRubyForCaptions(
        _ lines: [CaptionLine],
        rubyMap: inout [String: Data],
        rubyWordRanges: inout [String: [RubyWordRange]],
        onProgress: (([String: Data], [String: [RubyWordRange]]) -> Void)?
    ) async {
        var buffer: [CaptionLine] = []
        var bufferSize = 0
        let maxBatchSize = 3500

        for line in lines {

            let text = line.text
            let size = text.lengthOfBytes(using: .utf8)

            guard size < maxBatchSize else { continue }

            if bufferSize + size > maxBatchSize {
                // 🟢 修改點 1：接收返回值
                let (partialMap, partialRanges) = await requestRubyBatch(buffer)

                // 🟢 修改點 2：將增量合併到當前累積的容器中
                rubyMap.merge(partialMap) { (_, new) in new }
                rubyWordRanges.merge(partialRanges) { (_, new) in new }

                // 🟢 修改點 3：即時通知 PlayerViewModel 更新 UI
                onProgress?(partialMap, partialRanges)

                try? await Task.sleep(nanoseconds: 256_000_000)

                buffer = []
                bufferSize = 0
            }

            buffer.append(line)
            bufferSize += size
        }

        if !buffer.isEmpty {
            let (partialMap, partialRanges) = await requestRubyBatch(buffer)
            rubyMap.merge(partialMap) { (_, new) in new }
            rubyWordRanges.merge(partialRanges) { (_, new) in new }
            onProgress?(partialMap, partialRanges)
        }
    }
    // ルビ振り
    private func fetchKanjiRubyWithYahoo(text: String) async throws -> FuriganaResponse {
        print("--- fetchKanjiRubyWithYahoo ---")
        let url = URL(string: "https://jlp.yahooapis.jp/FuriganaService/V2/furigana")!
        let body: [String: Any] = [
            "id": "1",
            "jsonrpc": "2.0",
            "method": "jlp.furiganaservice.furigana",
            "params": [
                "q": text,
                "grade": 1
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body)

        guard jsonData.count < 4096 else {
            throw NSError(domain: "Furigana", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Request body は 4KBに超えた"
            ])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.setValue("Yahoo AppID: \(Config.YahooJapaneseClientID)", forHTTPHeaderField: "User-Agent")

        print("📡 正在發送文本，長度：\(text.count) 字符")
        let (data, _) = try await URLSession.shared.data(for: request)

        if let errorDict = try? JSONDecoder().decode(YahooErrorResponse.self, from: data) {
            print("❌ Yahoo 業務錯誤 [\(errorDict.error.code)]: \(errorDict.error.message)")
            print("🔴 出錯的文本片段: \(text)...")
            throw NSError(domain: "YahooAPI", code: errorDict.error.code, userInfo: [NSLocalizedDescriptionKey: errorDict.error.message])
        }

        return try JSONDecoder().decode(FuriganaResponse.self, from: data)
    }
    private func makeRubyTextWithRanges(from response: FuriganaResponse, fontStyle: RubyFontStyle = .HiraginoSans) -> (NSAttributedString, [RubyWordRange]) {

        let result = NSMutableAttributedString()
        var ranges: [RubyWordRange] = []
        guard let result_word = response.result?.word else {
            return (NSAttributedString(string: ""), [])
        }

        var location = 0

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 0
        paragraph.lineBreakMode = .byWordWrapping

        let fontSize: CGFloat = 26
        let customFont = UIFont(name: fontStyle.rawValue, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)

        for word in result_word {

            let surface = word.surface ?? ""
            let length = surface.count

            if let furigana = word.furigana {
                let settings: [CFString: Any] = [
                    kCTRubyAnnotationSizeFactorAttributeName: 0.5 as NSNumber // 振り仮名フォントサイズ
                ]

                let ruby = CTRubyAnnotationCreateWithAttributes(
                    .auto,
                    .auto,
                    .before,
                    furigana as CFString,
                    settings as CFDictionary
                )

                let attr: [NSAttributedString.Key: Any] = [
                    kCTRubyAnnotationAttributeName as NSAttributedString.Key: ruby,
                    .font: customFont,
                    .paragraphStyle: paragraph,
                    .foregroundColor: UIColor.white
                ]

                result.append(NSAttributedString(string: surface, attributes: attr))
            } else {
                result.append(NSAttributedString(
                    string: surface,
                    attributes: [
                        .font: customFont,
                        .paragraphStyle: paragraph,
                        .foregroundColor: UIColor.white
                    ])
                )
            }

            let range = NSRange(location: location, length: length)
            ranges.append(RubyWordRange(range: range, surface: surface))

            location += length
        }

        return (result, ranges)
    }
}
