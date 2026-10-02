import SwiftUI

@MainActor
func insertTemplateText(_ token: String, into text: inout String, selection: inout TextSelection?) {
    let range: Range<String.Index>
    if let selection, case let .selection(selectedRange) = selection.indices { range = selectedRange }
    else { range = text.endIndex..<text.endIndex }
    let position = text.distance(from: text.startIndex, to: range.lowerBound)
    text.replaceSubrange(range, with: token)
    selection = TextSelection(insertionPoint: text.index(text.startIndex, offsetBy: position + token.count))
}
