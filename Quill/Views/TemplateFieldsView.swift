import AppKit
import SwiftUI

/// Shared by preview, quick actions and automatic expansion.
struct TemplateFieldsView: View {
    let result: RenderResult
    @Binding var fields: [String: String]
    var focusInitially = false
    @FocusState private var focusedField: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(result.fields, id: \.self) { name in
                fieldControl(result.fieldDefinitions.first { $0.name == name } ?? TemplateField(name: name))
            }
        }
        .background(InputFocusOnPresentation(enabled: focusInitially) {
            focusedField = result.fields.first
        })
    }
    @ViewBuilder private func fieldControl(_ field: TemplateField) -> some View {
        let binding = Binding(get: { fields[field.name, default: ""] }, set: { fields[field.name] = $0 })
        switch field.kind {
        case .singleLine, .optional:
            TextField(field.kind == .optional ? "\(field.name) (optional)" : field.name, text: binding)
                .textFieldStyle(.automatic).accessibilityLabel("Fill-in: \(field.name)").focused($focusedField, equals: field.name)
        case .multiline:
            VStack(alignment: .leading) {
                Text(field.name).font(.caption)
                TextEditor(text: binding).frame(minHeight: 70).accessibilityLabel("Fill-in: \(field.name)").focused($focusedField, equals: field.name)
            }
        case let .choice(choices):
            Picker(field.name, selection: binding) {
                Text("Choose…").tag("")
                ForEach(choices, id: \.self) { Text($0).tag($0) }
            }.focusable().focused($focusedField, equals: field.name)
        case .date:
            DatePicker(field.name, selection: Binding(get: {
                dateFormatter.date(from: binding.wrappedValue) ?? .now
            }, set: { binding.wrappedValue = dateFormatter.string(from: $0) }), displayedComponents: .date).focused($focusedField, equals: field.name)
            if binding.wrappedValue.isEmpty {
                Button("Use Today for \(field.name)") { binding.wrappedValue = dateFormatter.string(from: .now) }
            }
        }
    }
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

/// Request SwiftUI focus only after the hosting window can accept keyboard input.
/// Attaching a hosting view fires onAppear before a nonactivating panel becomes key.
struct InputFocusOnPresentation: NSViewRepresentable {
    let enabled: Bool
    let focus: () -> Void
    func makeNSView(context: Context) -> PresentationView { PresentationView() }
    func updateNSView(_ view: PresentationView, context: Context) {
        view.focus = enabled ? focus : nil
        view.requestFocus()
    }
    final class PresentationView: NSView {
        var focus: (() -> Void)?
        private var delivered = false
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            NotificationCenter.default.removeObserver(self)
            delivered = false
            if let window {
                NotificationCenter.default.addObserver(self, selector: #selector(windowBecameKey), name: NSWindow.didBecomeKeyNotification, object: window)
            }
            requestFocus()
        }
        @objc private func windowBecameKey(_ notification: Notification) { requestFocus() }
        func requestFocus() {
            guard !delivered, focus != nil, window?.isKeyWindow == true else { return }
            // Let AppKit finish installing the field editor and SwiftUI finish layout.
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.delivered, self.window?.isKeyWindow == true, let focus = self.focus else { return }
                self.delivered = true
                focus()
            }
        }
        deinit { NotificationCenter.default.removeObserver(self) }
    }
}
