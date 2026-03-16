# Android Reading Plan Contract (Current iOS Surface)

This document captures the current Android-aligned reading-plan contract on iOS.

Primary code references:

- template and lifecycle service:
  `Sources/BibleCore/Sources/BibleCore/Services/ReadingPlanService.swift`
- persisted models:
  `Sources/BibleCore/Sources/BibleCore/Models/ReadingPlan.swift`
- UI surfaces:
  `Sources/BibleUI/Sources/BibleUI/ReadingPlans/`

## Template Contract

The parity baseline for bundled reading plans is the Android `.properties` plan
format.

iOS currently loads bundled Android-parity plans from:

- `Resources/readingplan/*.properties`

using day-number to reading-string semantics.

## Day Numbering Contract

The plan-template and day-row contract is intentionally 1-based:

- template day generation is 1-based
- persisted `ReadingPlanDay.dayNumber` is 1-based

The stored `ReadingPlan.currentDay` field remains separate from those rows.

## Plan Start Contract

Starting a plan on iOS currently means:

1. create the persisted `ReadingPlan`
2. pre-generate every `ReadingPlanDay`
3. mark the new plan active
4. initialize `currentDay` to `0`

This is the current persisted contract used by the UI and sync layers.

## Import Contract

iOS supports importing custom plans using the same Android `.properties`
syntax:

- `dayNumber=OsisRef1,OsisRef2,...`

Non-numeric keys such as `Versification=...` are ignored during parsing.

## UI Contract

The reading-plan UI currently preserves these major flows:

- browsing available plans
- starting a built-in plan
- viewing daily readings
- advancing completion day by day

These workflows are covered by the native SwiftUI reading-plan screens.
