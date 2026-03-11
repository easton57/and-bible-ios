// SearchResultsView.swift — Search results display

import SwiftUI
import SwordKit

/**
 Displays a read-only list of search hits returned from a module search.

 The view is a simple presentation layer over a resolved `SearchResults` payload. It groups hits by
 module and shows each result key with its preview text.

 Data dependencies:
 - `results` contains the module name, total result count, and individual search-hit previews to
   render
 */
public struct SearchResultsView: View {
    /// Search results payload to render.
    let results: SearchResults

    /**
     Creates a results list for a completed search payload.

     - Parameter results: Search-hit payload to display.
     */
    public init(results: SearchResults) {
        self.results = results
    }

    /**
     Builds the sectioned results list for the provided search payload.
     */
    public var body: some View {
        List {
            Section("\(results.count) results in \(results.moduleName)") {
                ForEach(results.results) { result in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.key)
                            .font(.headline)
                        Text(result.previewText)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Results")
    }
}
