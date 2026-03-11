// CrossReferenceView.swift — Popup showing cross-reference verses with navigation

import SwiftUI

/**
 Displays the cross-reference list for the currently selected verse or passage.

 The sheet is a thin navigation surface: it renders resolved cross-reference metadata and delegates
 actual navigation back to its parent when the user selects a destination reference.

 Data dependencies:
 - `references` contains the resolved cross-reference metadata and optional preview text
 - `onNavigate` is supplied by the presenting view to route the user into the selected
   book/chapter destination

 Side effects:
 - tapping a row invokes `onNavigate` with the selected reference destination
 */
struct CrossReferenceView: View {
    /// Cross-reference rows to display.
    let references: [CrossReference]

    /// Callback invoked when the user selects one of the displayed references.
    let onNavigate: (String, Int) -> Void

    /**
     Builds the navigable cross-reference list.
     */
    var body: some View {
        NavigationStack {
            List(references) { ref in
                Button {
                    onNavigate(ref.book, ref.chapter)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ref.displayName)
                            .font(.headline)
                        if !ref.text.isEmpty {
                            Text(ref.text)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle(String(localized: "cross_references"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}
