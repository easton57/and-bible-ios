# iOS Settings Parity Dispositions

This file records explicit iOS disposition decisions for Android parity tickets where behavior is implemented differently due to platform constraints.

## SETPAR-209 — `volume_keys_scroll`

- Android contract:
  - Key: `volume_keys_scroll`
  - Source: `and-bible/app/src/main/res/xml/settings.xml:101-106`
  - Runtime consumer: `MainBibleActivity.kt` intercepts `KEYCODE_VOLUME_UP/DOWN` and emits Bible scroll events.
- iOS platform constraint:
  - Public iOS APIs do not provide app-level interception of hardware volume-button presses for arbitrary in-app actions.
- iOS disposition (implemented):
  - Keep the setting in iOS settings UI and persistence for cross-platform parity and synced preference continuity.
  - Show an iOS-specific note in UI clarifying the platform limitation.
  - No native volume-button scroll action is bound on iOS.
- iOS references:
  - UI + persistence: `Sources/BibleUI/Sources/BibleUI/Settings/SettingsView.swift`
  - Key registry/default: `Sources/BibleCore/Sources/BibleCore/Database/AppPreferenceRegistry.swift`
