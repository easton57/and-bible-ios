# BRIDGE-701 Verification Matrix (Android WebView Bridge -> iOS)

Date: 2026-03-16

## Scope and Method

- Contract baseline: `docs/parity/bridge/contract.md`
- Verification method:
  - direct code inspection of `BibleWebView`, `BibleBridge`, `BridgeTypes`,
    `BibleReaderController`, and `StrongsSheetView`
  - focused unit and simulator-backed regression coverage for the embedded
    My Notes and StudyPad document surfaces
- Regression evidence: `docs/parity/bridge/regression-report.md`

## Status Legend

- `Pass`: implemented and backed by direct code evidence plus current regression coverage
- `Adapted Pass`: parity delivered with explicit iOS implementation differences documented in
  `dispositions.md`
- `Partial`: implemented or exposed, but not yet backed by enough focused evidence to treat the
  area as locked

## Summary

- `Pass`: 1
- `Adapted Pass`: 1
- `Partial`: 5

## Matrix

| Bridge Contract Area | iOS Evidence | Status | Notes |
|---|---|---|---|
| Embedded My Notes and StudyPad surfaces stay connected to native persistence and document reload | `BibleBridge.swift`, `BibleReaderController.swift`; unit tests `testBookmarkServiceClearingBibleBookmarkNoteDeletesPersistedNoteRow`, `testBookmarkServiceClearingBibleBookmarkNoteRemovesBookmarkFromMyNotesQuery`; UI tests `testMyNotesDirectLaunchShowsHeaderAndReturnsToBible`, `testMyNotesSeededNoteUpdatePersistsAcrossReturnAndReopen`, `testMyNotesSeededNoteDeletePersistsAcrossReturnAndReopen`, `testBookmarkListOpensStudyPadForSelectedLabel`, `testBookmarkStudyPadCreateNoteFromLabelWorkflow` | Pass | This is the strongest currently locked bridge-adjacent surface: native note mutations survive the embedded document lifecycle and remain visible after reopen. |
| iOS preserves the Android-style `window.android.*` call surface and synchronous `getActiveLanguages()` behavior via an injected shim | `BibleWebView.swift` shim injection and `BibleBridge.updateActiveLanguages(_:)`; documented in `dispositions.md` | Adapted Pass | The implementation intentionally differs from Android transport, but the shared frontend still boots against the Android-oriented API surface. Current regression is indirect through embedded document workflows, not per-method. |
| Async `callId` request/response flows remain available for content expansion and native dialogs | `BibleBridge.sendResponse(...)`; `BibleReaderController` handlers for `requestMoreToBeginning`, `requestMoreToEnd`, `refChooserDialog`, and `parseRef` | Partial | The transport and native handlers exist, but there is no focused regression gate for `callId` request/response semantics yet. |
| Bookmark, label, and StudyPad delegate dispatch remains centralized in `BibleBridge` | `BibleBridge.userContentController(...)` bookmark and StudyPad switch branches; `BridgeTypes.swift` payload models | Partial | The method surface is broad and still Android-shaped, but there is no dedicated dispatcher regression suite to catch argument-order or method-name drift. |
| Strong's sheet reuses the same bridge transport and `set_config`/document event sequence | `StrongsSheetView.swift` dedicated `BibleBridge`, `bridgeDidSetClientReady(_:)`, and in-sheet history handling | Partial | The architecture is aligned with the main reader bridge, but there is no focused Strong's sheet regression evidence yet. |
| Fullscreen, compare, help, external-link, and reference-dialog entry points remain exposed through the bridge | `BibleBridge.swift` switch branches for `toggleFullScreen`, `compare`, `helpDialog`, `openExternalLink`, and `refChooserDialog`; `BibleReaderController.swift` handlers | Partial | These reader-owned branches are implemented, but they are not yet locked by focused bridge-domain regression coverage. |
| Swift bridge payloads remain centralized and expected to stay aligned with `bibleview-js` type expectations | `BridgeTypes.swift`; `bibleview-js/src/types/`; summarized in `bridge-guide.md` | Partial | The contract is explicit, but there is no automated parity diff or generated-schema guard yet. |
