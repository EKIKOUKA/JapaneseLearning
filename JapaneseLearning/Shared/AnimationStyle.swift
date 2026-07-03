//
//  AnimationStyle.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/07/02.
//

import SwiftUI

struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 40, height: 40)
            .background {
                Circle()
                    .fill(.primary.opacity(0.08))
                    .scaleEffect(configuration.isPressed ? 1 : 0.8)
                    .opacity(configuration.isPressed ? 1 : 0)
            }
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .animation(.spring(response: 0.15, dampingFraction: 0.75), value: configuration.isPressed)
    }
}
