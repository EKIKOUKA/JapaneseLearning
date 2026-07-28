//
//  AchieveSystemStore.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 4/28/R8.
//

import Observation
import Foundation

@MainActor
@Observable
class AchieveSystemStore {
    var rawSessions: [PracticeTimingRow] = []
    var chartPoints: [PracticeChartPoint] = []
    var selectedRange: PracticeRange = .day
    var language: LanguageFilter = .all
    var selectedDate: Date = Date()
    var isRefreshing = false
    let goalMinutes: Double = 64

    @ObservationIgnored
    private let cacheKey = "achieve_system_practice_sessions_v1"

    private var loadToken: Int = 0

    init() {
        loadCache()
        selectedDate = Self.normalizedAnchorDate(Date(), range: selectedRange)
        rebuildChartWindow()
    }

    func reload() async {
        await fetchPracticeSessions(
            anchorDate: selectedDate,
            language: language
        )
    }

    func updateRange(_ range: PracticeRange) async {
        selectedRange = range
        selectedDate = Self.normalizedAnchorDate(Date(), range: range)
        rebuildChartWindow()
    }

    func canShiftVisibleWindow(steps: Int) -> Bool {
        guard steps != 0 else { return false }

        let candidate = Self.shiftDate(from: selectedDate, range: selectedRange, steps: steps)
        let latest = Self.normalizedAnchorDate(Date(), range: selectedRange)
        guard candidate <= latest else { return false }

        guard steps < 0 else { return true }
        guard let earliestPracticeDate = filteredRawSessions.compactMap({
            PracticeDateFormat.sqliteDateTime(from: $0.started_at)
        }).min() else {
            return false
        }

        let earliestPracticeDay = Self.tokyoCalendar.startOfDay(for: earliestPracticeDate)
        let candidateBounds = Self.queryBounds(for: selectedRange, referenceDate: candidate)
        return candidateBounds.end >= earliestPracticeDay
    }

    func shiftVisibleWindow(steps: Int) {
        guard steps != 0, canShiftVisibleWindow(steps: steps) else { return }
        selectedDate = Self.shiftDate(from: selectedDate, range: selectedRange, steps: steps)
        rebuildChartWindow()
    }

    func updateLanguage(_ language: LanguageFilter) {
        self.language = language
        rebuildChartWindow()
    }

