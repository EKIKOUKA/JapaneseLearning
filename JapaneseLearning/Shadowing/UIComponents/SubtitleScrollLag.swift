//
//  SubtitleScrollLag.swift
//  JapaneseLearning
//
//  Created by Makoto on 2026/11/07.
//

import QuartzCore
import SwiftUI

@MainActor
@Observable
final class ScrollOffsetHistory {
    private struct Sample {
        let time: CFTimeInterval
        let y: CGFloat
    }

    @ObservationIgnored private var samples: [Sample] = []
    private var currentY: CGFloat = 0

    func record(_ y: CGFloat, at time: CFTimeInterval = CACurrentMediaTime()) {
        guard y.isFinite else { return }
        
        if let last = samples.last {
            guard time > last.time else { return }
            
            // フレームが遅れても、実際に観測した位置の間を滑らかに補間する。
        }
        
        samples.append(Sample(time: time, y: y))
        currentY = y
        let cutoff = time - 2
        while samples.count > 2, samples[1].time < cutoff {
            samples.removeFirst()
        }
    }

    // 新しいスクロールに、直前の逆方向の軌跡を混ぜない。
    func reset() {
        guard let last = samples.last else { return }
        samples = [Sample(time: CACurrentMediaTime(), y: last.y)]
    }

    func lag(delay: Double, now: CFTimeInterval = CACurrentMediaTime()) -> CGFloat {
        guard delay > 0, let first = samples.first, let last = samples.last else { return 0 }
        // 現在と遅延時点の差を足すと、行だけが元の軌跡を遅れてたどる。
        let target = now - delay
        let current = currentY
        if target >= last.time { return 0 }
        if target <= first.time { return current - first.y }

        var index = samples.count - 1
        while index > 1, samples[index - 1].time > target { index -= 1 }
        let before = samples[index - 1]
        let after = samples[index]
        let progress = CGFloat((target - before.time) / (after.time - before.time))
        
        return current - (before.y + (after.y - before.y) * progress)
    }
}

private struct ScrollLagModifier: ViewModifier, Animatable {
    let history: ScrollOffsetHistory
    var delay: Double
    let isRunning: Bool

    // 連続して行が切り替わっても、参照する時刻を急に変えない。
    var animatableData: Double {
        get { delay }
        set { delay = newValue }
    }

    func body(content: Content) -> some View {
        TimelineView(.animation(paused: !isRunning || delay <= 0)) { _ in
            // 補正量は補間済み。スクロールのアニメーションを重ねて適用しない。
            let offset = isRunning ? history.lag(delay: delay) : 0
            content.animation(nil) { view in
                view.offset(y: offset)
            }
        }
    }
}

extension View {
    func scrollLag(history: ScrollOffsetHistory, delay: Double, isRunning: Bool) -> some View {
        modifier(ScrollLagModifier(history: history, delay: delay, isRunning: isRunning))
            .animation(isRunning ? .easeOut(duration: 0.15) : nil, value: delay)
    }
}
