import Foundation
import Testing
@testable import JapaneseLearning

@MainActor
@Suite("Utility helpers")
struct UtilityTests {
    @Test("Detects whitespace-only strings")
    func whitespaceDetection() {
        #expect("   \n".isWhitespaceOrNewLine)
        #expect(!"  こんにちは  ".isWhitespaceOrNewLine)
    }

    @Test("Cleans common video title noise")
    func cleanedVideoTitle() {
        print("How to make Japanese friends / 日本人と友達になる方法".cleanedVideoTitle)
        #expect("How to make Japanese friends / 日本人と友達になる方法".cleanedVideoTitle == "日本人と友達になる方法")
        print("見えない体の悩み❤️‍🩹1か月レッスンを休んで考えたこと｜日本語ポッドキャスト、N3～N1聴解【中級、上級】".cleanedVideoTitle)
        #expect("「師走」12月の昔の言い方 #1 | 日本語ポッドキャスト".cleanedVideoTitle == "「師走」12月の昔の言い方 #1")
    }

    @Test("Formats playback time as mm:ss")
    func currentTimeFormatting() {
        #expect(currentTimeFormatted(0) == "00:00")
        #expect(currentTimeFormatted(125) == "02:05")
    }

    @Test("Formats SQLite dates in Asia/Tokyo")
    func sqliteDateFormatting() {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 6
        components.day = 27
        components.hour = 15
        components.minute = 0
        components.second = 0

        let date = components.date!

        #expect(sqliteDateString(from: date) == "2026-06-28")
        #expect(sqliteDateTimeString(from: date) == "2026-06-28 00:00:00")
        #expect(PracticeDateFormat.sqliteDateTime(from: "2026-06-28 00:00:00") != nil)
    }
}
