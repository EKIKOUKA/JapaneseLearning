//
//  SubtitleRenderingPreview.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/11/24.
//

import SwiftUI

struct SubtitleRenderingPreview: View {
    private enum Sample: String, CaseIterable {
        case normal = "通常の字幕"
        case longRuby = "行頭・長いルビ"
        case adjacentRuby = "隣接するルビ"
        case wrapped = "折り返し"
        case mismatched = "字幕と断片が一致してない"
        case invalidTiming = "時刻が無効"
        case mixedTiming = "一部の時刻が無効"
        case noSegments = "断片なし"
        case singleStart = "開始時刻が同じ"
        case splitRuby = "ルビの途中で断片が分かれる"
        case gap = "断片の間に休止"
        case padded = "断片に前後の空白"
        case layerFailure = "レイヤー作成失敗（再現）"

        var parts: [String] {
            switch self {
                case .normal: ["今日は", "天気が", "いい", "です", "ね。"]
                case .longRuby, .mismatched, .invalidTiming, .mixedTiming, .noSegments, .singleStart, .gap, .padded, .layerFailure:
                    ["私", "以外", "の慮るにね"]
                case .adjacentRuby: ["行", "雷", "が聞こえる"]
                case .wrapped: ["私", "以外", "の慮るにもこの長い文章🇹🇼を読んで", "もらいます"]
                case .splitRuby: ["私", "以", "外", "の話"]
            }
        }

        var expectation: String {
            switch self {
                case .mismatched, .invalidTiming, .noSegments, .singleStart:
                    "字幕全体を表示し、文字単位の強調は行わない"
                case .mixedTiming:
                    "終了時刻が無効な「以外」も、1 秒で一度に強調する"
                case .layerFailure:
                    "字幕とルビを全体色で表示する。掃引・浮き上がりなし"
                case .splitRuby:
                    "「以外」のルビと親文字がまとまって浮き上がる"
                case .gap:
                    "休止中は次の断片の強調が始まらない"
                case .padded:
                    "前後の空白があっても文字位置がずれない"
                default:
                    "ルビと親文字を表示し、時刻に合わせて強調する"
            }
        }
    }

    @State private var sample = Sample.normal
    @State private var time = 0.0
    @State private var karaoke = true
    @State private var narrow = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("字幕レンダリング")
                    .font(.title2.bold())
                previewCard
                controls
            }
            .frame(maxWidth: 460)
            .padding()
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .preferredColorScheme(.dark)
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            casePicker
            subtitle
                .frame(maxWidth: .infinity, minHeight: 140)
                .padding(.vertical, 12)
                .background(.black, in: RoundedRectangle(cornerRadius: 16))
            Text(sample.expectation)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent("再生位置") {
                Text("\(time, specifier: "%.2f") 秒")
                    .monospacedDigit()
            }
            Slider(value: $time, in: 0...5) {
                Text("再生位置")
            }
            Divider()
            Toggle("カラオケ効果", isOn: $karaoke)
            Toggle("狭い表示幅", isOn: $narrow)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var casePicker: some View {
        Picker("ケース", selection: $sample) {
            ForEach(Sample.allCases, id: \.self) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.menu)
        .onChange(of: sample) {
            time = 0.0
        }
    }

    private var subtitle: some View {
        let text = sample.parts.joined()
        let label = RubyLabel(
            text: text, rubyRanges: rubyRanges(in: text), fontSizeScale: 1, fontStyle: .system,
            fontColor: .white, karaokeSegments: timedSegments, karaokeTime: time,
            karaokeAnimationRate: 0, simulateLayerBuildFailure: sample == .layerFailure,
            onTapWord: { _ in }, onTapLine: {}
        )
        let width: CGFloat = narrow ? 160 : 300
        
        return label.id(sample).fixedSize(horizontal: false, vertical: true).frame(width: width)
    }

    private func rubyRanges(in text: String) -> [RubyWordRange] {
        let readings = [("今日", "きょう"), ("天気", "てんき"), ("私", "わたくし"), ("以外", "いがい"), ("慮る", "おもんぱかる"),
                        ("行", "ぎょう"), ("雷", "かみなり")]
        return readings.compactMap { surface, reading in
            let range = (text as NSString).range(of: surface)
            guard range.location != NSNotFound else { return nil }
            
            return RubyWordRange(range: range, surface: surface, reading: reading)
        }
    }

    private var timedSegments: [CaptionSegment]? {
        guard karaoke, sample != .noSegments else { return nil }
        let segments: [CaptionSegment] = sample.parts.enumerated().map { index, part in
            let start = sample == .singleStart ? 0 : Double(index) * (sample == .gap ? 2 : 1)
            var text = sample == .mismatched && index == 0 ? "僕" : part
            if sample == .padded {
                if index == 0 { text = "  " + text }
                if index == sample.parts.count - 1 { text += "  " }
            }
            let end = sample == .invalidTiming ? start : start + 1
            
            return CaptionSegment(
                text: text,
                start: start,
                end: sample == .mixedTiming && index == 1 ? .infinity : end
            )
        }
        let valid = segments.filter { $0.start.isFinite && $0.end.isFinite && $0.end > $0.start }
        
        return Set(valid.map(\.start)).count > 1 ? segments : nil
    }
}

#Preview("字幕レンダリング") {
    SubtitleRenderingPreview()
}
