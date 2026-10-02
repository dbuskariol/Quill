import SwiftUI

struct TemplateInsertionMenu: View {
    let library: Library
    var excludingSnippet: UUID?
    var excludingMacro: UUID?
    let insert: (String) -> Void
    let showZendesk: () -> Void
    var body: some View {
        Menu("Insert") {
            ForEach(TemplateCompletion.builtins) { item in Button(item.label) { insert(item.token) } }
            Button("Conditional Section") { insert(TemplateCompletion.conditional) }
            Divider()
            Menu("Custom Macro") {
                ForEach(TemplateCompletion.availableMacros(in: library, excluding: excludingMacro)) { item in
                    Button(item.name) { insert("{{macro:\(item.name)}}") }
                }
            }.disabled(TemplateCompletion.availableMacros(in: library, excluding: excludingMacro).isEmpty)
            Menu("Snippet") {
                ForEach(TemplateCompletion.availableSnippets(in: library, excluding: excludingSnippet)) { item in
                    Button("\(item.title) (\(item.abbreviation))") { insert("{{snippet:\(item.abbreviation)}}") }
                }
            }.disabled(TemplateCompletion.availableSnippets(in: library, excluding: excludingSnippet).isEmpty)
            Button("Zendesk Placeholder…", action: showZendesk)
        }.help("Insert a template token, or type {{ for suggestions")
    }
}
