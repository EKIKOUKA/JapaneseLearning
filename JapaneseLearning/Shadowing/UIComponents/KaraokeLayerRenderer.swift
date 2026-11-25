//
//  KaraokeLayerRenderer.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/11/24.
//

import UIKit
import os

@MainActor
final class KaraokeLayerRenderer {
    static let isEnabled = true
    static let usesKeyframes = true
    static let signposter = OSSignposter(subsystem: "com.makoto.JapaneseLearning", category: "SubtitleRendering")

    struct Fragment {
        let segment: CaptionSegment
        let rangeStart: Int
        let segmentOffset: Int
        let segmentLength: Int
        let offsets: [CGFloat]
    }

    private struct Strip {
        let fragment: Fragment
        let dim: CALayer
        let highlight: CALayer
        let mask: CAGradientLayer
        var lastCursor: Double = -1
        var lastLift: CGFloat = -1
    }

    let layer = CALayer()
    private var strips: [Strip] = []
    private var animationStart: Double?

    func addRubyRun(
        bounds: CGRect, ink: CGRect, scale: CGFloat,
        fragment: Fragment?, draw: (CGContext) -> Void
    ) -> Bool {
        // 行頭・行末のルビは親文字の表示領域からはみ出すことがある。
        let area = CGRect(
            x: floor(ink.minX * scale - 1) / scale,
            y: floor(ink.minY * scale - 1) / scale,
            width: (ceil(ink.maxX * scale + 1) - floor(ink.minX * scale - 1)) / scale,
            height: (ceil(ink.maxY * scale + 1) - floor(ink.minY * scale - 1)) / scale
        )
        guard !area.isEmpty else { return false }
        
        let fragments: [Fragment] = fragment.map { fragment in
            let offsets = (0..<fragment.offsets.count).map {
                area.width * CGFloat($0) / CGFloat(fragment.offsets.count - 1)
            }
            
            return [Fragment(
                segment: fragment.segment, rangeStart: fragment.rangeStart,
                segmentOffset: fragment.segmentOffset, segmentLength: fragment.segmentLength, offsets: offsets
            )]
        } ?? []
        
        return addLine(bounds: area, originX: area.minX, scale: scale, fragments: fragments, isStatic: fragment == nil) { context in
            context.translateBy(x: -area.minX, y: area.maxY - bounds.height)
            draw(context)
        }
    }

    init(bounds: CGRect) {
        layer.frame = bounds
    }

