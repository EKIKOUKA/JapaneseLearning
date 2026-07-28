//
//  AchieveSystemView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 4/28/R8.
//

import SwiftUI

struct AchieveSystemView: View {
    @State private var store = AchieveSystemStore()
    @State private var selectedRange: PracticeRange = .day
    @State private var language: LanguageFilter = .all

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    rangePicker
                    summaryCard
                    chartCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .navigationTitle("学習記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Menu {
                            Picker("言語", selection: $language) {
                                ForEach(LanguageFilter.allCases, id: \.self) {
                                    Text($0.rawValue)
                                }
                            }
                        } label: {
                            Label("表示言語", systemImage: "arrow.up.arrow.down")
                        }

                        NavigationLink(destination: AchieveSystemRecord(store: store)) {
                            HStack(spacing: 10) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("記録詳細")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .background(backgroundView.ignoresSafeArea())
        }
        .onAppear {
            Task {
                await store.fetchPracticeSessions(
                    anchorDate: Date()
                )
            }
        }
        .onChange(of: selectedRange) { _, newValue in
            Task {
                await store.updateRange(newValue)
            }
        }
        .onChange(of: language) { _, newValue in
            store.updateLanguage(newValue)
        }
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.secondarySystemBackground),
                Color(.tertiarySystemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var rangePicker: some View {
        Picker("", selection: $selectedRange) {
            ForEach(PracticeRange.allCases) { range in
                Text(range.title).tag(range)
            }
        }
        .pickerStyle(.tabs)
    }

    private var summaryCard: some View {
        let totalMinutes = Int(store.totalMinutes.rounded())
        let progress = min(store.progressRatio, 1)
        let progressPercent = Int((progress * 100).rounded())
        let accent = rangeAccent(for: selectedRange)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("練習進度")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.62))
                    Text(store.windowTitle)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }

            HStack(spacing: 0) {
                summaryMetric(title: "合計", value: "\(totalMinutes)", suffix: "分", accent: .pink)
                Divider()
                    .overlay(Color.primary.opacity(0.10))
                    .padding(.vertical, 4)
                summaryMetric(title: "達成率", value: "\(progressPercent)", suffix: "%", accent: .green)
                    .padding(.leading, 10)
            }

            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: progress)
                    .tint(accent)
                    .scaleEffect(x: 1, y: 1.25, anchor: .center)

                Text("64分を基準に、日・週・月・6か月・年の流れを確認できます。")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.secondary.opacity(0.50))
            }
        }
        .padding(.horizontal, 4)
    }

    private func summaryMetric(title: String, value: String, suffix: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(accent)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                if !suffix.isEmpty {
                    Text(suffix)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.secondary.opacity(0.55))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chartCard: some View {
        let accent = rangeAccent(for: selectedRange)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(selectedRange.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)

                Spacer()

                if !store.chartCountText.isEmpty {
                    Text(store.chartCountText)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.trailing, 44)
                }
            }

            HealthStyleChartView(
                goalMinutes: store.goalMinutes,
                accent: accent,
                points: store.chartPoints,
                range: selectedRange,
                onPageChange: { steps in
                    store.shiftVisibleWindow(steps: steps)
                },
                canPageChange: { steps in
                    store.canShiftVisibleWindow(steps: steps)
                }
            )
        }
    }

    private func rangeAccent(for range: PracticeRange) -> Color {
        switch range {
            case .day: return Color.pink
            case .week: return Color(red: 1.0, green: 0.35, blue: 0.62)
            case .month: return Color(red: 0.70, green: 0.95, blue: 0.00)
            case .sixMonths: return Color(red: 0.00, green: 0.93, blue: 0.90)
            case .year: return Color(red: 0.26, green: 0.70, blue: 1.0)
        }
    }
}

#Preview() {
    AchieveSystemView()
}
