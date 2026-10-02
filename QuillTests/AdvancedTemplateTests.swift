import Foundation
import Testing
@testable import Quill

struct AdvancedTemplateTests {
    private func render(_ body: String, fields: [String: String] = [:]) throws -> RenderResult {
        let group = SnippetGroup(name: "Tests")
        let snippet = Snippet(groupID: group.id, title: "Template", abbreviation: ";test", body: body)
        return try TemplateRenderer.render(snippet, library: Library(groups: [group], snippets: [snippet]), context: .init(date: Date(timeIntervalSince1970: 0), timeZone: TimeZone(secondsFromGMT: 0)!, fields: fields))
    }
    @Test func resolvesTypedInputsLiterally() throws {
        let result = try render("{{input:notes|multiline}}/{{input:extra|optional}}/{{input:tone|choice|Formal|Friendly}}", fields: ["notes": "{{date}}\nline", "tone": "Formal"])
        #expect(result.text == "{{date}}\nline//Formal")
        #expect(result.fieldDefinitions.count == 3)
        #expect(result.fieldDefinitions.first { $0.name == "extra" }?.isRequired == false)
        #expect(throws: TemplateError.self) { try render("{{input:tone|choice|Formal|Friendly}}", fields: ["tone": "Other"]) }
    }
    @Test func conditionalBranchesOnlyResolveSelectedContent() throws {
        #expect(try render("{{if:tone=Formal}}Hello{{else}}{{if:short=yes}}Hi{{else}}Hey{{end}}{{end}}!", fields: ["tone": "Friendly", "short": "yes"]).text == "Hi!")
        #expect(try render("{{if:tone=Formal}}{{snippet:missing}}{{else}}Hi{{end}}", fields: ["tone": "Friendly"]).text == "Hi")
        #expect(throws: TemplateError.self) { try render("{{if:tone=Formal}}Hello") }
        #expect(throws: TemplateError.self) { try render("{{end}}") }
    }
    @Test func formattedDatesOffsetsAndDatePicker() throws {
        #expect(try render("{{date:yyyy-MM-dd|7}}/{{input:chosen|date|yyyy/MM/dd}}", fields: ["chosen": "2026-10-02"]).text == "1970-01-08/2026/10/02")
        #expect(throws: TemplateError.self) { try render("{{input:chosen|date|yyyy-MM-dd}}", fields: ["chosen": "2026-02-30"]) }
        #expect(throws: TemplateError.self) { try render("{{date:yyyy-MM-dd|-9223372036854775808}}") }
    }
    @Test func arithmeticHasPrecedenceBoundsAndNoExecution() throws {
        #expect(try render("{{math:(2+3)*4-1/2}}").text == "19.5")
        #expect(throws: TemplateError.self) { try render("{{math:1/0}}") }
        #expect(throws: TemplateError.self) { try render("{{math:system(1)}}") }
        #expect(throws: TemplateError.self) { try render("{{math:9999999999999999}}") }
        #expect(throws: TemplateError.self) { try render("{{math:2+}}") }
    }
    @Test func structuralLimitsRejectAmbiguousControlsAndDeepNesting() {
        #expect(throws: TemplateError.self) { try render("{{input:name|choice|Same|Same}}") }
        let deeplyNested = String(repeating: "{{if:x=yes}}", count: 33) + "text" + String(repeating: "{{end}}", count: 33)
        #expect(throws: TemplateError.self) { try render(deeplyNested) }
        let deepArithmetic = String(repeating: "(", count: 40) + "1" + String(repeating: ")", count: 40)
        #expect(throws: TemplateError.self) { try ArithmeticEvaluator.evaluate(deepArithmetic) }
    }
    @Test func conflictingFieldDefinitionsFail() {
        #expect(throws: TemplateError.self) { try render("{{field:name}}/{{input:name|multiline}}") }
    }
}
