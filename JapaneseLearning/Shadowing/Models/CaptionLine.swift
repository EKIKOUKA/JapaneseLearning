//
//  CaptionLine.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/28.
//

import Foundation

// 1. 字幕資料模型
struct RubyWord: Codable, Equatable {
    let surface: String
    let reading: String
    let start: Int
    let length: Int
}

struct CaptionLine: Identifiable, Equatable, Codable {
    let id: String
    let start: Double
    let end: Double
    let text: String
    let ruby: [RubyWord]?
}
