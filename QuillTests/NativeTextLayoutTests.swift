import AppKit
import SwiftUI
import Testing
@testable import Quill

@MainActor struct NativeTextLayoutTests {
    @Test func formattedPreviewSurvivesRepeatedContentAndWidthChanges() throws {
        let short = try MarkdownDocument("**Hello**, world.")
        let long = try MarkdownDocument(Array(repeating: "A longer **formatted reply** with several words to wrap.", count: 30).joined(separator: "\n\n"))
        let hosting = NSHostingView(rootView: FormattedPreview(document: short))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = hosting
        for index in 0..<20 {
            hosting.rootView = FormattedPreview(document: index.isMultiple(of: 2) ? long : short)
            hosting.frame.size = NSSize(width: index.isMultiple(of: 2) ? 290 : 600, height: 240)
            hosting.layoutSubtreeIfNeeded()
            let size = hosting.fittingSize
            #expect(size.width.isFinite && size.height.isFinite)
        }
        window.contentView = nil
    }
    @Test func offscreenMeasurementWrapsWithoutChangingItsSource() {
        let text = NSAttributedString(string: String(repeating: "Native text layout ", count: 40), attributes: [.font: NSFont.systemFont(ofSize: 13)])
        let original = NSAttributedString(attributedString: text)
        let narrow = NativeTextMeasurement.height(of: text, width: 200, lineFragmentPadding: 5)
        let wide = NativeTextMeasurement.height(of: text, width: 600, lineFragmentPadding: 5)
        #expect(narrow > wide && wide > 0)
        #expect(text == original)
    }
}
