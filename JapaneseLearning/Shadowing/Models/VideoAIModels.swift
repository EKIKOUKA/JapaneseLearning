//
//  VideoAIModes.swift
//  JapaneseLearning
//
//  Created by Makoto on 2026/11/07.
//

import Foundation

enum VideoAIMode: String, Codable, CaseIterable, Identifiable {
    case original, segmentation, transcription
    var id: String { rawValue }
    var title: String {
        switch self {
            case .original: "元の字幕（無料）"
            case .segmentation: "AI で文を区切る"
            case .transcription: "AI で音声から字幕を生成"
        }
    }
}
struct VideoAIQuote: Decodable, Identifiable {
    let id: String
    let youtube_id: String
    let credits: Int
    let duration_seconds: Double
    let expires_at: Double
}
struct VideoAIJob: Decodable {
    let id: String
    let mode: String
    let status: String
    let credits_requested: Int
    let progress: Double
    let stage: String
    let error: String?
    var stageTitle: String {
        switch stage {
            case "queued": "順番待ち"
            case "preparing": "準備中"
            case "segmenting": "字幕を区切っています"
            case "transcribing": "音声を認識しています"
            case "saving": "字幕を保存しています"
            case "completed": "完了"
            default: "生成に失敗しました"
        }
    }
}
struct VideoAIStatus: Decodable { let job: VideoAIJob? }
struct CaptionVersion: Decodable, Identifiable {
    let id: String
    let source: String
    let created_at: String
    let model: String?
    var title: String {
        let label = VideoAIMode(rawValue: source)?.title ?? "元の字幕"
        guard source == "transcription", let model else { return label }
        return "\(label)（\(model == "whisper-1" ? "Whisper" : "Gemini")）"
    }
}
struct CaptionVersionsResponse: Decodable {
    let active_version: String
    let versions: [CaptionVersion]
}