    func fetchPracticeSessions(
        anchorDate: Date,
        language: LanguageFilter = .all
    ) async {
        self.language = language
        selectedDate = Self.normalizedAnchorDate(anchorDate, range: selectedRange)
        rebuildChartWindow()

        loadToken += 1
        let token = loadToken
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let queryData = Self.makeQuery()
            let rows: [PracticeTimingRow] = try await WorkersAPI.get(queryData.path, queryItems: queryData.queryItems)
            guard token == loadToken else { return }

            rawSessions = rows.sorted { $0.started_at < $1.started_at }
            saveCache()
            rebuildChartWindow()
        } catch {
            print("❌ Fetch Error (using practice cache): \(error)")
        }
    }

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cachedRows = try? JSONDecoder().decode([PracticeTimingRow].self, from: data) else {
            return
        }

        rawSessions = cachedRows.sorted { $0.started_at < $1.started_at }
    }

    private func saveCache() {
        guard let data = try? JSONEncoder().encode(rawSessions) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private func rebuildChartWindow() {
        chartPoints = Self.makeChartPoints(
            from: filteredRawSessions,
            range: selectedRange,
            anchorDate: selectedDate
        )
    }

    var totalMinutes: Double {
        guard selectedRange == .sixMonths || selectedRange == .year else {
            return chartPoints.reduce(0) {
                $0 + $1.jaMinutes + $1.enMinutes
            }
        }

        let bounds = Self.queryBounds(for: selectedRange, referenceDate: selectedDate)
        let seconds = filteredRawSessions.reduce(into: 0) { total, row in
            guard let date = PracticeDateFormat.sqliteDateTime(from: row.started_at) else { return }
            let day = Self.tokyoCalendar.startOfDay(for: date)
            guard day >= bounds.start && day <= bounds.end else { return }
            total += row.duration_seconds
        }
        return Double(seconds) / 60.0
    }

    private var filteredRawSessions: [PracticeTimingRow] {
        rawSessions.filter { row in
            switch language {
                case .all: return true
                case .ja: return row.content_language == "ja"
                case .en: return row.content_language == "en"
            }
        }
    }

    var progressRatio: Double {
        switch selectedRange {
            case .day:
                return totalMinutes / goalMinutes
            default:
                let successCount = chartPoints.filter { ($0.jaMinutes + $0.enMinutes) >= goalMinutes }.count
                return chartPoints.isEmpty ? 0 : Double(successCount) / Double(chartPoints.count)
        }
    }

    var activeBarCount: Int {
        chartPoints.filter { ($0.jaMinutes + $0.enMinutes) > 0 }.count
    }

    var goalHitCount: Int {
        chartPoints.filter { ($0.jaMinutes + $0.enMinutes) >= goalMinutes }.count
    }

    var chartCountText: String {
        switch selectedRange {
            case .day:
                return "\(activeBarCount) / \(chartPoints.count)時間"
            case .week, .month:
                return "\(goalHitCount) / \(chartPoints.count)日間"
            case .sixMonths, .year:
                return ""
        }
    }

    var windowTitle: String {
        Self.windowTitle(range: selectedRange, anchorDate: selectedDate)
    }

    static func totalMinutes(_ items: [PracticeTimingRow]) -> Double {
        Double(items.reduce(0) { $0 + $1.duration_seconds }) / 60.0
    }

    static func makeQuery() -> (path: String, queryItems: [URLQueryItem]) {
        let start = Date(timeIntervalSince1970: 0)
        let end = tokyoCalendar.startOfDay(for: Date())

        return (
            "fetch_practice_sessions",
            [
                URLQueryItem(name: "start_date", value: sqliteDateString(from: start)),
                URLQueryItem(name: "end_date", value: sqliteDateString(from: end)),
                URLQueryItem(name: "language", value: "")
            ]
        )
    }

    private static func sum(_ rows: [(date: Date, row: PracticeTimingRow)]) -> (ja: Int, en: Int) {
        var ja = 0
        var en = 0

        for item in rows {
            switch item.row.content_language {
            case "ja":
                ja += item.row.duration_seconds
            case "en":
                en += item.row.duration_seconds
            default:
                break
            }
        }

        return (ja, en)
    }

    static func buildPoints(
        dates: [Date],
        grouped: [Date: (ja: Int, en: Int)],
        divisor: Double = 1
    ) -> [PracticeChartPoint] {
        dates.sorted().map { date in
            let normalizedDate = date
            let seconds = grouped[normalizedDate] ?? (0, 0)

            return PracticeChartPoint(
                date: normalizedDate,
                jaMinutes: Double(seconds.ja) / 60.0 / divisor,
                enMinutes: Double(seconds.en) / 60.0 / divisor
            )
        }
    }

    static func buildAveragePoints(
        dates: [Date],
        grouped: [Date: (ja: Int, en: Int)],
        daysInBucket: (Date) -> Int
    ) -> [PracticeChartPoint] {
        dates.sorted().map { date in
            let seconds = grouped[date] ?? (0, 0)
            let divisor = Double(max(daysInBucket(date), 1))

            return PracticeChartPoint(
                date: date,
                jaMinutes: Double(seconds.ja) / 60.0 / divisor,
                enMinutes: Double(seconds.en) / 60.0 / divisor
            )
        }
    }

    static func bucketDate(_ date: Date, range: PracticeRange) -> Date {
        switch range {
            case .day:
                let comps = tokyoCalendar.dateComponents([.year, .month, .day, .hour], from: date)
                return tokyoCalendar.date(from: comps) ?? date
            case .week:
                return tokyoCalendar.startOfDay(for: date)
            case .month:
                return tokyoCalendar.startOfDay(for: date)
            case .sixMonths:
                return tokyoCalendar.startOfDay(for: startOfWeekSunday(for: date))
            case .year:
                let comps = tokyoCalendar.dateComponents([.year, .month], from: date)
                return tokyoCalendar.date(from: comps) ?? date
        }
    }

    static func makeChartPoints(
        from items: [PracticeTimingRow],
        range: PracticeRange,
        anchorDate: Date
    ) -> [PracticeChartPoint] {
        let sessions: [(date: Date, row: PracticeTimingRow)] = items.compactMap { row in
            guard let date = PracticeDateFormat.sqliteDateTime(from: row.started_at) else {
                return nil
            }
            return (date, row)
        }

        switch range {
            case .day:
                let grouped = Dictionary(grouping: sessions) {
                    Self.bucketDate($0.date, range: range)
                }
                .mapValues { Self.sum($0) }

                let dayStart = normalizedAnchorDate(anchorDate, range: .day)
                let dates = (0..<24).compactMap { hour in
                    tokyoCalendar.date(byAdding: .hour, value: hour, to: dayStart)
                }

                return buildPoints(
                    dates: dates,
                    grouped: grouped
                )

            case .week:
                let grouped = Dictionary(grouping: sessions) {
                    Self.bucketDate($0.date, range: range)
                }
                .mapValues { Self.sum($0) }

                return buildPoints(
                    dates: dailyBuckets(in: queryBounds(for: .week, referenceDate: anchorDate)),
                    grouped: grouped
                )

            case .month:
                let grouped = Dictionary(grouping: sessions) {
                    Self.bucketDate($0.date, range: range)
                }
                .mapValues { Self.sum($0) }

                return buildPoints(
                    dates: dailyBuckets(in: queryBounds(for: .month, referenceDate: anchorDate)),
                    grouped: grouped
                )

            case .sixMonths:
                let bounds = Self.queryBounds(for: .sixMonths, referenceDate: anchorDate)

                let filteredSessions = sessions.filter {
                    let day = tokyoCalendar.startOfDay(for: $0.date)
                    return day >= bounds.start && day <= bounds.end
                }

                let grouped = Dictionary(grouping: filteredSessions) {
                    Self.bucketDate($0.date, range: range)
                }
                .mapValues { Self.sum($0) }

                let weeks = weeklyBuckets(
                    from: startOfWeekSunday(for: bounds.start),
                    to: startOfWeekSunday(for: bounds.end)
                )

                return buildAveragePoints(dates: weeks, grouped: grouped) { weekStart in
                    let weekEnd = min(
                        tokyoCalendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart,
                        bounds.end
                    )
                    return (tokyoCalendar.dateComponents([.day], from: weekStart, to: weekEnd).day ?? 0) + 1
                }

            case .year:
                let bounds = Self.queryBounds(for: .year, referenceDate: anchorDate)
                let filteredSessions = sessions.filter {
                    let day = tokyoCalendar.startOfDay(for: $0.date)
                    return day >= bounds.start && day <= bounds.end
                }
                let months = monthlyBuckets(from: bounds.start, to: bounds.end)

                let filteredGrouped = Dictionary(grouping: filteredSessions) {
                    Self.bucketDate($0.date, range: range)
                }
                .mapValues { Self.sum($0) }

                return buildAveragePoints(dates: months, grouped: filteredGrouped) { monthStart in
                    let nextMonth = tokyoCalendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
                    let monthEnd = min(
                        tokyoCalendar.date(byAdding: .day, value: -1, to: nextMonth) ?? monthStart,
                        bounds.end
                    )
                    return (tokyoCalendar.dateComponents([.day], from: monthStart, to: monthEnd).day ?? 0) + 1
                }
        }
    }

    static func queryBounds(for range: PracticeRange, referenceDate: Date) -> (start: Date, end: Date) {
        let end = normalizedAnchorDate(referenceDate, range: range)

        let bounds: (start: Date, end: Date)

        switch range {
            case .day:
                bounds = (end, end)
            case .week:
                let start = startOfWeekSunday(for: end)
                let weekEnd = tokyoCalendar.date(byAdding: .day, value: 6, to: start) ?? end
                bounds = (start, weekEnd)
            case .month:
                let start = startOfMonth(for: end)
                let days = tokyoCalendar.range(of: .day, in: .month, for: start)?.count ?? 30
                let monthEnd = tokyoCalendar.date(byAdding: .day, value: days - 1, to: start) ?? end
                bounds = (start, monthEnd)
            case .sixMonths:
                let year = tokyoCalendar.component(.year, from: end)
                let month = tokyoCalendar.component(.month, from: end)

                let startComponents: DateComponents
                let endComponents: DateComponents

                if month <= 6 {
                    // 1月1日 ~ 6月30日
                    startComponents = DateComponents(year: year, month: 1, day: 1)
                    endComponents = DateComponents(year: year, month: 6, day: 30)
                } else {
                    // 7月1日 ~ 12月31日
                    startComponents = DateComponents(year: year, month: 7, day: 1)
                    endComponents = DateComponents(year: year, month: 12, day: 31)
                }

                let startDate = tokyoCalendar.date(from: startComponents) ?? end
                let endDate = tokyoCalendar.date(from: endComponents) ?? end
                bounds = (startDate, endDate)
            case .year:
                let start = startOfYear(for: end)
                let yearEnd = tokyoCalendar.date(byAdding: .month, value: 11, to: start) ?? end
                bounds = (start, yearEnd)
        }

        return bounds
    }

    static func dailyBuckets(in bounds: (start: Date, end: Date)) -> [Date] {
        var buckets: [Date] = []
        var current = bounds.start

        while current <= bounds.end {
            buckets.append(current)
            guard let next = tokyoCalendar.date(byAdding: .day, value: 1, to: current) else {
                break
            }
            current = next
        }

        return buckets
    }

    static func weeklyBuckets(from startDate: Date, to endDate: Date) -> [Date] {
        var buckets: [Date] = []
        var current = startDate

        while current <= endDate {
            buckets.append(current)
            guard let next = tokyoCalendar.date(byAdding: .day, value: 7, to: current) else { break }
            current = next
        }
        return buckets
    }

    static func monthlyBuckets(count: Int, referenceDate: Date) -> [Date] {
        let start = startOfYear(for: referenceDate)

        return (0..<count).compactMap { offset in
            guard let month = tokyoCalendar.date(
                byAdding: .month,
                value: offset,
                to: start
            ) else {
                return nil
            }

            return startOfMonth(for: month)
        }
    }

    static func monthlyBuckets(from startDate: Date, to endDate: Date) -> [Date] {
        var buckets: [Date] = []
        var current = startOfMonth(for: startDate)

        while current <= endDate {
            buckets.append(current)
            guard let next = tokyoCalendar.date(byAdding: .month, value: 1, to: current) else {
                break
            }
            current = next
        }

        return buckets
    }

    static func startOfWeek(for date: Date) -> Date {
        let calendar = tokyoCalendar
        let weekday = calendar.component(.weekday, from: date)
        let offset = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: date)) ?? date
    }

    static func startOfWeekSunday(for date: Date) -> Date {
        let calendar = tokyoCalendar
        let weekday = calendar.component(.weekday, from: date)
        let offset = weekday - 1 // Sunday = 1
        return calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: date)) ?? date
    }

    static func startOfMonth(for date: Date) -> Date {
        tokyoCalendar.date(from: tokyoCalendar.dateComponents([.year, .month], from: date)) ?? date
    }

    static func startOfYear(for date: Date) -> Date {
        tokyoCalendar.date(from: tokyoCalendar.dateComponents([.year], from: date)) ?? date
    }

    static func normalizedAnchorDate(_ date: Date, range: PracticeRange) -> Date {
        switch range {
            case .day:
                return tokyoCalendar.startOfDay(for: date)
            case .week:
                return startOfWeekSunday(for: date)
            case .month:
                return startOfMonth(for: date)
            case .sixMonths:
                let year = tokyoCalendar.component(.year, from: date)
                let month = tokyoCalendar.component(.month, from: date)
                let targetMonth = month <= 6 ? 1 : 7
                return tokyoCalendar.date(from: DateComponents(year: year, month: targetMonth, day: 1)) ?? date
            case .year:
                return startOfYear(for: date)
        }
    }

    static var tokyoCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar
    }

    static func shiftDate(from date: Date, range: PracticeRange, steps: Int) -> Date {
        let calendar = tokyoCalendar
        let base = normalizedAnchorDate(date, range: range)

        switch range {
            case .day:
                return calendar.date(byAdding: .day, value: steps, to: base) ?? date
            case .week:
                return calendar.date(byAdding: .day, value: steps * 7, to: base) ?? date
            case .month:
                return calendar.date(byAdding: .month, value: steps, to: base) ?? date
            case .sixMonths:
                return calendar.date(byAdding: .month, value: steps * 6, to: base) ?? date
            case .year:
                return calendar.date(byAdding: .year, value: steps, to: base) ?? date
        }
    }

    static func windowTitle(range: PracticeRange, anchorDate: Date) -> String {
        let bounds = queryBounds(for: range, referenceDate: anchorDate)

        switch range {
            case .day:
                return sqliteDateString(from: bounds.start)
            case .week:
                return "\(PracticeDateFormat.monthDayLabel(from: bounds.start)) 〜 \(PracticeDateFormat.monthDayLabel(from: bounds.end))"
            case .month:
                return "\(PracticeDateFormat.monthDayLabel(from: bounds.start)) 〜 \(PracticeDateFormat.monthDayLabel(from: bounds.end))"
            case .sixMonths:
                let year = tokyoCalendar.component(.year, from: bounds.start)
                let startMonth = tokyoCalendar.component(.month, from: bounds.start)
                let endMonth = tokyoCalendar.component(.month, from: bounds.end)
                return "\(year)年\(startMonth)月 〜 \(endMonth)月"
            case .year:
                return "\(PracticeDateFormat.YearMonthLabel(from: bounds.start)) ～ \(PracticeDateFormat.monthLabel(from: bounds.end))"
        }
    }

    func deleteRawRecord(_ id: UUID) async {
        do {
            try await WorkersAPI.post("delete_practice_session", body: [ "id": id ])
            rawSessions.removeAll { $0.id == id }
            saveCache()
            rebuildChartWindow()
        } catch {
            print("❌ Delete Error:", error)
        }
    }
}
