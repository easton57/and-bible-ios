# Android Bookmark Contract (Current iOS Surface)

This document captures the current bookmark-domain parity surface on iOS.

Primary code references:

- bookmark business logic:
  `Sources/BibleCore/Sources/BibleCore/Services/BookmarkService.swift`
- bookmark models:
  `Sources/BibleCore/Sources/BibleCore/Models/Bookmark.swift`
- bookmark browser:
  `Sources/BibleUI/Sources/BibleUI/Bookmarks/BookmarkListView.swift`
- label assignment and label manager:
  `Sources/BibleUI/Sources/BibleUI/Bookmarks/`
- reader-side bridge integration:
  `Sources/BibleUI/Sources/BibleUI/Bible/BibleReaderController.swift`

## Domain Contract

The bookmark domain currently includes:

- Bible bookmarks
- generic bookmarks
- bookmark notes
- labels and primary-label assignment
- StudyPad label-linked content
- My Notes note-bearing bookmark workflows

## Bookmark Type and Sort Contract

The iOS bookmark models preserve Android-style raw-value semantics for:

- bookmark types
- bookmark sort orders
- edit-action modes
- custom icon identifiers

These raw values must remain parity-safe because they are used by persistence,
bridge state, and sync flows.

## Note Contract

iOS preserves the split between:

- bookmark records
- separate note payload entities

That separation is part of the current performance and sync shape, and it
drives the product split between the regular bookmark list and My Notes.

## Label and StudyPad Contract

Bookmark labeling preserves parity-sensitive behaviors for:

- toggle/remove label assignment
- primary label selection
- label-based StudyPad grouping and ordering
- bookmark-to-label ordering metadata

StudyPad remains part of the bookmark domain because it is driven by labels and
bookmark-to-label relationships rather than a completely separate model family.

## Bookmark List Contract

`BookmarkListView` currently provides the main native browser for:

- label filtering
- text search
- sort selection
- row deletion
- label assignment entry
- StudyPad handoff from a selected label

## My Notes Contract

Note-bearing bookmark workflows are preserved separately through My Notes.

This is still part of the bookmark domain contract because note persistence,
bookmark-note deletion, and note mutation are backed by the same bookmark
services and models.
