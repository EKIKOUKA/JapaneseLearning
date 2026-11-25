//
//  RubyLabel.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/25.
//

import SwiftUI
import os

struct RubyLabel: UIViewRepresentable {
    private static let attributedTextCache = NSCache<NSString, NSAttributedString>()

    let text: String
    let rubyRanges: [RubyWordRange]
    let fontSizeScale: Double
    let fontStyle: VideoSubtitleRubyFontStyle
    let fontColor: UIColor

    var karaokeSegments: [CaptionSegment]? = nil
    var karaokeTime: Double = 0
    var karaokeAnimationRate: Float? = nil
    var simulateLayerBuildFailure = false
    let onTapWord: (String) -> Void
    let onTapLine: () -> Void

    struct ContentIdentity: Equatable {
        let text: String
        let rubyRanges: [RubyWordRange]
        let fontSizeScale: Double
        let fontStyle: VideoSubtitleRubyFontStyle
        let fontColor: UIColor
    }

    final class Coordinator {
        var content: ContentIdentity?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> RubyUIView {
        let view = RubyUIView()
        view.simulateLayerBuildFailure = simulateLayerBuildFailure
        view.onTapWord = onTapWord
        view.onTapLine = onTapLine
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .vertical)
        return view
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: RubyUIView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        // 上方の行を再生成するときも、仮の幅で測定してから高さを変更しない。
        return uiView.measuredSize(for: width)
    }

    func updateUIView(_ uiView: RubyUIView, context: Context) {
        uiView.updateKaraoke(segments: karaokeSegments, time: karaokeTime, color: fontColor, animationRate: karaokeAnimationRate)
        uiView.onTapLine = onTapLine
        uiView.onTapWord = onTapWord

        // 時刻だけの更新では、ルビ文字列の連結やキャッシュキーの生成を省く。
        let identity = ContentIdentity(
            text: text, rubyRanges: rubyRanges, fontSizeScale: fontSizeScale,
            fontStyle: fontStyle, fontColor: fontColor
        )
        guard context.coordinator.content != identity else { return }
        context.coordinator.content = identity

        let key = Self.cacheKey(
            text: text,
            rubyRanges: rubyRanges,
            fontSizeScale: fontSizeScale,
            fontStyle: fontStyle,
            fontColor: fontColor
        )

        if uiView.contentKey != key {
            uiView.contentKey = key

            if let cached = Self.attributedTextCache.object(forKey: key as NSString) {
                uiView.attributedText = cached
                return
            }

            let attributedText = buildAttributedString()
            Self.attributedTextCache.setObject(attributedText, forKey: key as NSString)
            uiView.attributedText = attributedText
        }
    }

    private static func cacheKey(
        text: String,
        rubyRanges: [RubyWordRange],
        fontSizeScale: Double,
        fontStyle: VideoSubtitleRubyFontStyle,
        fontColor: UIColor
    ) -> String {
        let colorKey = fontColor.description

        let readings = rubyRanges.map { ruby in
            let reading = ruby.reading ?? ""
            return "\(ruby.range.location):\(ruby.range.length):\(reading.utf16.count):\(reading)"
        }.joined(separator: "|")
        
        return "\(text.utf16.count):\(text)|\(fontSizeScale)|\(fontStyle.rawValue)|\(colorKey)|\(readings)"
    }

    private func buildAttributedString() -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 6
        style.alignment = .left

        let baseFontSize: CGFloat = 32
        let baseFont: UIFont
        let baseFontSystem = UIFont.systemFont(ofSize: baseFontSize * fontSizeScale)

        switch fontStyle {
            case .system:
                baseFont = UIFont.systemFont(ofSize: baseFontSize * fontSizeScale, weight: .semibold)
            default:
                baseFont = UIFont(name: fontStyle.rawValue, size: baseFontSize * fontSizeScale) ?? baseFontSystem
        }

        let mutable = NSMutableAttributedString(string: rubyRanges.isEmpty ? text : text.trimmingCharacters(in: .whitespacesAndNewlines))

        mutable.addAttributes(
            [
                .font: baseFont,
                .foregroundColor: fontColor,
                .paragraphStyle: style
            ],
            range: NSRange(location: 0, length: mutable.length)
        )

