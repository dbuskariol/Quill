import AppKit
import SwiftUI

struct FormattedPreview: NSViewRepresentable {
    let document: MarkdownDocument
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        let view = NSTextView(); view.isEditable = false; view.isSelectable = true; view.drawsBackground = false
        view.isVerticallyResizable = true; view.isHorizontallyResizable = false; view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = true; view.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        view.setAccessibilityLabel("Formatted preview")
        scroll.documentView = view; return scroll
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView scroll: NSScrollView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0, let view = scroll.documentView as? NSTextView,
              let container = view.textContainer else { return nil }
        let height = NativeTextMeasurement.height(of: view.attributedString(), width: width - 18, lineFragmentPadding: container.lineFragmentPadding)
        return CGSize(width: width, height: min(240, max(24, height + 12)))
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? NSTextView else { return }
        let attributed = FormattedContent.attributed(document)
        if view.attributedString() != attributed { view.textStorage?.setAttributedString(attributed) }
    }
}
