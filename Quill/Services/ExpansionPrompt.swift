import AppKit
import SwiftUI

/// Holds an immutable template/target transaction while the user supplies literal values.
@MainActor final class ExpansionPrompt: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var submitting = false
    private var completion: ((RenderResult?) async throws -> Void)?

    func show(snippet: Snippet, library: Library, anchor: NSRect, completion: @escaping (RenderResult?) async throws -> Void) {
        cancel()
        self.completion = completion
        let rendered = try? TemplateRenderer.render(snippet, library: library)
        let fields = rendered?.fieldDefinitions ?? []
        let height = min(CGFloat(420), 78 + fields.reduce(CGFloat.zero) { total, field in
            switch field.kind {
            case .multiline: total + 108
            case .date: total + 80
            default: total + 42
            }
        })
        let panel = ExpansionInputPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: max(120, height)),
                            styleMask: [.titled, .utilityWindow, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = snippet.title
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.isRestorable = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: ExpansionForm(snippet: snippet, library: library) { [weak self] result in
            try await self?.finish(result)
        })
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
        if let screen {
            panel.setFrame(ExpansionPanelLayout.frame(size: panel.frame.size, anchor: anchor, visibleFrame: screen.visibleFrame), display: false)
        }
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
    }
    func cancel() {
        completion = nil
        close()
    }
    func windowDidResignKey(_ notification: Notification) {
        guard !submitting, let callback = completion else { return }
        cancel()
        Task { try? await callback(nil) }
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
        submitting = true
        defer { submitting = false }
        window.orderOut(nil)
        do {
            try await callback(result)
            guard panel === window else { return }
            completion = nil
            close()
        } catch {
            guard panel === window else { return }
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
        VStack(alignment: .leading, spacing: 10) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    switch result {
                    case let .success(preview):
                        TemplateFieldsView(result: preview, fields: $fields, focusInitially: true)

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
        }.padding(12).frame(minWidth: 296, minHeight: 96)
        .onSubmit { if isReady, let value = try? result.get() { submit(value) } }
        .onKeyPress(.return, phases: .down) { event in
            guard event.modifiers.contains(.command), isReady, let value = try? result.get() else { return .ignored }
            submit(value)
            return .handled
        }
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

/// Takes keyboard focus without activating Quill or raising its library windows.
@MainActor final class ExpansionInputPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// AX coordinates use the primary display's top-left; AppKit uses its bottom-left.
enum ExpansionPanelLayout {
    static func appKitRect(_ rect: CGRect, primaryDisplayTop: CGFloat) -> NSRect {
        NSRect(x: rect.minX, y: primaryDisplayTop - rect.maxY, width: rect.width, height: rect.height)
    }
    static func frame(size: NSSize, anchor: NSRect, visibleFrame: NSRect) -> NSRect {
        let margin: CGFloat = 8
        let size = NSSize(width: min(size.width, visibleFrame.width - 2 * margin), height: min(size.height, visibleFrame.height - 2 * margin))
        let below = anchor.minY - size.height - margin
        let y = below >= visibleFrame.minY + margin ? below : anchor.maxY + margin
        return NSRect(x: min(max(anchor.minX, visibleFrame.minX + margin), visibleFrame.maxX - size.width - margin),
                      y: min(max(y, visibleFrame.minY + margin), visibleFrame.maxY - size.height - margin),
                      width: size.width, height: size.height)
    }
}
