//
//  RubyLabel.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/25.
//

import SwiftUI

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
        view.setContentHuggingPriority(.required, for: .vertical)
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

    // 💡 增加這個屬性來精準控制換行寬度
    private var preferredMaxLayoutWidth: CGFloat = 0 {
        didSet {
            if oldValue != preferredMaxLayoutWidth {
                invalidateIntrinsicContentSize()
                setNeedsDisplay()
            }
        }
    }

    var attributedText: NSAttributedString? {
        didSet {
            guard let attr = attributedText else {
                cachedFrame = nil
                return
            }

            cachedFramesetter = CTFramesetterCreateWithAttributedString(attributedText! as CFAttributedString)
            invalidateIntrinsicContentSize()
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        self.addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError() }

    // 💡 關鍵：當 UIView 被放入父容器時，獲取實際寬度
    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.width > 0 && bounds.width != preferredMaxLayoutWidth {
            preferredMaxLayoutWidth = bounds.width
        }
    }

    override var intrinsicContentSize: CGSize {
        guard let attributedText = attributedText, let framesetter = cachedFramesetter else { return .zero }

        let width = preferredMaxLayoutWidth > 0 ? preferredMaxLayoutWidth : 100

        let constraints = CGSize(width: width, height: .greatestFiniteMagnitude)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(cachedFramesetter!, CFRangeMake(0, attributedText.length), nil, constraints, nil)

        return CGSize(width: width, height: ceil(size.height))
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
          let _ = attributedText,
          let framesetter = cachedFramesetter else { return }

        context.textMatrix = .identity
        context.translateBy(x: 0, y: bounds.size.height)
        context.scaleBy(x: 1.0, y: -1.0)

        let path = CGMutablePath()
        path.addRect(bounds)

        let frame = CTFramesetterCreateFrame(
            framesetter,
            CFRangeMake(0, 0),
            path,
            nil
        )

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

                // 2️⃣ 只有1字 → 嘗試擴展（最多４字）

                var start = tokenRange.location
                var end = tokenRange.location + 1
                let maxLength = 4

                func isKanji(_ index: Int) -> Bool {
                    guard index >= 0 && index < length else { return false }
//                    let scalar = text[text.index(text.startIndex, offsetBy: index)].unicodeScalars.first!.value
//                    return (0x4E00...0x9FFF).contains(scalar)
                    let char = nsText.character(at: index)
                    return (0x4E00...0x9FFF).contains(char)
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

            tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        }

        return nil
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let attributedText = attributedText, let cachedFramesetter = cachedFramesetter else { return }

        let location = gesture.location(in: self)

        // 1. 創建 Path (與 draw 函數保持一致)
        let path = CGMutablePath()
        path.addRect(bounds)

        // 2. 修正函數名：使用 CTFramesetterCreateFrame
        let frame = CTFramesetterCreateFrame(cachedFramesetter, CFRangeMake(0, 0), path, nil)

        // 3. 坐標轉換 (反轉 Y 軸)
        let flippedLocation = CGPoint(x: location.x, y: bounds.size.height - location.y)

        // 4. 獲取所有行 (修正類型轉換)
        let lines = CTFrameGetLines(frame) as! [CTLine]
        let lineCount = lines.count
        var origins = [CGPoint](repeating: .zero, count: lineCount)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), &origins)

        var characterIndex: CFIndex = -1

        // 5. 遍歷每一行
        for i in 0..<lineCount {
            let line = lines[i]
            let origin = origins[i]

            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            CTLineGetTypographicBounds(line, &ascent, &descent, &leading)

            // 考慮到 Ruby 注音，行高的判定範圍需要包含 ascent 和 descent
            let yMin = origin.y - descent
            let yMax = origin.y + ascent

            if flippedLocation.y >= yMin && flippedLocation.y <= yMax {
                // 計算在該行內的相對 X 位置
                let relativePoint = CGPoint(x: flippedLocation.x - origin.x, y: flippedLocation.y - origin.y)
                characterIndex = CTLineGetStringIndexForPosition(line, relativePoint)
                break
            }
        }

        // 6. 執行 wordAt
        if characterIndex != -1 && characterIndex < attributedText.length {
            let text = attributedText.string

            // 額外安全檢查：防止點擊行尾空白處返回最後一個字符
            let nsText = text as NSString
            let tappedChar = nsText.substring(with: NSRange(location: characterIndex, length: 1))
            if tappedChar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return
            }

            if let word = wordAt(tapIndex: characterIndex, in: text) {
                onTapWord?(word)
            }
        }
    }
}
