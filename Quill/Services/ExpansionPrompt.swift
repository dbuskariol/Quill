import AppKit
import SwiftUI

/// Holds an immutable template/target transaction while the user supplies literal values.
@MainActor final class ExpansionPrompt: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var completion: ((RenderResult?) async throws -> Void)?

    func show(snippet: Snippet, library: Library, completion: @escaping (RenderResult?) async throws -> Void) {
        cancel()
        self.completion = completion
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
                            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        panel.title = "Expand \(snippet.title)"
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: ExpansionForm(snippet: snippet, library: library) { [weak self] result in
            try await self?.finish(result)
        })
        panel.center()
        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
    func cancel() {
        completion = nil
        close()
    }
    func windowWillClose(_ notification: Notification) {
        guard let callback = completion else { return }
        cancel()
        Task { try? await callback(nil) }
    }
    private func close() {
        let window = panel
        panel = nil
        window?.delegate = nil
        window?.close()
    }
    private func finish(_ result: RenderResult?) async throws {
        guard let callback = completion, let window = panel else { return }
        // Keep the hosted form and its answers alive while returning focus to the target.
        window.orderOut(nil)
        do {
            try await callback(result)
            guard panel === window else { return }
            completion = nil
            close()
        } catch {
            guard panel === window else { return }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            throw error
        }
    }
}

private struct ExpansionForm: View {
    let snippet: Snippet
    let library: Library
    let complete: (RenderResult?) async throws -> Void
    @State private var submitting = false
    @State private var insertionError: String?
    @State private var fields: [String: String] = [:]
    @State private var date = Date.now
    private var result: Result<RenderResult, Error> {
        Result { try TemplateRenderer.render(snippet, library: library, context: .init(date: date, fields: fields)) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch result {
                    case let .success(preview):
                        TemplateFieldsView(result: preview, fields: $fields, focusInitially: true)
                        Divider()
                        if preview.format == .markdown, let document = try? MarkdownDocument(preview.text) {
                            FormattedPreview(document: document).frame(height: 160)
                        } else { Text(preview.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                    case let .failure(error):
                        Text(error.localizedDescription).foregroundStyle(.red)
                    }
                }
            }
            if let insertionError { Text(insertionError).foregroundStyle(.red).textSelection(.enabled) }
            HStack {
                Button("Cancel") { submit(nil) }.keyboardShortcut(.cancelAction).disabled(submitting)
                Spacer()
                Button("Expand") { if let value = try? result.get() { submit(value) } }
                    .keyboardShortcut(.defaultAction).disabled(!isReady || submitting)
            }
        }.padding(20).frame(minWidth: 360, minHeight: 280)
    }
    private func submit(_ value: RenderResult?) {
        guard !submitting else { return }
        submitting = true
        insertionError = nil
        Task { @MainActor in
            do { try await complete(value) }
            catch { insertionError = error.localizedDescription }
            submitting = false
        }
    }
    private var isReady: Bool {
        guard let value = try? result.get() else { return false }
        return value.fields.allSatisfy { name in
            !(value.fieldDefinitions.first { $0.name == name }?.isRequired ?? true) || !fields[name, default: ""].isEmpty
        }
    }
}
