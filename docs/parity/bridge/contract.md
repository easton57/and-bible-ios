# Android Bridge Contract (Current iOS Surface)

This document captures the Android-compatible bridge contract currently exposed
by iOS through `BibleView`.

Primary code references:

- bridge host and Android compatibility shim:
  `Sources/BibleView/Sources/BibleView/BibleWebView.swift`
- bridge dispatcher and delegate protocol:
  `Sources/BibleView/Sources/BibleView/BibleBridge.swift`
- main native delegate implementation:
  `Sources/BibleUI/Sources/BibleUI/Bible/BibleReaderController.swift`

## Core Transport Contract

The shared frontend still expects Android-style bridge semantics.

### JavaScript to native

The effective transport shape on iOS is:

```javascript
window.webkit.messageHandlers.bibleView.postMessage({ method, args })
```

But the web client is still allowed to call Android-style APIs such as
`window.android.addBookmark(...)` because iOS injects an Android compatibility
shim before the page loads.

### Native to JavaScript

Native code sends events back through:

```javascript
bibleView.emit(event, data)
```

### Async response contract

Deferred requests use the shared `callId` pattern:

```javascript
bibleView.response(callId, value)
```

That contract must remain stable across Android and iOS.

## Message Contract

The authoritative grouped catalog is the `BibleBridgeDelegate` protocol plus the
dispatcher switch in `BibleBridge`.

Current message groups:

- navigation and scroll position
- bookmark CRUD and label actions
- content actions such as share, copy, compare, and speak
- StudyPad and My Notes actions
- dialogs, reference parsing, and help
- client state/reporting messages

The important parity rule is that shared method names, argument ordering, and
response expectations must not drift casually.

## Event Contract

Current native-to-JS event groups include:

- document/config lifecycle (`set_config`, `clear_document`, `add_documents`,
  `setup_content`)
- navigation/scrolling (`scroll_to_verse`, `scroll_down`, `scroll_up`)
- bookmark and label updates (`add_or_update_bookmarks`, `delete_bookmarks`,
  `update_labels`)
- StudyPad updates
- selection and active-window state

If event names or payload shapes change, both iOS and Android clients must be
treated as affected.

## Compatibility Shim Contract

iOS currently preserves Android-oriented frontend assumptions by injecting:

- `window.__PLATFORM__ = 'ios'`
- `window.android = new Proxy(...)`
- a synchronous `getActiveLanguages()` cache via `window.__activeLanguages__`

This shim is part of the parity contract, not incidental glue. The Vue bundle
still relies on Android-style bridge calls in multiple places.

## Payload Contract

Swift payload definitions live in:

- `Sources/BibleView/Sources/BibleView/BridgeTypes.swift`

The corresponding TypeScript-side expectations live under:

- `bibleview-js/src/types/`

Payload drift is a high-risk change because it often fails at runtime without a
compile-time signal.
