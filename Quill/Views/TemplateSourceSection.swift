import SwiftUI

/// Both template editors share source spacing, insertion and content sizing.
struct TemplateSourceSection: View {
    @Binding var text: String
    let library: Library
    let controller: TemplateEditorController
    var excludingSnippet: UUID?
    var excludingMacro: UUID?
    let accessibilityName: String
    let showZendesk: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Template").font(.headline)
                Spacer()
                TemplateInsertionMenu(library: library, excludingSnippet: excludingSnippet, excludingMacro: excludingMacro, insert: controller.insert, showZendesk: showZendesk)
            }
            TemplateEditor(text: $text, library: library, controller: controller, excludingSnippet: excludingSnippet, excludingMacro: excludingMacro, accessibilityName: accessibilityName)
        }
    }
}