        for ruby in rubyRanges {
            guard let reading = ruby.reading,
                  !reading.isEmpty,
                  reading != ruby.surface
            else { continue }

            let annotation = CTRubyAnnotationCreateWithAttributes(
                .center, .none, .before, reading as CFString,
                [kCTRubyAnnotationSizeFactorAttributeName: 0.45] as CFDictionary
            )

            mutable.addAttribute(
                kCTRubyAnnotationAttributeName as NSAttributedString.Key,
                value: annotation,
                range: ruby.range
            )
        }

        return mutable
    }
}

class RubyUIView: UIView {
    var simulateLayerBuildFailure = false
    var onTap: ((Int) -> Void)?
    var onTapWord: ((String) -> Void)?
    var onTapLine: (() -> Void)?
    var contentKey: String?

    private var measuredSizeCache: (width: CGFloat, size: CGSize)?
    private var rubyAlignment: [ObjectIdentifier: (centerShift: CGFloat, left: CGFloat, right: CGFloat)] = [:]
    private var rubyInkCache: [ObjectIdentifier: CGRect] = [:]
    private var frameSize: CGSize = .zero
    private var cachedFramesetter: CTFramesetter?
    private var cachedFrame: CTFrame? {
        didSet {
            rubyInkCache.removeAll(keepingCapacity: true)
            rubyAlignment.removeAll(keepingCapacity: true)
            karaokeLayout = nil
            karaokeDrawingSegments = nil
            karaokeExperimentUnavailable = false
            removeKaraokeExperiment()
        }
    }

    // 実際の表示幅を使って改行位置を決める。
    private var preferredMaxLayoutWidth: CGFloat = 0 {
        didSet {
            if abs(oldValue - preferredMaxLayoutWidth) > 0.5 {
                invalidateIntrinsicContentSize()
                setNeedsDisplay()
            }
        }
    }

    var attributedText: NSAttributedString? {
        didSet {
            measuredSizeCache = nil
            guard let attributedText else {
                cachedFrame = nil
                cachedFramesetter = nil
                return
            }

            cachedFramesetter = CTFramesetterCreateWithAttributedString(attributedText as CFAttributedString)
            cachedFrame = nil

            invalidateIntrinsicContentSize()
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        contentMode = .redraw
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        self.addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError() }

    // 表示幅が変わると改行位置も変わるため、組版結果を破棄する。
    override func layoutSubviews() {
        super.layoutSubviews()
        if frameSize != bounds.size {
            frameSize = bounds.size
            cachedFrame = nil
            // 初回のレイアウトでサイズが確定したら、ルビのはみ出しを再計算する。
            setNeedsDisplay()
        }
        if bounds.width > 0 && abs(bounds.width - preferredMaxLayoutWidth) > 0.5 {
            preferredMaxLayoutWidth = bounds.width
            cachedFrame = nil
        }
    }

    override var intrinsicContentSize: CGSize {
        let width = preferredMaxLayoutWidth > 0 ? preferredMaxLayoutWidth : 100
        return measuredSize(for: width)
    }

    func measuredSize(for width: CGFloat) -> CGSize {
        guard let attributedText, let framesetter = cachedFramesetter else { return .zero }
        if let cached = measuredSizeCache, cached.width == width { return cached.size }
        let constraints = CGSize(width: width, height: .greatestFiniteMagnitude)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, attributedText.length), nil, constraints, nil)

        let measured = CGSize(width: width, height: ceil(size.height))
        measuredSizeCache = (width, measured)
        
