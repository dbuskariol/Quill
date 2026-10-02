import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct StatisticsSettingsView: View {
    @Bindable var statistics: LocalStatistics
    let store: LibraryStore
    let requestReset: () -> Void
    @State private var exportError: String?
    var body: some View {
        Section {
            Toggle("Count expansions and copies on this Mac", isOn: $statistics.isEnabled)
            Text("Totals stay on this Mac. No snippet text, field values or keystrokes are recorded.").font(.caption).foregroundStyle(.secondary)
            LabeledContent("Confirmed expansions", value: statistics.totals.expansions.formatted())
            LabeledContent("Preview copies", value: statistics.totals.copies.formatted())
            LabeledContent("Characters avoided", value: statistics.totals.charactersAvoided.formatted())
            LabeledContent("Estimated time saved", value: "\((statistics.estimatedSecondsSaved / 60).formatted(.number.precision(.fractionLength(1)))) minutes")
                .help("Based on five characters per word, excluding the abbreviation, copy time and form entry.")
            Stepper("Typing baseline: \(Int(statistics.wordsPerMinute)) words/minute", value: $statistics.wordsPerMinute, in: 10...200, step: 5)
            HStack {
                Button("Export Totals…", action: export)
                Button("Reset Totals…", role: .destructive, action: requestReset)
            }
            if let exportError { Text(exportError).foregroundStyle(.red) }
        }
    }
    private func export() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "Quill Usage Totals.json"
        Task {
            guard await NativeFilePanel.present(panel) == .OK, let url = panel.url else { return }
            do { try await store.exportStatistics(to: url); exportError = nil }
            catch { exportError = error.localizedDescription }
        }
    }
}
