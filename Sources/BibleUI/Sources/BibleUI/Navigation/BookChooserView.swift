// BookChooserView.swift — Book selection grid

import SwiftUI
import SwordKit

/// Grid-based book chooser for navigating to a Bible book.
///
/// Displays books from the active module's versification, grouped by testament.
/// Modules with apocrypha/deuterocanonical books will show additional sections.
public struct BookChooserView: View {
    let books: [BookInfo]
    let navigateToVerse: Bool
    let onSelect: (String, Int, Int?) -> Void
    @State private var selectedBook: BookInfo?
    @State private var selectedChapter: Int?
    @Environment(\.dismiss) private var dismiss

    /// Create a book chooser with a specific book list.
    /// - Parameters:
    ///   - books: The book list from the active module's versification.
    ///   - navigateToVerse: Whether selecting a passage should include a verse step.
    ///   - onSelect: Callback with (bookName, chapter, verse?) when selection is complete.
    public init(
        books: [BookInfo],
        navigateToVerse: Bool = false,
        onSelect: @escaping (String, Int, Int?) -> Void
    ) {
        self.books = books
        self.navigateToVerse = navigateToVerse
        self.onSelect = onSelect
    }

    /// Old Testament books from the provided list.
    private var oldTestamentBooks: [BookInfo] {
        books.filter { $0.testament == 1 }
    }

    /// New Testament books from the provided list.
    private var newTestamentBooks: [BookInfo] {
        books.filter { $0.testament == 2 }
    }

    public var body: some View {
        Group {
            if let book = selectedBook {
                if navigateToVerse, let chapter = selectedChapter {
                    VerseChooserView(
                        bookName: book.name,
                        chapter: chapter,
                        verseCount: BibleReaderController.verseCount(for: book.name, chapter: chapter)
                    ) { verse in
                        onSelect(book.name, chapter, verse)
                    }
                } else {
                    ChapterChooserView(bookName: book.name, chapterCount: book.chapterCount) { chapter in
                        if navigateToVerse {
                            selectedChapter = chapter
                        } else {
                            onSelect(book.name, chapter, nil)
                        }
                    }
                }
            } else {
                bookGrid
            }
        }
        .navigationTitle(navigationTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "cancel")) { dismiss() }
            }
            if selectedChapter != nil {
                ToolbarItem(placement: .navigation) {
                    Button(String(localized: "choose_chapter", defaultValue: "Choose Chapter")) {
                        selectedChapter = nil
                    }
                }
            } else if selectedBook != nil {
                ToolbarItem(placement: .navigation) {
                    Button(String(localized: "books")) {
                        selectedBook = nil
                        selectedChapter = nil
                    }
                }
            }
        }
    }

    private var navigationTitle: String {
        if let book = selectedBook, let chapter = selectedChapter {
            return "\(book.name) \(chapter)"
        }
        return selectedBook?.name ?? String(localized: "choose_book")
    }

    private var bookGrid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if !oldTestamentBooks.isEmpty {
                    Section(String(localized: "old_testament")) {
                        bookGridSection(books: oldTestamentBooks)
                    }
                }
                if !newTestamentBooks.isEmpty {
                    Section(String(localized: "new_testament")) {
                        bookGridSection(books: newTestamentBooks)
                    }
                }
            }
            .padding()
        }
    }

    private func bookGridSection(books: [BookInfo]) -> some View {
        let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(books) { book in
                Button(action: {
                    selectedBook = book
                    selectedChapter = nil
                }) {
                    Text(book.abbreviation)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
