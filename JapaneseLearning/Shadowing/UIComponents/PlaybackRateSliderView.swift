//
//  PlaybackRateSliderView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 6/9/R8.
//

import SwiftUI

struct PlaybackRateSliderView: View {
    @Binding var rateValue: Float

    let minValue: Float
    let maxValue: Float
    let step: Float

    var onCommit: ((Float) -> Void)? = nil

    var body: some View {
        HStack {
            Image(systemName: "tortoise.fill")
                .foregroundColor(.secondary)
                .onTapGesture {
                    if rateValue > minValue {
                        rateValue = max(rateValue - step, minValue)
                        onCommit?(rateValue)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }

            ZStack {
                GeometryReader { geo in
                    let minRate: Float = minValue
                    let maxRate: Float = maxValue
                    let range = maxRate - minRate
                    let temp_rate = min(rateValue, maxValue)

                    let progress = (temp_rate - minRate) / range
                    let thumbOffset = CGFloat(progress) * (geo.size.width - 30) + 15

                    let selectionFeedback = UISelectionFeedbackGenerator()

                    Slider(
                        value: $rateValue,
                        in: minValue...maxValue,
                        step: step,
                        onEditingChanged: { editing in
                            if !editing {
                                onCommit?(rateValue)
                            }
                            if editing { selectionFeedback.prepare() }
                        }
                    )
                    .onChange(of: rateValue) { _, newValue in
                        if newValue == 1.0 {
                            selectionFeedback.selectionChanged()
                        }
                    }

                    Text("\(String(format: "%.2f", rateValue))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.9))
                        .position(x: thumbOffset, y: 15)
                        .allowsHitTesting(false)
                }
                .frame(height: 30)
            }

            Image(systemName: "hare.fill")
                .foregroundStyle(.secondary)
                .onTapGesture {
                    if rateValue < 2.0 {
                        rateValue = min(rateValue + step, 2.0)
                        onCommit?(rateValue)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
        }
        .padding(6)
        .padding(.trailing, 0)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}
