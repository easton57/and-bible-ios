# SETPAR-603 Localization Guardrails

## Purpose

Prevent regressions in settings localization parity by enforcing:

1. `AndBible/*.lproj` and `Localizations/*.lproj` stay in sync for parity settings keys.
2. iOS does not keep English strings when Android already has non-English translations.
3. English-placeholder counts per key do not increase above the committed baseline.

## Command

```bash
python3 scripts/check_settings_localization_guardrails.py
```

## Baseline Update

Only run after intentional localization changes:

```bash
python3 scripts/check_settings_localization_guardrails.py --write-baseline
```

This updates:

- `docs/settings-localization-guardrail-baseline.json`

## Notes

- Baseline is keyed to the current parity-key set and locale set.
- If Android adds new locale translations, iOS will fail guardrails until matching translations are added (or explicitly updated via approved baseline process).
