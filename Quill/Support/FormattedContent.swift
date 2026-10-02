import AppKit

@MainActor enum FormattedContent {
    static func attributed(_ document: MarkdownDocument) -> NSAttributedString {
        let value = NSMutableAttributedString(string: "")
        for segment in document.segments {
            let run = segment.run
            let heading = run.path.compactMap { if case .header(let level) = $0.kind { level } else { nil } }.last
            let code = run.code || run.path.contains { if case .codeBlock = $0.kind { true } else { false } }
            var font = code ? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular) : NSFont.systemFont(ofSize: heading.map { CGFloat(24 - min($0,6)*2) } ?? 14, weight: heading != nil || run.bold ? .bold : .regular)
            if run.italic { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
            let paragraph = NSMutableParagraphStyle(); paragraph.paragraphSpacing = 8
            if run.path.contains(where: { $0.kind == .blockQuote }) { paragraph.headIndent = 14; paragraph.firstLineHeadIndent = 14 }
            var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.textColor, .paragraphStyle: paragraph]
            if run.strike { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
            if code { attributes[.backgroundColor] = NSColor.quaternaryLabelColor.withAlphaComponent(0.12) }
            if let link = run.link { attributes[.link] = link }
            value.append(NSAttributedString(string: segment.text, attributes: attributes))
        }
        return value
    }
}
