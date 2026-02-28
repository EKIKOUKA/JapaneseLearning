//
//  SelectableUITextView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2025/11/27.
//

import SwiftUI

struct SelectableUITextView: UIViewRepresentable {

    let text: String
    @Binding var height: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false // !!
        // textView.font = .systemFont(ofSize: 20)
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byCharWrapping
        paragraphStyle.lineBreakStrategy = []

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 19),
            .paragraphStyle: paragraphStyle,
            .foregroundColor: UIColor.label
        ]
        uiView.attributedText = NSAttributedString(string: text, attributes: attributes)

        let targetWidth = uiView.frame.width > 0 ? uiView.frame.width : UIScreen.main.bounds.width - 40 // 減去 Padding

        let size = uiView.sizeThatFits(
            CGSize(width: targetWidth, height: .greatestFiniteMagnitude)
        )

        if abs(height - size.height) > 1.0 {
            DispatchQueue.main.async {
                self.height = size.height
            }
        }
    }
}