    func addLine(
        bounds: CGRect, originX: CGFloat, scale: CGFloat,
        fragments: [Fragment], isStatic: Bool = false, draw: (CGContext) -> Void
    ) -> Bool {
        let ranges = fragments.compactMap { fragment -> (Fragment, CGFloat, CGFloat)? in
            guard let first = fragment.offsets.first, let last = fragment.offsets.last,
                  first.isFinite, last.isFinite, last > first else { return nil }
            return (fragment, originX + first, originX + last)
        }
        var end = bounds.minX
        for (_, left, right) in ranges {
            guard left >= end, right <= bounds.maxX + 0.0001 else { return false }
            end = right
        }

        let image = Self.signposter.withIntervalSignpost("Subtitle Bitmap", id: Self.signposter.makeSignpostID()) {
            let format = UIGraphicsImageRendererFormat()
            format.scale = scale
            return UIGraphicsImageRenderer(size: bounds.size, format: format).image { rendererContext in
                let context = rendererContext.cgContext
                context.translateBy(x: 0, y: bounds.height)
                context.scaleBy(x: 1, y: -1)
                draw(context)
            }.cgImage
        }
        guard let image else { return false }

        let layersInterval = Self.signposter.beginInterval("Subtitle Layers", id: Self.signposter.makeSignpostID())
        defer { Self.signposter.endInterval("Subtitle Layers", layersInterval) }

        if isStatic {
            let label = CALayer()
            label.frame = bounds
            label.contents = image
            label.contentsScale = scale
            layer.addSublayer(label)
            
            return true
        }
        // 暗い文字と明るい文字は同じ画像を参照し、透明度とマスクで描き分ける。
        func imageStrip(from left: CGFloat, to right: CGFloat) -> CALayer {
            let strip = CALayer()
            strip.frame = CGRect(x: left, y: bounds.minY, width: right - left, height: bounds.height)
            strip.contents = image
            strip.contentsScale = scale
            strip.contentsRect = CGRect(x: (left - bounds.minX) / bounds.width, y: 0, width: (right - left) / bounds.width, height: 1)
            
            return strip
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        var leftEdge = bounds.minX
        for (fragment, left, right) in ranges {
            if left > leftEdge {
                let gap = imageStrip(from: leftEdge, to: left)
                gap.opacity = 0.4
                layer.addSublayer(gap)
            }
            let dim = imageStrip(from: left, to: right)
            dim.opacity = 0.4
            let highlight = imageStrip(from: left, to: right)
            let mask = CAGradientLayer()
            mask.startPoint = CGPoint(x: 0, y: 0.5)
            mask.endPoint = CGPoint(x: 1, y: 0.5)
            mask.colors = [UIColor.white.cgColor, UIColor.white.cgColor, UIColor.clear.cgColor, UIColor.clear.cgColor]
            let width = highlight.bounds.width
            let feather = min(14, width / 2)
            let span = width * 2 + feather
            mask.frame = CGRect(x: 0, y: 0, width: span, height: highlight.bounds.height)
            mask.locations = [0, NSNumber(value: Double(width / span)), NSNumber(value: Double((width + feather) / span)), 1]
            highlight.mask = mask
            layer.addSublayer(dim)
            layer.addSublayer(highlight)
            strips.append(Strip(fragment: fragment, dim: dim, highlight: highlight, mask: mask))
            leftEdge = right
        }
        
        if leftEdge < bounds.maxX {
            let gap = imageStrip(from: leftEdge, to: bounds.maxX)
            gap.opacity = 0.4
            layer.addSublayer(gap)
        }
        
        return true
    }

    func sync(time: Double, rate: Float, liftDuration: Double, liftHeight: CGFloat) {
        guard time.isFinite else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let isNew = animationStart == nil
        // beginTime が 0 だと追加時刻が使われるため、最初の断片にも明示的な開始時刻を与える。
        let start = animationStart ?? ((strips.map { $0.fragment.segment.start }.min() ?? time) - 1)
        let now = CACurrentMediaTime()
        let target = time - start
        if isNew || layer.speed != rate || abs(layer.convertTime(now, from: nil) - target) > (rate == 0 ? 0 : 0.05) {
            layer.beginTime = layer.superlayer?.convertTime(now, from: nil) ?? now
            layer.timeOffset = target
            layer.speed = rate
        }
        if isNew {
            animationStart = start
            for strip in strips {
                installAnimations(for: strip, start: start, liftDuration: liftDuration, liftHeight: liftHeight)
            }
        }
    }

    private func installAnimations(for strip: Strip, start: Double, liftDuration: Double, liftHeight: CGFloat) {
        let fragment = strip.fragment
        let segment = fragment.segment
        let duration = segment.end - segment.start
        let offset = Double(fragment.rangeStart - fragment.segmentOffset)
        let length = Double(fragment.segmentLength)
        let width = strip.highlight.bounds.width
        let feather = min(14, width / 2)
        let maskOrigin = -feather - width + strip.mask.bounds.width / 2

        // 各文字境界の時刻とマスク位置を登録し、描画ごとの更新をなくす。
        let sweep = CAKeyframeAnimation(keyPath: "position.x")
        sweep.beginTime = segment.start - start
        sweep.duration = duration
        var keyTimes: [NSNumber] = [0]
        var positions: [CGFloat] = [maskOrigin]
        for (index, x) in fragment.offsets.enumerated() {
            let fraction = (Double(index) + offset) / length
            guard fraction > 0, fraction < 1 else { continue }
            let swept = x - fragment.offsets[0]
            keyTimes.append(NSNumber(value: fraction))
            positions.append(maskOrigin + swept * (1 + feather / width))
        }
        keyTimes.append(1)
        positions.append(maskOrigin + width + feather)
        sweep.keyTimes = keyTimes
        sweep.values = positions
        sweep.fillMode = .both
        sweep.isRemovedOnCompletion = false
        strip.mask.add(sweep, forKey: "subtitleSweep")

        let completeAt = segment.start + (Double(fragment.offsets.count - 1) + offset) / length * duration
        let dim = CABasicAnimation(keyPath: "opacity")
        dim.beginTime = completeAt - start
        dim.duration = 0.001
        dim.fromValue = strip.dim.opacity
        dim.toValue = Float(0)
        dim.fillMode = .both
        dim.isRemovedOnCompletion = false
        strip.dim.add(dim, forKey: "subtitleDim")

        let lift = CABasicAnimation(keyPath: "transform.translation.y")
        lift.beginTime = segment.end - start
        lift.duration = liftDuration
        lift.fromValue = 0
        lift.toValue = -liftHeight
        lift.timingFunction = CAMediaTimingFunction(controlPoints: 1.0 / 3, 0, 2.0 / 3, 1)
        lift.fillMode = .both
        lift.isRemovedOnCompletion = false
        strip.highlight.add(lift, forKey: "subtitleLift")
    }

    func update(time: Double, liftDuration: Double, liftHeight: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        for i in strips.indices {
            let strip = strips[i]
            let fragment = strip.fragment
            let segment = fragment.segment
            let progress = min(1, max(0, (time - segment.start) / (segment.end - segment.start)))
            let last = fragment.offsets.count - 1
            let cursor = min(Double(last), max(0, Double(fragment.segmentOffset - fragment.rangeStart) + Double(fragment.segmentLength) * progress))
            let t = CGFloat(min(1, max(0, (time - segment.end) / liftDuration)))
            guard cursor != strip.lastCursor || t != strip.lastLift else { continue }
            strips[i].lastCursor = cursor
            strips[i].lastLift = t
            let index = Int(cursor)
            let x = fragment.offsets[index]
            let next = fragment.offsets[min(index + 1, last)]
            let swept = x + (next - x) * CGFloat(cursor - Double(index)) - fragment.offsets[0]
            let complete = cursor >= Double(last)
            strip.dim.isHidden = complete
            strip.highlight.isHidden = swept <= 0
            
            if complete {
                strip.highlight.mask = nil
                strip.highlight.transform = CATransform3DMakeTranslation(0, -t * t * (3 - 2 * t) * liftHeight, 0)
            } else {
                strip.highlight.transform = CATransform3DIdentity
                if strip.highlight.mask == nil { strip.highlight.mask = strip.mask }
                let width = strip.highlight.bounds.width
                let feather = min(14, width / 2)
                let front = swept + feather * (swept / width)
                // グラデーションを移動し、断片の端で切り抜く。
                strip.mask.position.x = front - feather - width + strip.mask.bounds.width / 2
            }
        }
    }
}
