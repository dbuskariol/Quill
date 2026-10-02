import AppKit
import Foundation
import Testing
@testable import Quill

struct TemplateRendererTests {
    private func fixture(_ body: String) -> (Snippet, Library) {
        let group = SnippetGroup(name: "Test")
        let item = Snippet(groupID: group.id, title: "Test", abbreviation: ";test", body: body)
        return (item, Library(groups: [group], snippets: [item]))
    }

    @Test func resolvesFieldsAndFixedDate() throws {
        let (item, library) = fixture("{{field:name}} · {{date}} {{time}}")
        let context = RenderContext(date: Date(timeIntervalSince1970: 0), timeZone: TimeZone(secondsFromGMT: 0)!, fields: ["name": "Daniel"])
        let result = try TemplateRenderer.render(item, library: library, context: context)
        #expect(result.text == "Daniel · 1970-01-01 00:00")
        #expect(result.fields == ["name"])
    }

    @Test func fieldValuesAreNotExecutedAsMacros() throws {
        let (item, library) = fixture("{{field:name}}")
        let result = try TemplateRenderer.render(item, library: library, context: RenderContext(fields: ["name": "{{snippet:;test}}"] ))
        #expect(result.text == "{{snippet:;test}}")
    }

    @Test func cursorUsesUTF16ForNativeTextSystems() throws {
        let (item, library) = fixture("🪶{{cursor}}Hello")
        let result = try TemplateRenderer.render(item, library: library)
        #expect(result.text == "🪶Hello")
        #expect(result.cursorUTF16Offset == 2)
    }

    @Test func nestingResolvesAndCollectsFields() throws {
        var (item, library) = fixture("Hello {{snippet:;nested}}")
        let nested = Snippet(groupID: item.groupID, title: "Nested", abbreviation: ";nested", body: "{{field:name}}")
        library.snippets.append(nested)
        item.body += " {{field:name}}"
        let result = try TemplateRenderer.render(item, library: library)
        #expect(result.text == "Hello ‹name› ‹name›")
        #expect(result.fields == ["name"])
    }

    @Test func rejectsCycles() {
        let (item, library) = fixture("{{snippet:;test}}")
        #expect(throws: TemplateError.self) { try TemplateRenderer.render(item, library: library) }
    }

    @Test func rejectsUnknownAndMalformedMacros() {
        for source in ["{{unknown}}", "{{date", "oops}}", "{{field:}}"] {
            #expect(throws: TemplateError.self) { try TemplateRenderer.parse(source) }
        }
    }

    @Test func rejectsAmbiguousAndMissingReferences() {
        var (item, library) = fixture("{{snippet:;missing}}")
        #expect(throws: TemplateError.self) { try TemplateRenderer.render(item, library: library) }
        item.body = "{{snippet:;test}}"
        library.snippets.append(Snippet(groupID: item.groupID, title: "Duplicate", abbreviation: ";test", body: ""))
        #expect(TemplateRenderer.conflicts(for: item, in: library).count == 1)
        #expect(throws: TemplateError.self) { try TemplateRenderer.render(item, library: library) }
    }
}

struct ExpansionPanelLayoutTests {
    @Test func staysOnTheTargetDisplayAndMovesAboveNearBottom() {
        let display = CGRect(x: -1280, y: 100, width: 1280, height: 800)
        let caret = CGRect(x: -10, y: 108, width: 0, height: 18)
        let frame = ExpansionPanelLayout.frame(size: CGSize(width: 320, height: 160), anchor: caret, visibleFrame: display)
        #expect(display.contains(frame))
        #expect(frame.minY > caret.maxY)
        #expect(frame.maxX <= -8)
    }
    @Test func translatesAXCaretAndPlacesBelowWhenSpacePermits() {
        let caret = ExpansionPanelLayout.appKitRect(CGRect(x: 120, y: 100, width: 0, height: 20), primaryDisplayTop: 1080)
        #expect(caret.minY == 960)
        let frame = ExpansionPanelLayout.frame(size: CGSize(width: 320, height: 160), anchor: caret,
                                              visibleFrame: CGRect(x: 0, y: 40, width: 1920, height: 1000))
        #expect(frame.maxY < caret.minY)
        #expect(frame.minX == caret.minX)
    }
    @Test func starterNotesResolvesTopicDateAndCursorBeforeNotesBody() throws {
        let library = Library.starter
        let notes = try #require(library.snippets.first { $0.abbreviation == ";notes" })
        let result = try TemplateRenderer.render(notes, library: library,
            context: RenderContext(date: Date(timeIntervalSince1970: 0), timeZone: TimeZone(secondsFromGMT: 0)!, fields: ["topic": "Planning 🙂"]))
        let plain = try result.plainTextResult()
        #expect(plain.text == "Meeting · 1970-01-01\nTopic: Planning 🙂\n\nNotes\n\n\nNext steps\n• ")
        #expect(plain.cursorUTF16Offset == "Meeting · 1970-01-01\nTopic: Planning 🙂\n\nNotes\n".utf16.count)
    }
}


@Suite(.serialized)
struct ExpansionPanelFocusTests {
    @Test(arguments: ["{{field:topic}}", "{{input:topic|optional}}", "{{input:topic|multiline}}", "{{input:topic|choice|One|Two}}", "{{input:topic|date|yyyy-MM-dd}}"])
    @MainActor func presentationFocusesTheFieldWithoutAUserClick(body: String) async throws {
        let group = SnippetGroup(name: "Panel test")
        let snippet = Snippet(groupID: group.id, title: "Panel focus acceptance", abbreviation: ";panel", body: body)
        let prompt = ExpansionPrompt()
        defer { prompt.cancel() }
        prompt.show(snippet: snippet, library: Library(groups: [group], snippets: [snippet]), anchor: NSRect(x: 100, y: 300, width: 0, height: 18)) { _ in }
        let panel = try #require(NSApp.windows.first { $0.title == snippet.title && $0.isVisible } as? ExpansionInputPanel)
        for _ in 0..<30 {
            if let responder = panel.firstResponder as? NSView, responder !== panel.contentView, responder.acceptsFirstResponder { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(panel.isKeyWindow)
        let responder = try #require(panel.firstResponder as? NSView)
        #expect(responder !== panel.contentView)
        #expect(responder.acceptsFirstResponder)
        if body == "{{field:topic}}" {
            let editor = try #require(panel.firstResponder as? NSTextView)
            #expect(editor.isFieldEditor)
            #expect(editor.isEditable)
            #expect(panel.contentLayoutRect.height < 90)
        }
        #expect(panel.frame.width == 280)
    }
}