        return measured
    }

    override func draw(_ rect: CGRect) {
        guard bounds.width > 0, bounds.height > 0,
          let context = UIGraphicsGetCurrentContext(),
          let framesetter = cachedFramesetter else { return }

        context.textMatrix = .identity
        context.translateBy(x: 0, y: bounds.size.height)
        context.scaleBy(x: 1.0, y: -1.0)

        if cachedFrame == nil {
            let path = CGMutablePath()
            path.addRect(bounds)

            cachedFrame = CTFramesetterCreateFrame(
                framesetter,
                CFRangeMake(0, 0),
                path,
                nil
            )
        }

        if let segments = karaokeSegments, !segments.isEmpty, karaokeTime.isFinite {
            if drawKaraokeExperiment(frame: cachedFrame!, segments: segments) {
                return
            }
        }
        drawStaticText(frame: cachedFrame!, in: context)
    }

    private func drawStaticText(frame: CTFrame, in context: CGContext) {
        let lines = CTFrameGetLines(frame) as! [CTLine]
        guard !lines.isEmpty else { return }
        var origins = Array(repeating: CGPoint.zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)

        var staticRubyRuns: [(CTRun, CGPoint, CGRect)] = []
        // 再生中と同じランの描画位置を使い、ルビの位置が切り替え時にずれないようにする。
        for (line, origin) in zip(lines, origins) {
            for run in CTLineGetGlyphRuns(line) as! [CTRun] {
                if karaokeSegments == nil, KaraokeLayerRenderer.isEnabled,
                   (CTRunGetAttributes(run) as NSDictionary)[kCTRubyAnnotationAttributeName] != nil,
                   let area = rubyRunArea(run, at: origin, onlyOverflow: true) {
                    staticRubyRuns.append((run, origin, area))
                    continue
                }
                drawRubyClampedRun(run, at: origin, in: context)
            }
        }
        guard !staticRubyRuns.isEmpty, karaokeExperiment == nil else { return }
        let experiment = KaraokeLayerRenderer(bounds: bounds)
        for (run, origin, area) in staticRubyRuns {
            if !experiment.addRubyRun(
                bounds: bounds, ink: area, scale: contentScaleFactor, fragment: nil,
                draw: { self.drawRubyClampedRun(run, at: origin, in: $0) }
            ) {
                drawRubyClampedRun(run, at: origin, in: context)
            }
        }
        layer.addSublayer(experiment.layer)
        karaokeExperiment = experiment
    }

    // ルビを含むランは、初回の描画時に余白付きの画像で実際の左右端を測る。
    private func rubyInk(_ run: CTRun) -> CGRect {
        let key = ObjectIdentifier(run)
        if let cached = rubyInkCache[key] { return cached }
        let signposter = KaraokeLayerRenderer.signposter
        let interval = signposter.beginInterval("Ruby Ink Probe", id: signposter.makeSignpostID())
        defer { signposter.endInterval("Ruby Ink Probe", interval) }
        let range = CFRange(location: 0, length: 0)
        let estimate = CTRunGetImageBounds(run, nil, range)
        guard !estimate.isEmpty, !estimate.isInfinite else { return estimate }
        let padding = ceil(max(estimate.width, estimate.height))
        // 左右端だけを測るため、上下にはアンチエイリアス用の余白だけを取る。
        let probe = estimate.insetBy(dx: -padding, dy: -2).integral
        let scale = contentScaleFactor
        let width = Int(ceil(probe.width * scale))
        let height = Int(ceil(probe.height * scale))
        guard width > 0, height > 0, width <= 4096, height <= 4096,
              let bitmap = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                     bytesPerRow: width * 2, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = bitmap.data else { return estimate }
        bitmap.scaleBy(x: scale, y: scale)
        bitmap.textPosition = CGPoint(x: -probe.minX, y: -probe.minY)
        CTRunDraw(run, bitmap, range)
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        let split = rubyBaseTop(run)
        var reading = (left: width, right: -1)
        var base = reading
        for y in 0..<height {
            let row = pixels.advanced(by: y * width * 2)
            let isReading = probe.minY + (CGFloat(height - y) - 0.5) / scale > split
            var edges = isReading ? reading : base
            for x in 0..<edges.left where row[x * 2 + 1] != 0 {
                edges.left = x
                break
            }
            for x in stride(from: width - 1, to: edges.right, by: -1) where row[x * 2 + 1] != 0 {
                edges.right = x
                break
            }
            if isReading { reading = edges } else { base = edges }
        }
        let left = min(base.left, reading.left)
        let right = max(base.right, reading.right)
        guard right >= left else { return estimate }
        if reading.right >= reading.left, base.right >= base.left {
            rubyAlignment[key] = (
                CGFloat(base.left + base.right - reading.left - reading.right) / (2 * scale),
                probe.minX + CGFloat(reading.left) / scale,
                probe.minX + CGFloat(reading.right + 1) / scale
            )
        }
        let ink = CGRect(x: probe.minX + CGFloat(left) / scale, y: estimate.minY,
                         width: CGFloat(right - left + 1) / scale, height: estimate.height)
        rubyInkCache[key] = ink
        return ink
    }

    private func rubyRunArea(_ run: CTRun, at origin: CGPoint, onlyOverflow: Bool = false) -> CGRect? {
        let ink = rubyInk(run)
        let area = CGRect(x: origin.x + ink.minX, y: bounds.height - origin.y - ink.maxY,
                          width: ink.width, height: ink.height)
        guard !area.isEmpty, !area.isInfinite else { return nil }
        let shift = rubyInset(for: area, run: run, originX: origin.x)
        if shift == 0 { return onlyOverflow ? nil : area }
        return area.union(area.offsetBy(dx: shift, dy: 0))
            .intersection(CGRect(x: bounds.minX, y: area.minY, width: bounds.width, height: area.height))
    }

    private func rubyBaseTop(_ run: CTRun) -> CGFloat {
        let glyphRange = CFRange(location: 0, length: 0)
        let count = CTRunGetGlyphCount(run)
        guard count > 0, let font = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] else { return 0 }
        var glyphs = Array(repeating: CGGlyph(), count: count)
        var positions = Array(repeating: CGPoint.zero, count: count)
        var glyphBounds = Array(repeating: CGRect.zero, count: count)
        CTRunGetGlyphs(run, glyphRange, &glyphs)
        CTRunGetPositions(run, glyphRange, &positions)
        CTFontGetBoundingRectsForGlyphs(font as! CTFont, .horizontal, glyphs, &glyphBounds, count)
        return zip(glyphBounds, positions).reduce(CGFloat.zero) {
            max($0, $1.0.maxY + $1.1.y)
        }
    }

    private func rubyInset(for ink: CGRect, run: CTRun, originX: CGFloat) -> CGFloat {
        guard !ink.isNull, !ink.isInfinite, ink.width <= bounds.width else { return 0 }
        guard let alignment = rubyAlignment[ObjectIdentifier(run)] else {
            return min(0, bounds.maxX - ink.maxX) + max(0, bounds.minX - ink.minX)
        }
        return min(bounds.maxX - originX - alignment.right,
                   max(bounds.minX - originX - alignment.left, alignment.centerShift))
    }

    private func drawRubyClampedRun(_ run: CTRun, at origin: CGPoint, in context: CGContext) {
        let glyphRange = CFRange(location: 0, length: 0)
        context.textPosition = origin
        let attributes = CTRunGetAttributes(run) as NSDictionary
        guard attributes[kCTRubyAnnotationAttributeName] != nil else {
            CTRunDraw(run, context, glyphRange)
            return
        }

        let ink = rubyInk(run).offsetBy(dx: origin.x, dy: origin.y)
        let shift = rubyInset(for: ink, run: run, originX: origin.x)
        guard shift != 0 else {
            CTRunDraw(run, context, glyphRange)
            return
        }
        let baseTop = origin.y + rubyBaseTop(run)
        let split = min(bounds.maxY, max(bounds.minY, ceil(baseTop * contentScaleFactor) / contentScaleFactor))
        // 親文字はそのまま描き、表示範囲をはみ出すルビだけ内側へ移動する。
        context.saveGState()
        context.clip(to: CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: split - bounds.minY))
        CTRunDraw(run, context, glyphRange)
        context.restoreGState()

        context.saveGState()
        context.clip(to: CGRect(x: bounds.minX, y: split, width: bounds.width, height: bounds.maxY - split))
        context.textPosition = CGPoint(x: origin.x + shift, y: origin.y)
        CTRunDraw(run, context, glyphRange)
        context.restoreGState()
    }

    // 改行、ルビ、タップ位置の判定には同じ Core Text の組版結果を使う。
    private var karaokeSegments: [CaptionSegment]?
    private var karaokeDrawingSegments: [CaptionSegment]?
    private var karaokeTime: Double = 0
    private var karaokeAnimationRate: Float?

    private static let liftDuration = 0.64
    private static let liftHeight: CGFloat = 1.5
    private var karaokeColor: UIColor = .white

    func updateKaraoke(segments: [CaptionSegment]?, time: Double, color: UIColor, animationRate: Float?) {
        let changed = karaokeSegments != segments
        let animationModeChanged = (karaokeAnimationRate == nil) != (animationRate == nil)
        guard changed || (segments != nil && (karaokeTime != time || karaokeColor != color || animationRate != nil || animationModeChanged)) else { return }

        let previousTime = karaokeTime
        let colorChanged = karaokeColor != color
        if changed {
            karaokeLayout = nil
            karaokeDrawingSegments = nil
            karaokeExperimentUnavailable = false
        }
        karaokeSegments = segments
        karaokeTime = time
        karaokeColor = color
        karaokeAnimationRate = animationRate

        if changed || colorChanged || animationModeChanged || !time.isFinite { removeKaraokeExperiment() }
        if let karaokeExperiment, let animationRate, time.isFinite {
            karaokeExperiment.sync(time: time, rate: animationRate, liftDuration: Self.liftDuration, liftHeight: Self.liftHeight)
            return
        }

        // シークも含め、二つの時刻の間に表示が変化する区間があるかを確認する。
        if !changed, !colorChanged, !animationModeChanged, previousTime.isFinite, time.isFinite {
            let lower = min(previousTime, time)
            let upper = max(previousTime, time)
            guard (karaokeDrawingSegments ?? segments)?.contains(where: {
                $0.end > $0.start && upper > $0.start && lower < $0.end + Self.liftDuration
            }) == true else { return }
        }
        if let karaokeExperiment {
            karaokeExperiment.update(time: time, liftDuration: Self.liftDuration, liftHeight: Self.liftHeight)
            return
        }
        setNeedsDisplay()
    }

    // レイヤーを作成できない場合は字幕全体を静止表示する。
    private var karaokeExperiment: KaraokeLayerRenderer?
    private var karaokeExperimentUnavailable = false

    private func removeKaraokeExperiment() {
        guard let karaokeExperiment else { return }
        karaokeExperiment.layer.removeFromSuperlayer()
        self.karaokeExperiment = nil
        setNeedsDisplay()
    }

    private func drawKaraokeExperiment(frame: CTFrame, segments: [CaptionSegment]) -> Bool {
        guard KaraokeLayerRenderer.isEnabled, !karaokeExperimentUnavailable,
              bounds.width > 0, bounds.height > 0 else { return false }
        if karaokeExperiment == nil {
            let signposter = KaraokeLayerRenderer.signposter
            let interval = signposter.beginInterval("Karaoke Line Build", id: signposter.makeSignpostID())
            defer { signposter.endInterval("Karaoke Line Build", interval) }
            if karaokeLayout == nil { karaokeLayout = makeKaraokeLayout(frame: frame, segments: segments) ?? [] }
            guard let karaokeLayout, !karaokeLayout.isEmpty else { return false }
            let experiment = KaraokeLayerRenderer(bounds: bounds)
            for row in karaokeLayout {
                let fragments = row.fragments.map {
                    KaraokeLayerRenderer.Fragment(
                        segment: $0.segment, rangeStart: $0.rangeStart, segmentOffset: $0.segmentOffset,
                        segmentLength: $0.segmentLength, offsets: $0.offsets
                    )
                }
                var baseRuns: [CTRun] = []
                for run in CTLineGetGlyphRuns(row.line) as! [CTRun] {
                    let attributes = CTRunGetAttributes(run) as NSDictionary
                    let range = CTRunGetStringRange(run)
                    guard attributes[kCTRubyAnnotationAttributeName] != nil, range.length > 0,
                          let owner = fragments.first(where: {
                              range.location >= $0.rangeStart &&
                              range.location + range.length < $0.rangeStart + $0.offsets.count
                          }) else {
                        baseRuns.append(run)
                        continue
                    }
                    let rubyFragment = KaraokeLayerRenderer.Fragment(
                        segment: owner.segment, rangeStart: range.location,
                        segmentOffset: owner.segmentOffset, segmentLength: owner.segmentLength,
                        offsets: Array(repeating: 0, count: range.length + 1)
                    )
                    // ルビ付きのランは実際の描画範囲で切り出し、隣の断片から分離する。
                    if let area = rubyRunArea(run, at: row.origin), experiment.addRubyRun(
                        bounds: bounds, ink: area, scale: contentScaleFactor,
                        fragment: rubyFragment,
                        draw: { context in
                            self.drawRubyClampedRun(run, at: row.origin, in: context)
                        }
                    ) { continue }
                    baseRuns.append(run)
                }
                guard !simulateLayerBuildFailure, experiment.addLine(
                    bounds: bounds, originX: row.origin.x, scale: contentScaleFactor,
                    fragments: fragments,
                    draw: { context in
                        for run in baseRuns {
                            self.drawRubyClampedRun(run, at: row.origin, in: context)
                        }
                    }
                ) else {
                    karaokeExperimentUnavailable = true
                    return false
                }
            }
            layer.addSublayer(experiment.layer)
            karaokeExperiment = experiment
        }
        if let karaokeAnimationRate {
            karaokeExperiment?.sync(time: karaokeTime, rate: karaokeAnimationRate, liftDuration: Self.liftDuration, liftHeight: Self.liftHeight)
        } else {
            karaokeExperiment?.update(time: karaokeTime, liftDuration: Self.liftDuration, liftHeight: Self.liftHeight)
        }
        return true
    }

    // 時刻付きの断片と各表示行の対応を保持し、描画のたびに文字位置を引き直さない。
    private struct KaraokeFragment {
        let segment: CaptionSegment
        let rangeStart: Int
        let segmentOffset: Int
        let segmentLength: Int
        let offsets: [CGFloat]
    }

    private struct KaraokeLine {
        let line: CTLine
        let origin: CGPoint
        let fragments: [KaraokeFragment]

    }

    private var karaokeLayout: [KaraokeLine]?

    private func joinSegmentsWithinRuby(
        _ segments: [CaptionSegment], attributedText: NSAttributedString, leading: Int
    ) -> [CaptionSegment] {
        var rubyInterior = IndexSet()
        attributedText.enumerateAttribute(
            kCTRubyAnnotationAttributeName as NSAttributedString.Key,
            in: NSRange(location: 0, length: attributedText.length)
        ) { annotation, range, _ in
            if annotation != nil, range.length > 1 {
                rubyInterior.insert(integersIn: (range.location + 1)..<NSMaxRange(range))
            }
        }

        var result: [CaptionSegment] = []
        var boundary = -leading
        for segment in segments {
            // ルビの途中に境界がある断片はまとめ、同じタイミングで持ち上げる。
            if boundary >= 0, rubyInterior.contains(boundary), let previous = result.popLast() {
                let timed = [previous, segment].filter { $0.start.isFinite && $0.end.isFinite && $0.end > $0.start }
                result.append(CaptionSegment(
                    text: previous.text + segment.text,
                    start: timed.map(\.start).min() ?? 0,
                    end: timed.map(\.end).max() ?? 0
                ))
            } else {
                result.append(segment)
            }
            boundary += segment.text.utf16.count
        }
        return result
    }

    private func makeKaraokeLayout(frame: CTFrame, segments: [CaptionSegment]) -> [KaraokeLine]? {
        guard let attributedText else { return nil }
        let text = attributedText.string
        
        let joined = segments.map(\.text).joined()
        guard joined.trimmingCharacters(in: .whitespacesAndNewlines) == text else { return nil }
        let leading = (joined as NSString).range(of: text).location
        guard leading != NSNotFound else { return nil }
        let renderableSegments = segments.map { segment in
            guard segment.start.isFinite, !segment.end.isFinite || segment.end <= segment.start else {
                return segment
            }
            // 終了時刻が使えない断片は、開始時刻でほぼ一瞬に強調する。
            return CaptionSegment(text: segment.text, start: segment.start, end: segment.start + 0.001)
        }
        let drawingSegments = joinSegmentsWithinRuby(renderableSegments, attributedText: attributedText, leading: leading)
        karaokeDrawingSegments = drawingSegments

        let lines = CTFrameGetLines(frame) as! [CTLine]
        var origins = Array(repeating: CGPoint.zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), &origins)
        
        return lines.enumerated().map { index, line in
            let range = CTLineGetStringRange(line)
            var offset = -leading
            let fragments = drawingSegments.compactMap { segment -> KaraokeFragment? in
                let lower = offset
                let length = segment.text.utf16.count
                offset += length
                let start = max(lower, range.location)
                let end = min(offset, range.location + range.length)
                guard start < end, segment.start.isFinite, segment.end.isFinite,
                      segment.end > segment.start else { return nil }
                
                return KaraokeFragment(
                    segment: segment,
                    rangeStart: start,
                    segmentOffset: lower,
                    segmentLength: length,
                    offsets: (start...end).map {
                        CTLineGetOffsetForStringIndex(line, $0, nil)
                    }
                )
            }
            
            return KaraokeLine(line: line, origin: origins[index], fragments: fragments)
        }
    }

    private func wordAt(tapIndex: Int, in text: String) -> String? {
        let nsText = text as NSString
        let length = nsText.length
        guard tapIndex >= 0 && tapIndex < length else { return nil }

        // トークナイザーでタップ位置を含む単語を探す。
        let tokenizer = CFStringTokenizerCreate(
            kCFAllocatorDefault,
            text as CFString,
            CFRangeMake(0, length),
            kCFStringTokenizerUnitWord,
            Locale(identifier: "ja_JP") as CFLocale
        )

        var tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)

        while tokenType != [] {
            let tokenRange = CFStringTokenizerGetCurrentTokenRange(tokenizer)

            if tapIndex >= tokenRange.location &&
               tapIndex < tokenRange.location + tokenRange.length {

                // 複数文字の単語はそのまま返す。
                if tokenRange.length > 1 {
                    let nsRange = NSRange(location: tokenRange.location, length: tokenRange.length)
                    return nsText.substring(with: nsRange)
                }

                // 1 文字の場合は、前後の漢字を含めて最大 4 文字まで広げる。
                var start = tokenRange.location
                var end = tokenRange.location + 1
                let maxLength = 4

                func isKanji(_ index: Int) -> Bool {
                    guard index >= 0 && index < length else { return false }
                    let char = nsText.character(at: index)
                    
                    return (0x4E00...0x9FFF).contains(char)
                }

                // 左側の連続する漢字を含める。
                while start > 0 &&
                      isKanji(start - 1) &&
                      (end - (start - 1)) <= maxLength {
                    start -= 1
                }

                // 右側の連続する漢字を含める。
                while end < length &&
                      isKanji(end) &&
                      (end + 1 - start) <= maxLength {
                    end += 1
                }

                let nsRange = NSRange(location: start, length: end - start)
                return nsText.substring(with: nsRange)
            }

            tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        }

        return nil
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let attributedText = attributedText, let cachedFramesetter = cachedFramesetter else {
            onTapLine?()
            return
        }

        let location = gesture.location(in: self)

        // 描画時と同じ領域で組版する。
        let path = CGMutablePath()
        path.addRect(bounds)

        let frame: CTFrame
        if let cachedFrame {
            frame = cachedFrame
        } else {
            frame = CTFramesetterCreateFrame(cachedFramesetter, CFRangeMake(0, 0), path, nil)
            self.cachedFrame = frame
        }

        // UIKit のタップ座標を Core Text の座標系に変換する。
        let flippedLocation = CGPoint(x: location.x, y: bounds.size.height - location.y)

        // 各表示行と、そのベースラインの位置を取得する。
        let lines = CTFrameGetLines(frame) as! [CTLine]
        let lineCount = lines.count
        var origins = [CGPoint](repeating: .zero, count: lineCount)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), &origins)

        var characterIndex: CFIndex = -1

        // タップ位置に該当する表示行を探す。
        for i in 0..<lineCount {
            let line = lines[i]
            let origin = origins[i]

            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
                - CGFloat(CTLineGetTrailingWhitespaceWidth(line))

            // ルビの位置も含めて、ベースラインの上下を判定範囲にする。
            let yMin = origin.y - descent - leading
            let yMax = origin.y + ascent

            if flippedLocation.y >= yMin && flippedLocation.y <= yMax {
                // タップ座標を行の原点からの相対位置に変換する。
                let relativePoint = CGPoint(x: flippedLocation.x - origin.x, y: flippedLocation.y - origin.y)
                // 行末の空白では最寄りの文字位置が返るため、文字の表示幅で先に絞り込む。
                guard relativePoint.x >= 0, relativePoint.x < width else { break }
                characterIndex = CTLineGetStringIndexForPosition(line, relativePoint)
                break
            }
        }

        // MARK: - 文字上のタップだけを単語検索に渡す
        if characterIndex != -1 && characterIndex < attributedText.length {
            let text = attributedText.string
            let nsText = text as NSString
            let tappedChar = nsText.substring(with: NSRange(location: characterIndex, length: 1))

            if !tappedChar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let word = wordAt(tapIndex: characterIndex, in: text) {
                    onTapWord?(word)
                    return
                }
            }
        }

        onTapLine?()
    }
}
