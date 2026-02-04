//
//  QuickActionTarget.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/01/16.
//

import Foundation

enum QuickActionTarget: Hashable {
    case lastGrammar(id: UUID, level: String)
    case resumeVideo(id: String)
}
