# iOS Reader Parity Dispositions

This file records explicit iOS reader adaptations.

## 1. Swipe navigation is implemented with native gestures, not Android view plumbing

- Status: intentional adaptation

Disposition:

- iOS maps `bible_view_swipe_mode` onto native gesture recognizers and WebView
  scrolling behavior rather than Android's exact view stack.

Reason:

- The parity goal is the resulting chapter/page/none behavior, not identical UI
  implementation.

## 2. Compare presentation uses native iOS sheet presentation

- Status: intentional adaptation

Disposition:

- Bridge-driven compare requests are presented through UIKit/SwiftUI sheet
  presentation rather than Android's exact activity/dialog structure.

Reason:

- The compare action must integrate with iOS presentation state and the
  top-most visible controller.

## 3. Reader fullscreen is coordinated by native shell state

- Status: intentional adaptation

Disposition:

- Web content can request fullscreen toggles, but the actual fullscreen state is
  owned by the native reader shell.

Reason:

- On iOS, hiding chrome, overlays, and bars is coordinated above the WebView,
  not inside the client bundle alone.

## 4. Some parity-sensitive reader inputs remain constrained by platform limits

- Status: documented constraint

Disposition:

- Hardware volume-key scrolling does not exist as a functional reader feature on
  iOS even though the setting is preserved for parity and sync continuity.

Reason:

- iOS does not expose app-level interception of hardware volume buttons for this
  type of custom reader action.
