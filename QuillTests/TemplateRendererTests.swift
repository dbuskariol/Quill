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
