# iOS Bookmark Parity Dispositions

This file records explicit iOS bookmark-domain adaptations.

## 1. Bookmark list and My Notes are intentionally split

- Status: intentional product partition

Disposition:

- `BookmarkListView` excludes note-bearing bookmarks.
- Note-bearing bookmark flows are surfaced through My Notes instead.

Reason:

- The current iOS bookmark browser follows the same conceptual split the
  product already expects between plain bookmark browsing and note-centric
  workflows.

## 2. Label and StudyPad management are native SwiftUI shells over shared data

- Status: intentional adaptation

Disposition:

- iOS uses native SwiftUI sheets and list views for label assignment, label
  management, and some bookmark browsing workflows.
- The underlying document/editor content still interacts with the WebView-based
  StudyPad and My Notes surfaces where appropriate.

Reason:

- The parity goal is shared data and user-visible behavior, not forcing every
  bookmark flow through identical Android UI structure.

## 3. System labels remain deterministic and mostly invisible

- Status: intentional compatibility preservation

Disposition:

- System labels such as speak/unlabeled/paragraph-break retain deterministic
  identifiers and are not treated like normal user-visible labels.

Reason:

- These identifiers participate in cross-device/state continuity and should not
  be casually regenerated or normalized away.
