//
//  RubyLabel.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/25.
//

import SwiftUI
import CoreText

struct RubyLabel: UIViewRepresentable {
    let text: String
    let rubyWords: [RubyWord]
    let fontSizeScale: Double
    let fontStyle: VideoSubtitleRubyFontStyle
    let onTapWord: (String) -> Void

    func makeUIView(context: Context) -> RubyUIView {
        let view = RubyUIView()
        view.onTapWord = onTapWord
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        return view
    }

    func updateUIView(_ uiView: RubyUIView, context: Context) {
        let key = "\(text)|\(fontSizeScale)|\(fontStyle)"

        if uiView.contentKey != key {
            uiView.contentKey = key
            uiView.attributedText = buildAttributedString()
        }
    }

    private func buildAttributedString() -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 8
        style.alignment = .left

        let baseFontSize: CGFloat = 28
        let baseFont: UIFont
        let baseFontSystem = UIFont.systemFont(ofSize: baseFontSize * fontSizeScale)
        
        switch fontStyle {
            case .system:
                baseFont = UIFont.systemFont(ofSize: baseFontSize * fontSizeScale, weight: .medium)
            default:
                baseFont = UIFont(name: fontStyle.rawValue, size: baseFontSize * fontSizeScale) ?? baseFontSystem
        }

        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let attr = NSMutableAttributedString(
            string: cleanText,
            attributes: [
                .font: baseFont,
                .foregroundColor: UIColor.white,
                .paragraphStyle: style
            ]
        )

        var searchStart = cleanText.startIndex

        for ruby in rubyWords {
            guard !ruby.surface.isEmpty,
                !ruby.reading.isEmpty,
                ruby.reading != ruby.surface
            else { continue }

            if let range = cleanText.range(
                of: ruby.surface,
                range: searchStart..<cleanText.endIndex
            ) {
                let nsRange = NSRange(range, in: cleanText)

                var rubyAnnotations: [Unmanaged<CFString>?] = [
                    Unmanaged.passRetained(ruby.reading as CFString),
                    nil, nil, nil
                ]

                let annotation = CTRubyAnnotationCreate(
                    .auto,
                    .auto,
                    0.45,
                    &rubyAnnotations
                )

                attr.addAttribute(
                    kCTRubyAnnotationAttributeName as NSAttributedString.Key,
                    value: annotation,
                    range: nsRange
                )

                attr.addAttribute(.font, value: baseFont, range: nsRange)

                searchStart = range.upperBound
            }
        }

        return attr
    }
}

class RubyUIView: UIView {
    var onTap: ((Int) -> Void)?
    var onTapWord: ((String) -> Void)?
    var contentKey: String?

    private var cachedFramesetter: CTFramesetter?
    private var cachedFrame: CTFrame?

    var attributedText: NSAttributedString? {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsDisplay()

            cachedFramesetter = CTFramesetterCreateWithAttributedString(attributedText! as CFAttributedString)
            cachedFrame = nil
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        self.addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: CGSize {
        guard let attributedText = attributedText else { return .zero }

        let width = self.bounds.width > 0 ? self.bounds.width : (UIScreen.main.bounds.width - 36)

        let constraints = CGSize(width: width, height: .greatestFiniteMagnitude)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(cachedFramesetter!, CFRangeMake(0, attributedText.length), nil, constraints, nil)

        return CGSize(width: width, height: ceil(size.height))
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
          let attributedText = attributedText else { return }

        context.textMatrix = .identity
        context.translateBy(x: 0, y: bounds.size.height)
        context.scaleBy(x: 1.0, y: -1.0)

        let path = CGMutablePath()
        path.addRect(bounds)

        let frame = CTFramesetterCreateFrame(cachedFramesetter!, CFRangeMake(0, attributedText.length), path, nil)

        CTFrameDraw(frame, context)
    }

    private func wordAt(tapIndex: Int, in text: String) -> String? {
        let nsText = text as NSString
        let length = nsText.length
        guard tapIndex >= 0 && tapIndex < length else { return nil }

        // 1️⃣ 用 tokenizer 找基本 token
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

                // 如果本來就超過1字，直接返回
                if tokenRange.length > 1 {
                    let nsRange = NSRange(location: tokenRange.location,
                                          length: tokenRange.length)
                    return nsText.substring(with: nsRange)
                }

                // 2️⃣ 只有1字 → 嘗試擴展（最多6字）
                // 單字時才做
                if tokenRange.length == 1 {

                    var start = tokenRange.location
                    var end = tokenRange.location + 1

                    let maxLength = 4

                    func isKanji(_ index: Int) -> Bool {
                        let scalar = text[text.index(text.startIndex, offsetBy: index)].unicodeScalars.first!.value
                        return (0x4E00...0x9FFF).contains(scalar)
                    }

                    // 只向左擴
                    while start > 0 &&
                          isKanji(start - 1) &&
                          (end - (start - 1)) <= maxLength {
                        start -= 1
                    }

                    // 只向右擴
                    while end < length &&
                          isKanji(end) &&
                          (end + 1 - start) <= maxLength {
                        end += 1
                    }

                    let nsRange = NSRange(location: start, length: end - start)
                    return nsText.substring(with: nsRange)
                }
            }

            tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        }

        return nil
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let attributedText = attributedText else { return }

        let location = gesture.location(in: self)

        let textStorage = NSTextStorage(attributedString: attributedText)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: bounds.size)

        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        textContainer.maximumNumberOfLines = 0

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        let glyphIndex = layoutManager.glyphIndex(for: location, in: textContainer)

        let glyphRect = layoutManager.boundingRect(
            forGlyphRange: NSRange(location: glyphIndex, length: 1),
            in: textContainer
        )

        if !glyphRect.contains(location) {
            return
        }

        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        let text = attributedText.string
        let nsText = text as NSString

        guard characterIndex >= 0, characterIndex < nsText.length else {
            return
        }

        let tappedChar = nsText.substring(with: NSRange(location: characterIndex, length: 1))
        if tappedChar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }

        if let word = wordAt(tapIndex: characterIndex, in: text) {
            print("word: \(word)")
            onTapWord?(word)
        }
    }
}
