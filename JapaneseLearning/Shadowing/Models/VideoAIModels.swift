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
