//
//  ScrollIndicatorStyle.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 8/02/15.
//

import SwiftUI
import UIKit

private struct ScrollIndicatorStyleModifier: ViewModifier {
    let style: UIScrollView.IndicatorStyle

    func body(content: Content) -> some View {
        content
            .background(ScrollIndicatorConfigurator(style: style))
    }
}

private struct ScrollIndicatorConfigurator: UIViewRepresentable {
    let style: UIScrollView.IndicatorStyle

    func makeUIView(context: Context) -> UIView {
        let view = UIView()

        DispatchQueue.main.async {
            if let scrollView = findScrollView(from: view) {
                scrollView.indicatorStyle = style
            }
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let scrollView = findScrollView(from: uiView) {
                scrollView.indicatorStyle = style
            }
        }
    }

    private func findScrollView(from view: UIView) -> UIScrollView? {
        var current: UIView? = view
        while let superview = current?.superview {
            if let scrollView = superview as? UIScrollView {
                return scrollView
            }
            current = superview
        }
        return nil
    }
}

extension View {
    func ScrollIndicatorStyle(_ style: UIScrollView.IndicatorStyle) -> some View {
        modifier(ScrollIndicatorStyleModifier(style: style))
    }
}
