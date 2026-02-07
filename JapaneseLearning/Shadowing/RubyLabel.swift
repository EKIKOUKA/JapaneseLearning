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
    let onTapWordAtIndex: (Int) -> Void

    func makeUIView(context: Context) -> RubyUIView {
        let view = RubyUIView()
        view.onTap = onTapWordAtIndex
        // 核心：告訴 SwiftUI 垂直方向不要圧縮我
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        return view
    }

    func updateUIView(_ uiView: RubyUIView, context: Context) {
        let key = "\(text)|\(fontSizeScale)"

        // 只有内容変了才更新，避免循環刷新
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
        let baseFont = UIFont.systemFont(ofSize: baseFontSize * fontSizeScale, weight: .medium)

        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let attr = NSMutableAttributedString(
            string: cleanText,
            attributes: [
                .font: baseFont,
                .foregroundColor: UIColor.white,
                .paragraphStyle: style
            ]
        )

        // 🔑 關鍵：只用文字搜尋，不用 start / length
        var searchStart = cleanText.startIndex

        for ruby in rubyWords {
            guard !ruby.surface.isEmpty,
                !ruby.reading.isEmpty,
                ruby.reading != ruby.surface
            else { continue }

            // 從尚未用過的位置開始找
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

                // 👉 推進搜尋起點（非常重要）
                searchStart = range.upperBound
            }
        }

        return attr
    }
}

class RubyUIView: UIView {
    var onTap: ((Int) -> Void)?
    var contentKey: String?

    private var cachedFramesetter: CTFramesetter?
    private var cachedFrame: CTFrame?

    // 当文字改変時，自動触発重新佈局和繪製
    var attributedText: NSAttributedString? {
        didSet {
            invalidateIntrinsicContentSize() // 告訴 SwiftUI 我的尺寸変了
            setNeedsDisplay()               // 告訴系統需要重新繪製

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

    // 核心修復：讓視図知道自己需要多高
    override var intrinsicContentSize: CGSize {
        guard let attributedText = attributedText else { return .zero }

        // 獲取当前寬度，如果還没佈局則使用螢幕寬度（減去 Padding）
        // 技巧：給予一個稍微寬裕的預估寬度，減少佈局計算的辺界錯誤
        let width = self.bounds.width > 0 ? self.bounds.width : (UIScreen.main.bounds.width - 36)

        let constraints = CGSize(width: width, height: .greatestFiniteMagnitude)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(cachedFramesetter!, CFRangeMake(0, attributedText.length), nil, constraints, nil)

        // 向上取整，避免浮点数導致的線条抖動
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

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let attributedText = attributedText else { return }
        let point = gesture.location(in: self)

        let frame = CTFramesetterCreateFrame(cachedFramesetter!, CFRangeMake(0, attributedText.length), CGMutablePath(rect: bounds, transform: nil), nil)

        let lines = CTFrameGetLines(frame) as! [CTLine]
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), &origins)

        let y = bounds.height - point.y

        for (i, line) in lines.enumerated() {
            let origin = origins[i]
            var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
            let lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)

            if y >= (origin.y - descent - 5) && y <= (origin.y + ascent + 5) {
                if point.x >= origin.x && point.x <= (origin.x + CGFloat(lineWidth)) {
                    let relativePoint = CGPoint(x: point.x - origin.x, y: y - origin.y)
                    let index = CTLineGetStringIndexForPosition(line, relativePoint)
                    if index != kCFNotFound {
                        onTap?(index)
                        return
                    }
                }
            }
        }
        onTap?(-1)
    }
}
