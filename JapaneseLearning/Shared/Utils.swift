//
//  Utils.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 4/28/R8.
//

import SwiftUI
import Foundation
import UIKit

extension String {
    var isWhitespaceOrNewLine: Bool {
        return self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var cleanedVideoTitle: String {
        return String(
            self.filter { character in
                !character.unicodeScalars.contains { scalar in
                    scalar.properties.isEmojiPresentation
                }
            }
        )
        .replacingOccurrences(of: "【.*?】", with: "", options: .regularExpression)
        .replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression)
        .replacingOccurrences(of: "（.*?）", with: "", options: .regularExpression)
        .replacingOccurrences(
            of: "(?i)YUYUの日本語Podcast:?|Japanese Listening Practice|yuyu japanese podcast|Native Japanese Listening(?: Podcast)?",
            with: "",
            options: .regularExpression
        )
        .replacingOccurrences(of: "\\s*\\|\\|\\s*", with: "", options: .regularExpression)
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension View {
    @ViewBuilder
    func ModifierApplyIf<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

extension Array {
    mutating func apply<CollectionID: Hashable & Sendable>(
        difference: ReorderDifference<Element.ID, CollectionID>
    ) where Element: Identifiable, Element.ID: Sendable {
        guard let sourceIndex = firstIndex(where: { $0.id == difference.sources[0] }) else { return }
        let movedItem = remove(at: sourceIndex)

        var destination: Int

        switch difference.destination.position {
            case let .before(value):
                guard let index = firstIndex(where: { $0.id == value }) else { return }
                destination = index
            case .end:
                destination = endIndex
        }

        insert(movedItem, at: destination)
    }
}

func currentTimeFormatted(_ time: Int) -> String {
    let totalSeconds = time
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    let formatted = String(format: "%02d:%02d", minutes, seconds)

    return formatted
}


func sqliteDateTimeString(from date: Date) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.calendar = Calendar(identifier: .gregorian)
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return dateFormatter.string(from: date)
}
func sqliteDateString(from date: Date) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.calendar = Calendar(identifier: .gregorian)
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
    dateFormatter.dateFormat = "yyyy-MM-dd"
    return dateFormatter.string(from: date)
}

enum PracticeDateFormat {
    static func sqliteDateTime(from string: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.date(from: string)
    }
    static func YearMonthLabel(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }

    static func monthLabel(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "M月"
        return formatter.string(from: date)
    }

    static func monthDayLabel(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}

extension UIColor {
    var rgbaCacheKey: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return description
        }

        return String(format: "%.3f-%.3f-%.3f-%.3f", red, green, blue, alpha)
    }
}
