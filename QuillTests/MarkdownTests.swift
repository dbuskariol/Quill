import AppKit
import Foundation
import Testing
@testable import Quill

struct MarkdownTests {
    @Test func formattingUsesSafeHTMLAndPreservesZendeskExpressions() throws {
        let text = "# Reply\n\n**Hi {{ticket.requester.first_name}}**, *welcome*.\n\n[Help](https://example.com/help)\n\n`code`"
        let document = try MarkdownDocument(text)
        #expect(document.html.contains("<h1>")); #expect(document.html.contains("<strong>Hi {{ticket.requester.first_name}}</strong>"))
        #expect(document.html.contains("<em>welcome</em>")); #expect(document.html.contains("href=\"https://example.com/help\""))
        #expect(document.plainText.contains("Hi {{ticket.requester.first_name}}, welcome."))
        #expect(!document.plainText.contains("**"))
    }
    @Test func listsCodeAndUnsafeLinksHaveExplicitBoundaries() throws {
        let document = try MarkdownDocument("- One\n- Two\n  - Nested\n\n```swift\nlet x = \"<tag>\"\n```\n\n[bad](javascript:alert)\n\n<script>alert(1)</script>")
        #expect(document.html.contains("<ul>")); #expect(document.html.contains("<li>")); #expect(document.html.contains("<pre><code>"))
        #expect(document.html.contains("&lt;script&gt;")); #expect(!document.html.contains("<script>"))
        #expect(!document.html.contains("href=\"javascript:")); #expect(document.warnings.count >= 2)
        #expect(document.plainText.contains("Nested")); #expect(document.plainText.contains("let x"))
    }
    @Test func literalFieldsAndMixedFormatReferencesRemainLiteral() throws {
        let group = SnippetGroup(name: "Work")
        let macro = CustomMacro(name: "plain", body: "**literal** {{ticket.requester.first_name}}")
        let snippet = Snippet(groupID: group.id, title: "Reply", abbreviation: ";r", body: "**Hello** {{field:name}}\n{{macro:plain}}", format: .markdown)
        let library = Library(groups: [group], snippets: [snippet], macros: [macro])
        let rendered = try TemplateRenderer.render(snippet, library: library, context: RenderContext(fields: ["name": "**not bold** [not a link](https://example.com)"]))
        let document = try MarkdownDocument(rendered.text)
        #expect(rendered.format == .markdown)
        #expect(document.plainText.contains("**not bold** [not a link](https://example.com)"))
        #expect(document.plainText.contains("**literal** {{ticket.requester.first_name}}"))
        #expect(!document.html.contains("<strong>not bold</strong>"))
        let richMacro = CustomMacro(name: "rich", body: "**Bold**", format: .markdown)
        let plain = Snippet(groupID: group.id, title: "Plain", abbreviation: ";p", body: "{{macro:rich}}")
        #expect(try TemplateRenderer.render(plain, library: Library(groups: [group], snippets: [plain], macros: [richMacro])).text == "Bold")
    }
    @Test func escapedURLsAndAutolinksRespectLiteralAndCodeBoundaries() throws {
        let literal = "https://example.com/a-b?q=(value)"
        #expect(try MarkdownDocument(MarkdownDocument.escapeLiteral(literal)).plainText == literal)
        let code = try MarkdownDocument("`https://example\\.com`")
        #expect(code.plainText == "https://example\\.com")
        let link = try MarkdownDocument("<https://example.com>")
        #expect(link.html.contains("href=\"https://example.com\""))
        #expect(link.warnings.isEmpty)
    }
    @Test @MainActor func formattedCopyAndRepeatKeepAllFormatsOnAnOwnedPasteboard() throws {
        let name = "QuillTests-" + UUID().uuidString, defaults = try #require(UserDefaults(suiteName: name))
        let board = NSPasteboard(name: .init(name))
        defer { board.clearContents(); defaults.removePersistentDomain(forName: name) }
        let actions = QuickActionStore(statistics: LocalStatistics(defaults: defaults), pasteboard: board)
        let group = SnippetGroup(name: "Work"), snippet = Snippet(groupID: UUID(), title: "Reply", abbreviation: ";r", body: "**Hi** {{ticket.id}}", format: .markdown)
        let rendered = try TemplateRenderer.render(snippet, library: Library(groups: [group], snippets: []))
        #expect(actions.copy(rendered))
        #expect(board.string(forType: .string) == "Hi {{ticket.id}}")
        let html = try #require(board.data(forType: .html)), rtf = try #require(board.data(forType: .rtf))
        #expect(String(decoding: html, as: UTF8.self).contains("<strong>Hi</strong>"))
        board.clearContents(); board.setString("Other content", forType: .string)
        actions.repeatLastCopy()
        #expect(board.data(forType: .html) == html); #expect(board.data(forType: .rtf) == rtf)
        #expect(actions.copy(rendered, style: .markdown)); #expect(board.string(forType: .string) == snippet.body)
        #expect(board.data(forType: .html) == nil)
    }
    @Test func literalMarkupAndEntitiesRemainLiteral() throws {
        let value = "<tag> &amp; **plain**"
        let document = try MarkdownDocument(MarkdownDocument.escapeLiteral(value))
        #expect(document.plainText == value)
        #expect(!document.html.contains("<tag>")); #expect(!document.html.contains("<strong>plain</strong>"))
        #expect(document.warnings.isEmpty)
    }
    @Test func currentFormatsRoundTripAndRejectOutdatedDefinitions() throws {
        let group = SnippetGroup(name: "Work")
        let item = Snippet(groupID: group.id, title: "Reply", abbreviation: ";r", body: "**Hello**", format: .markdown)
        let library = Library(groups: [group], snippets: [item])
        #expect(library.version == 3)
        #expect(try LibraryRepository.decode(LibraryRepository.encode(library)) == library)
        let legacy = #"{"version":1,"groups":[],"snippets":[]}"#
        #expect(throws: LibraryError.self) { try LibraryRepository.decode(Data(legacy.utf8)) }
    }
    @Test @MainActor func nativeFormattedContentHasReadableStylesWithoutHTMLLoading() throws {
        let document = try MarkdownDocument("**Bold** and *italic* {{ticket.id}}")
        let text = FormattedContent.attributed(document)
        #expect(text.string == "Bold and italic {{ticket.id}}")
        #expect(text.attribute(.font, at: 0, effectiveRange: nil) != nil)
        let rtf = try text.data(from: NSRange(location: 0, length: text.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        #expect(!rtf.isEmpty)
    }
}
