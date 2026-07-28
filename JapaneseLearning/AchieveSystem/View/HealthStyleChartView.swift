//
//  HealthStyleChartView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 5/14/R8.
//

import SwiftUI
import Charts

struct HealthStyleChartView: View {
    let goalMinutes: Double
    let accent: Color
    let points: [PracticeChartPoint]
    let range: PracticeRange
    let onPageChange: (Int) -> Void
    let canPageChange: (Int) -> Bool

    @State private var displayedPoints: [PracticeChartPoint] = []
    @State private var dragOffset: CGFloat = 0
    @State private var isSettling = false

    var body: some View {
        HStack(spacing: 10) {
            GeometryReader { geometry in
                let pageWidth = max(geometry.size.width, 1)

                HStack(spacing: 0) {
                    chartPage(dateOffset: -1)
                        .frame(width: pageWidth)

                    chartPage(dateOffset: 0)
                        .frame(width: pageWidth)

                    chartPage(dateOffset: 1)
                        .frame(width: pageWidth)
                }
                .frame(width: pageWidth * 3, alignment: .leading)
                .offset(x: -pageWidth + dragOffset)
                .contentShape(Rectangle())
                .simultaneousGesture(pageGesture(pageWidth: pageWidth))
            }
            .clipped()

            targetLabel
        }
        .frame(height: 250)
        .onAppear {
            displayedPoints = points
        }
        .onChange(of: points) { _, newPoints in
            withAnimation(.smooth(duration: 0.2)) {
                displayedPoints = newPoints
            }
        }
        .onChange(of: range) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                dragOffset = 0
                displayedPoints = points
            }
        }
    }

    private func chartPage(dateOffset: Int) -> some View {
        let pagePoints = shiftedPoints(displayedPoints.isEmpty ? points : displayedPoints, steps: dateOffset)
        let width = barWidth(for: pagePoints.count)

        return Chart {
            ForEach(pagePoints) { point in
                let index = pagePoints.firstIndex(where: { $0.id == point.id }) ?? 0
                let totalMinutes = point.jaMinutes + point.enMinutes
                let barOpacity = range == .day || totalMinutes >= goalMinutes ? 1.0 : 0.5

                BarMark(
                    x: .value("Slot", Double(index)),
                    y: .value("Minutes", totalMinutes),
                    width: width
                )
                .foregroundStyle(accent)
                .opacity(barOpacity)
            }

            if range != .day {
                RuleMark(y: .value("Goal", goalMinutes))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [7, 7]))
                    .foregroundStyle(accent.opacity(0.82))
            }
        }
        .chartXScale(domain: xDomain(for: pagePoints.count))
        .chartYScale(domain: yDomain(for: pagePoints))
        .chartPlotStyle { plotArea in
            plotArea
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color(.systemGray3))
                        .frame(height: 1)
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color(.systemGray3))
                        .frame(height: 1)
                }
        }
        .chartXAxis {
            AxisMarks(values: separatorPositions(for: pagePoints.count)) { _ in
                AxisGridLine(
                    stroke: StrokeStyle(lineWidth: 1, dash: [4, 5])
                )
                .foregroundStyle(Color(.systemGray3))
            }
        }
        .chartYAxis(.hidden)
    }

    private var targetLabel: some View {
        let currentPoints = displayedPoints.isEmpty ? points : displayedPoints
        let upperBound = yDomain(for: currentPoints).upperBound

        return GeometryReader { geometry in
            let targetY = min(
                max(24, geometry.size.height * (1 - goalMinutes / upperBound)),
                geometry.size.height - 24
            )

            if range != .day {
                VStack(alignment: .leading, spacing: 2) {
                    Text("目標")
                    Text("\(Int(goalMinutes))")
                }
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(accent)
                .position(x: 10, y: targetY)
            }

            Text("0 分")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.secondary)
                .position(x: 10, y: geometry.size.height)
        }
        .frame(width: 27, alignment: .center)
    }

    private func xDomain(for count: Int) -> ClosedRange<Double> {
        let lastSlot = Double(max(count - 1, 0))
        return -0.5...(lastSlot + 0.5)
    }

    private func barWidth(for count: Int) -> MarkDimension {
        let width: CGFloat

        switch range {
            case .week:
                width = 30
            case .year:
                width = 18
            default:
                width = 175 / CGFloat(max(count, 1))
        }

        return .fixed(min(max(width, 5), 30))
    }

    private func separatorPositions(for count: Int) -> [Double] {
        guard count > 0 else { return [] }

        let interval: Int
        switch range {
            case .day:
                interval = 6
            case .week, .year:
                interval = 1
            case .month:
                interval = 7
            case .sixMonths:
                interval = 4
        }

        var positions = [-0.5, Double(count) - 0.5]
        positions += stride(from: interval, to: count, by: interval).map {
            Double($0) - 0.5
        }
        return positions
    }

    private func yDomain(for pagePoints: [PracticeChartPoint]) -> ClosedRange<Double> {
        let maximum = pagePoints.map { $0.jaMinutes + $0.enMinutes }.max() ?? 0
        let upper = max(
            goalMinutes * 1.2,
            ceil(max(maximum, goalMinutes) * 1.2 / 10) * 10
        )
        return 0...upper
    }

    private func pageGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard !isSettling,
                      abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }
                dragOffset = value.translation.width
            }
            .onEnded { value in
                guard !isSettling,
                      abs(value.translation.width) > abs(value.translation.height),
                      abs(value.translation.width) > 8 else {
                    withAnimation(.snappy(duration: 0.22, extraBounce: 0)) {
                        dragOffset = 0
                    }
                    return
                }

                let projected = value.predictedEndTranslation.width
                let direction = projected < 0 ? 1 : -1
                let projectedPageCount = Int((abs(projected) / pageWidth).rounded())
                let steps = direction * min(max(projectedPageCount, 1), 12)
                let destinationOffset = direction > 0 ? -pageWidth : pageWidth

                guard canPageChange(steps) else {
                    withAnimation(.snappy(duration: 0.25, extraBounce: 0.08)) {
                        dragOffset = 0
                    }
                    return
                }

                isSettling = true
                withAnimation(
                    .snappy(duration: 0.28, extraBounce: 0),
                    completionCriteria: .logicallyComplete
                ) {
                    dragOffset = destinationOffset
                } completion: {
                    let placeholder = shiftedPoints(
                        displayedPoints.isEmpty ? points : displayedPoints,
                        steps: steps
                    )
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        displayedPoints = placeholder
                        dragOffset = 0
                    }

                    onPageChange(steps)
                    isSettling = false
                }
            }
    }

    private func shiftedPoints(_ source: [PracticeChartPoint], steps: Int) -> [PracticeChartPoint] {
        guard steps != 0 else { return source }

        return source.map { point in
            PracticeChartPoint(
                date: shiftedDate(point.date, steps: steps),
                jaMinutes: point.jaMinutes,
                enMinutes: point.enMinutes
            )
        }
    }

    private func shiftedDate(_ date: Date, steps: Int) -> Date {
        let calendar = AchieveSystemStore.tokyoCalendar
        switch range {
            case .day:
                return calendar.date(byAdding: .day, value: steps, to: date) ?? date
            case .week:
                return calendar.date(byAdding: .day, value: steps * 7, to: date) ?? date
            case .month:
                return calendar.date(byAdding: .month, value: steps, to: date) ?? date
            case .sixMonths:
                return calendar.date(byAdding: .month, value: steps * 6, to: date) ?? date
            case .year:
                return calendar.date(byAdding: .year, value: steps, to: date) ?? date
        }
    }
}
