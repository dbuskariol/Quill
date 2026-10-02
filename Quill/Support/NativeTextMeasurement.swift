import AppKit

/// Measure offscreen so SwiftUI sizing never resizes a live text view during layout.
@MainActor enum NativeTextMeasurement {
    static func height(of text: NSAttributedString, width: CGFloat, lineFragmentPadding: CGFloat) -> CGFloat {
        let storage = NSTextStorage(attributedString: text)
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: max(1, width), height: CGFloat.greatestFiniteMagnitude))
        container.lineFragmentPadding = lineFragmentPadding
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        layout.ensureLayout(for: container)
        return layout.usedRect(for: container).height
    }
}
