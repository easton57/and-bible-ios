# iOS Reading Plan Parity Dispositions

This file records explicit iOS reading-plan adaptations and extensions.

## 1. iOS includes additional algorithmic plans

- Status: intentional iOS extension

Disposition:

- In addition to the bundled Android-parity `.properties` plans, iOS currently
  exposes a small set of algorithmic plans with no Android equivalent.

Reason:

- These are additive product extensions and do not replace the Android parity
  baseline for bundled plans.

## 2. `currentDay` remains zero-based while day rows are one-based

- Status: intentional persisted constraint

Disposition:

- `ReadingPlan.currentDay` is initialized to `0`.
- Generated `ReadingPlanDay.dayNumber` values remain 1-based.

Reason:

- This matches the current persisted contract used by existing UI and backup/sync
  flows, even though it is easy to misread during implementation.

## 3. Import preserves Android `.properties` syntax, not a new iOS-only format

- Status: intentional compatibility preservation

Disposition:

- Custom plan import on iOS intentionally keeps Android `.properties` semantics
  rather than defining a separate iOS-native reading-plan import format.

Reason:

- The bundled parity plans and import behavior are easier to reason about when
  the same source syntax is accepted across platforms.
