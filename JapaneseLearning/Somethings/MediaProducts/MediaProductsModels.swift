//
//  MediaProductsModels.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 8/01/14.
//

import Foundation

struct MediaProductsItem: Codable, Identifiable {
    let id: UUID
    var title: String
    var category: MediaCategory
    var status: WatchStatus
    var detailsURL: String?
    var memo: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case category
        case status
        case detailsURL = "details_url"
        case memo
        case createdAt = "created_at"
    }
}

// Category
enum MediaCategory: String, Codable, CaseIterable, Identifiable {
    case drama
    case anime
    case movie

    var id: String { rawValue }

    var displayName: String {
        switch self {
            case .drama: return "ドラマ"
            case .anime: return "アニメ"
            case .movie: return "映画"
        }
    }
}

// Sort Order
enum MediaProductsSortOrder: String, CaseIterable, Identifiable {
    case createdAt
    case title

    var id: String { rawValue }

    var displayName: String {
        switch self {
            case .createdAt:
                return "作成日"
            case .title:
                return "タイトル"
        }
    }
}

enum WatchStatus: String, Codable, CaseIterable, Identifiable {
    case want
    case watched

    var id: String { rawValue }

    var displayName: String {
        switch self {
            case .watched: return "観た"
            case .want: return "観たい"
        }
    }
}

