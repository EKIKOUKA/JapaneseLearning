//
//  FetchVideoService.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/28.
//

import Foundation

final class FetchVideoService {

    struct VideoData {
        let videoURL: URL
        let captions: [CaptionLine]
    }

    func fetchVideoDataFromServer(_ videoID: String) async throws -> VideoData {

        let serverURL = "https://makotodeveloper.website/shadowing/get_video?id=\(videoID)"
        guard let url = URL(string: serverURL) else {
            print("❌ invalid url:", serverURL)
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        let body = String(data: data, encoding: .utf8) ?? ""
        if body.contains("<html") {
            print("❌ Server returned HTML, not JSON")
            print(body.prefix(500))
            throw URLError(.badServerResponse)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let streamUrlString = json["url"] as? String,
            let videoURL = URL(string: streamUrlString),
            let rawCaptions = json["captions"] as? [[String: Any]] else {

              throw URLError(.cannotParseResponse)
        }

        let captions: [CaptionLine] = rawCaptions.compactMap { dict in
            guard let id = dict["id"] as? String,
                let start = dict["start"] as? Double,
                let end = dict["end"] as? Double,
                let text = dict["text"] as? String
            else { return nil }

            var rubyList: [RubyWord]? = nil
            if let rubyArr = dict["ruby"] as? [[String: Any]] {
                rubyList = rubyArr.compactMap { rubyDict in
                    guard let surface = rubyDict["surface"] as? String,
                        let reading = rubyDict["reading"] as? String,
                        let startIdx = rubyDict["start"] as? Int,
                        let length = rubyDict["length"] as? Int
                    else { return nil }

                    return RubyWord(
                        surface: surface,
                        reading: reading,
                        start: startIdx,
                        length: length
                    )
                }
            }

            return CaptionLine(
                id: id,
                start: start,
                end: end,
                text: text,
                ruby: rubyList
            )
        }

        return VideoData(
            videoURL: videoURL,
            captions: captions
        )
    }



//    func fetchCaptionURL(videoID: String) async throws -> String? {
//        print("fetchCaptionUR()")
//        let url = URL(string: "https://www.youtube.com/youtubei/v1/player?key=IzaSyAO-PaLj_SMv8vY6FD0Z89AX9Y")!
//        let body: [String: Any] = [
//            "context": [
//                "client": [
//                    "clientName": "ANDROID",
//                    "clientVersion": "18.11.34"
//                ]
//            ],
//            "videoId": videoID
//        ]
//
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
//        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
//
//        do {
//            let (data, response) = try await URLSession.shared.data(for: request)
//
//            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
//               let captions = json["captions"] as? [String: Any],
//               let playerCaptionsTracklistRenderer = captions["playerCaptionsTracklistRenderer"] as? [String: Any],
//               let captionTracks = playerCaptionsTracklistRenderer["captionTracks"] as? [[String: Any]] {
//                print("captionsがある")
//                let track = captionTracks.first { ($0["languageCode"] as? String) == "ja" } ?? captionTracks.first
//                return track?["baseUrl"] as? String
//            }
//        } catch {
//            print("--- [DEBUG] 網絡或解析異常: \(error.localizedDescription)")
//        }
//
//        return nil
//    }
//
//    func parse(xmlString: String) -> [CaptionLine] {
//        var result: [CaptionLine] = []
//
//        let decodedXML = xmlString
//            .replacingOccurrences(of: "&amp;", with: "&")
//            .replacingOccurrences(of: "&lt;", with: "<")
//            .replacingOccurrences(of: "&gt;", with: ">")
//            .replacingOccurrences(of: "&quot;", with: "\"")
//            .replacingOccurrences(of: "&#39;", with: "'")
//            .replacingOccurrences(of: "\n", with: " ")
//
//        let pattern = #"<text[^>]+start="([\d\.]+)"(?:[^>]+dur="([\d\.]+)")?[^>]*>([^<]*)</text>"#
//
//        do {
//            let regex = try NSRegularExpression(pattern: pattern, options: [])
//            let nsString = decodedXML as NSString
//            let matches = regex.matches(in: decodedXML, range: NSRange(location: 0, length: nsString.length))
//
//            var tempLines: [CaptionLine] = []
//            for match in matches {
//                let startStr = nsString.substring(with: match.range(at: 1))
//                let start = Double(startStr) ?? 0.0
//
//                let text = nsString.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespacesAndNewlines)
//                if text.isEmpty { continue }
//
//                var duration = 3.0
//                if match.range(at: 2).location != NSNotFound {
//                    let durStr = nsString.substring(with: match.range(at: 2))
//                    duration = Double(durStr) ?? 3.0
//                }
//
//                result.append(
//                    CaptionLine(
//                        id: "\(start)",
//                        start: start,
//                        end: start + duration,
//                        text: text,
//                        ruby: nil
//                    )
//                )
//            }
//
//            for i in 0..<result.count {
//                if i < result.count - 1 {
//                    let current = result[i]
//                    let next = result[i + 1]
//                    if current.end > next.start || (current.end - current.start == 3.0) {
//                        let correctedLine = CaptionLine(
//                            id: current.id,
//                            start: current.start,
//                            end: next.start,
//                            text: current.text,
//                            ruby: nil
//                        )
//                        result[i] = correctedLine
//                    }
//                }
//            }
//        } catch {
//            print("Regex Error: \(error)")
//        }
//
//        return result
//    }
//
//    func mergeContinuousLines(_ lines: [CaptionLine]) -> [CaptionLine] {
//        guard !lines.isEmpty else { return [] }
//
//        var merged: [CaptionLine] = []
//        var buffer = lines[0]
//
//        for i in 1..<lines.count {
//            let current = lines[i]
//
//            let timeGap = current.start - buffer.end
//            let shouldMerge =
//            timeGap < 0.3 &&
//            buffer.text.count < 30 &&
//            !buffer.text.hasSuffix("。") &&
//            !buffer.text.hasSuffix("？") &&
//            !buffer.text.hasSuffix("?") &&
//            !buffer.text.hasSuffix("！")
//
//            if shouldMerge {
//                buffer = CaptionLine(
//                    id: current.id,
//                    start: buffer.start,
//                    end: current.end,
//                    text: buffer.text + current.text,
//                    ruby: nil
//                )
//            } else {
//                merged.append(buffer)
//                buffer = current
//            }
//        }
//
//        merged.append(buffer)
//        return merged
//    }
//
//    private func splitSingleLongLine(_ line: CaptionLine, maxChars: Int) -> [CaptionLine] {
//        var subs: [CaptionLine] = []
//        let text = line.text
//        var start = text.startIndex
//        let totalChars = Double(text.count)
//        let duration = line.end - line.start
//
//        var i = 0
//        while start < text.endIndex {
//            let end = text.index(start, offsetBy: maxChars, limitedBy: text.endIndex) ?? text.endIndex
//            let subText = String(text[start..<end])
//
//            let startOffset = (Double(text.distance(from: text.startIndex, to: start)) / totalChars) * duration
//            let endOffset = (Double(text.distance(from: text.startIndex, to: end)) / totalChars) * duration
//
//            subs.append(CaptionLine(
//                id: "\(line.id)_s\(i)",
//                start: line.start + startOffset,
//                end: line.start + endOffset,
//                text: subText,
//                ruby: nil
//            ))
//            start = end
//            i += 1
//        }
//        return subs
//    }
//    func cleanSubtitleText(_ rawText: String) -> String {
//        var text = rawText.replacingOccurrences(of: "\\[.*?\\]", with: "", options: .regularExpression)
//
//        // 2. 定義「絕對安全」的白名單正則表達式
//        // \u3040-\u309F: 平假名
//        // \u30A0-\u30FF: 片假名
//        // \u4E00-\u9FAF: 常用漢字
//        // \uFF00-\uFFEF: 全角符號與數字
//        // \u3000-\u303F: 日文標點
//        // a-zA-Z0-0: 基礎英數
//        // \\s: 空格
//        let pattern = "[^\\u3040-\\u309F\\u30A0-\\u30FF\\u4E00-\\u9FAF\\uFF00-\\uFFEF\\u3000-\\u303Fga-zA-Z0-9\\s、。！？]"
//
//        text = text.replacingOccurrences(of: pattern, with: " ", options: .regularExpression) /// MARK:
//        text = text.components(separatedBy: CharacterSet.controlCharacters).joined()
//
//        return text.trimmingCharacters(in: .whitespacesAndNewlines)
//    }
//
//    func processSubtitlesByPunctuation(_ lines: [CaptionLine], targetLength: Int = 28) -> [CaptionLine] {
//        guard !lines.isEmpty else { return [] }
//
//        var result: [CaptionLine] = []
//        let punctuations: Set<Character> = ["。", "！", "？", "；", "!", "?", ";"]
//        let softPunctuations: Set<Character> = ["、", "，", ",", " "]
//
//        var currentText = ""
//        var currentStart = lines[0].start
//
//        for (index, line) in lines.enumerated() {
//
//            let cleaned = cleanSubtitleText(line.text)
//            if cleaned.isEmpty { continue }
//
//            if cleaned.count > 26 {
//                if !currentText.isEmpty {
//                result.append(
//                    CaptionLine(
//                        id: "merged_\(result.count)",
//                        start: currentStart,
//                        end: line.start,
//                        text: currentText,
//                        ruby: nil
//                    )
//                )
//                    currentText = ""
//                }
//
//                let subLines = splitSingleLongLine(line, maxChars: 26)
//                result.append(contentsOf: subLines)
//
//                if index + 1 < lines.count {
//                    currentStart = lines[index + 1].start
//                }
//                continue
//            }
//
//            currentText += cleaned
//            var shouldSplit = false
//            if currentText.count >= 26 { shouldSplit = true }
//            else if currentText.count >= 20 && cleaned.last != nil && punctuations.contains(cleaned.last!) { shouldSplit = true }
//            else if currentText.count >= 28 && cleaned.last != nil && softPunctuations.contains(cleaned.last!) { shouldSplit = true }
//            else if index == lines.count - 1 { shouldSplit = true }
//
//            if shouldSplit {
//                result.append(
//                    CaptionLine(
//                        id: "merged_\(result.count)",
//                        start: currentStart,
//                        end: line.end,
//                        text: currentText,
//                        ruby: nil
//                    )
//                )
//                if index + 1 < lines.count {
//                    currentStart = lines[index + 1].start
//                    currentText = ""
//                }
//            }
//        }
//
//        return result
//    }
}
