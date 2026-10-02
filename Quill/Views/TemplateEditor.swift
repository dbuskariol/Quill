import AppKit
import SwiftUI

@MainActor
final class TemplateEditorController {
    weak var textView: NSTextView?
    func insert(_ token: String) {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
        textView.insertText(token, replacementRange: textView.selectedRange())
    }
}

/// A narrow AppKit bridge for the native completion panel and the native undo/responder chain.
struct TemplateEditor: NSViewRepresentable {
    @Environment(\.isEnabled) private var isEnabled
    @Binding var text: String
    let library: Library
    let controller: TemplateEditorController
    var excludingSnippet: UUID?
    var excludingMacro: UUID?
    let accessibilityName: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let view = CompletingTextView()
        view.isRichText = false
        view.allowsUndo = true
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isAutomaticSpellingCorrectionEnabled = false
        view.isAutomaticTextCompletionEnabled = false
        view.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        view.textColor = .textColor
        view.backgroundColor = .textBackgroundColor
        view.textContainerInset = NSSize(width: 10, height: 10)
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        view.minSize = NSSize(width: 0, height: 170)
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.string = text
        view.setAccessibilityLabel(accessibilityName)
        view.delegate = context.coordinator
        scroll.documentView = view
        controller.textView = view
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let view = scroll.documentView as? CompletingTextView else { return }
        controller.textView = view
        view.isEditable = isEnabled
        view.library = library
        view.excludingSnippet = excludingSnippet
        view.excludingMacro = excludingMacro
        if view.string != text {
            // External changes are Revert, selection changes, or a saved reference rename.
            view.string = text
            view.undoManager?.removeAllActions()
            view.setSelectedRange(NSRange(location: min(view.selectedRange().location, (text as NSString).length), length: 0))
        }
    }
    static func dismantleNSView(_ scroll: NSScrollView, coordinator: Coordinator) {
        (scroll.documentView as? NSTextView)?.delegate = nil
    }
    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TemplateEditor
        init(_ parent: TemplateEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? CompletingTextView else { return }
            parent.text = view.string
            if !view.isInsertingCompletion { view.scheduleCompletion() }
        }
    }
}

@MainActor
final class CompletingTextView: NSTextView {
    var library = Library(groups: [], snippets: [])
    var excludingSnippet: UUID?
    var excludingMacro: UUID?
    var isInsertingCompletion = false
    private var completionGeneration = 0
    override var rangeForUserCompletion: NSRange {
        TemplateCompletion.context(in: string, selection: selectedRange())?.range ?? NSRange(location: NSNotFound, length: 0)
    }
    override func completions(forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String]? {
        guard let context = TemplateCompletion.context(in: string, selection: selectedRange()), context.range == charRange else { return nil }
        index.pointee = -1 // Opening the helper must not insert or select speculative template text.
        return TemplateCompletion.suggestions(for: context, library: library, excludingSnippet: excludingSnippet, excludingMacro: excludingMacro)
    }
    override func insertCompletion(_ word: String, forPartialWordRange charRange: NSRange, movement: Int, isFinal flag: Bool) {
        isInsertingCompletion = true
        super.insertCompletion(word, forPartialWordRange: charRange, movement: movement, isFinal: flag)
        isInsertingCompletion = false
        if flag, movement != NSCancelTextMovement {
            if word == "macro:" || word == "snippet:" || word == "ticket." || word == "current_user." { scheduleCompletion() }
            else if (string as NSString).substring(from: selectedRange().location).hasPrefix("}}") {
                setSelectedRange(NSRange(location: selectedRange().location + 2, length: 0))
            }
        }
    }
    func scheduleCompletion() {
        completionGeneration += 1
        let generation = completionGeneration
        let expectedText = string
        let expectedSelection = selectedRange()
        DispatchQueue.main.async { [weak self] in
            guard let self, generation == self.completionGeneration, self.string == expectedText,
                  self.selectedRange() == expectedSelection, self.window?.firstResponder === self,
                  !self.hasMarkedText(), TemplateCompletion.context(in: self.string, selection: expectedSelection) != nil else { return }
            self.complete(nil)
        }
    }
}
