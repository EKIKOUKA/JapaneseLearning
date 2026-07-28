//
//  AchieveSystemModel.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R8/04/28.
//

import Foundation

enum LanguageFilter: String, CaseIterable {
    case all = "全部"
    case ja = "日本語"
    case en = "英語"
}

enum PracticeRange: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case sixMonths
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
            case .day: return "日"
            case .week: return "週"
            case .month: return "月"
            case .sixMonths: return "6か月"
            case .year: return "年"
        }
    }

    var visibleBarCount: Int {
        switch self {
            case .day: return 24
            case .week: return 7
            case .month: return 30
            case .sixMonths: return 26
            case .year: return 12
        }
    }

    var countSuffix: String {
        switch self {
            case .day: return "時間"
            case .week, .month: return "日間"
            case .sixMonths: return "週間"
            case .year: return "か月"
        }
    }

    var isContinuousPagingEnabled: Bool {
        self != .day
    }
}

extension PracticeRange {
    var barUnit: Calendar.Component {
        switch self {
            case .day: return .hour
            case .week, .month: return .day
            case .sixMonths: return .weekOfYear
            case .year: return .month
        }
    }

    var scrollMatching: DateComponents {
        switch self {
            case .day: return DateComponents(hour: 1)
            case .week, .month: return DateComponents(day: 1)
            case .sixMonths: return DateComponents(weekOfYear: 1)
            case .year: return DateComponents(month: 1)
        }
    }

    var majorAlignment: DateComponents {
        switch self {
            case .day: return DateComponents(day: 1)
            case .week: return DateComponents(weekOfYear: 1)
            case .month: return DateComponents(month: 1)
            case .sixMonths: return DateComponents(month: 6)
            case .year: return DateComponents(year: 1)
        }
    }

    var visibleDomainSeconds: TimeInterval {
        switch self {
            case .day: return 3600 * 24
            case .week: return 3600 * 24 * 7
            case .month: return 3600 * 24 * 30
            case .sixMonths: return 3600 * 24 * 7 * 26
            case .year: return 3600 * 24 * 365
        }
    }
}

struct PracticeTimingRow: Codable, Identifiable, Hashable {
    let id: UUID
    let started_at: String
    let duration_seconds: Int
    let content_language: String?
}

struct PracticeChartPoint: Identifiable, Hashable {
    let date: Date
    let jaMinutes: Double
    let enMinutes: Double

    var id: Date {
        date
    }
}
