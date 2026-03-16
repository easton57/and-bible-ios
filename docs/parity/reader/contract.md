# Android Reader Contract (Current iOS Surface)

This document captures the Android-aligned reader behaviors currently driven by
the iOS reading shell.

Primary code references:

- top-level reader coordinator:
  `Sources/BibleUI/Sources/BibleUI/Bible/BibleReaderView.swift`
- main document controller:
  `Sources/BibleUI/Sources/BibleUI/Bible/BibleReaderController.swift`
- web view coordinator and swipe handling:
  `Sources/BibleView/Sources/BibleView/WebViewCoordinator.swift`
- pane shell:
  `Sources/BibleUI/Sources/BibleUI/Bible/BibleWindowPane.swift`

## Core Reader Contract

The iOS reader preserves the Android-style split between:

- a document-rendering surface in the WebView
- native coordination for windows, sheets, toolbars, and overlays
- Android-parity settings that drive runtime reader behavior

## Preference-Driven Reader Behaviors

The following Android-origin settings directly affect reader behavior on iOS:

- `navigate_to_verse_pref`
- `open_links_in_special_window_pref`
- `double_tap_to_fullscreen`
- `auto_fullscreen_pref`
- `disable_two_step_bookmarking`
- `bible_view_swipe_mode`
- `toolbar_button_actions`
- `full_screen_hide_buttons_pref`
- `hide_window_buttons`
- `hide_bible_reference_overlay`
- `show_active_window_indicator`

These behaviors are documented in detail in the settings parity matrix, but the
reader is where they are actually consumed.

## Navigation Contract

iOS currently preserves Android-oriented reader navigation semantics for:

- chapter/page/none swipe modes
- active-window tracking
- current-window vs links-window navigation
- history updates and jump-back navigation
- fullscreen transitions triggered from document interaction

## Bookmarking Contract

Reader-side bookmark actions preserve Android-oriented behavior for:

- one-step vs two-step bookmarking
- whole-verse vs selection bookmarks
- bridge-driven label assignment entry points
- bookmark updates reflected back into the WebView document

## Display Contract

The reader still pushes a shared config payload into the WebView surface,
including Android-parity display options such as:

- night mode state
- monochrome mode
- animation disablement
- font-size multiplier
- bookmark modal button disablement
- active-window indicator visibility

## Window and Comparison Contract

The reader continues to preserve multi-window and comparison-oriented behavior
through:

- focused window tracking
- special links windows
- compare sheet/module-picker flows
- synchronized window scrolling and active-window signaling
