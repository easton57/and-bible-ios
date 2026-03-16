# iOS Bridge Parity Dispositions

This file records explicit iOS bridge adaptations and intentional no-op
branches.

## 1. iOS preserves Android-style `window.android.*` calls via an injected shim

- Status: intentional adaptation

Disposition:

- iOS does not expose a literal Android `JavascriptInterface`.
- Instead, `BibleWebView` injects a `window.android` `Proxy` that forwards calls
  through `WKScriptMessageHandler`.

Reason:

- The shared frontend still calls Android-style APIs directly.
- Preserving that call surface is lower risk than forking the client contract.

## 2. `getActiveLanguages()` is cached for synchronous parity

- Status: intentional adaptation

Disposition:

- `getActiveLanguages()` is served from the injected
  `window.__activeLanguages__` cache on iOS.

Reason:

- `WKScriptMessageHandler` does not support synchronous return values.
- The cache preserves the frontend's expectation that this call is synchronous.

## 3. Some Android bridge actions remain intentional no-ops on iOS

- Status: documented divergence

Current intentional no-ops:

- `memorize`
- `addParagraphBreakBookmark`
- `addGenericParagraphBreakBookmark`

Reason:

- These flows do not currently have a complete native iOS implementation, so
  the bridge preserves the method surface without claiming feature parity.

## 4. Fullscreen and compare are handled through iOS-native presentation paths

- Status: intentional adaptation

Disposition:

- Fullscreen toggling is driven by injected web-side double-tap handling plus
  native reader state.
- Compare presentation uses native iOS presentation paths instead of Android's
  exact UI structure.

Reason:

- The user-facing behavior remains parity-oriented, but UIKit/SwiftUI
  presentation constraints differ from Android's activity/dialog model.
