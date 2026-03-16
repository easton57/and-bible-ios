# iOS Search Parity Dispositions

This file records explicit iOS search adaptations.

## 1. Indexed search is backed by local FTS services

- Status: intentional adaptation

Disposition:

- iOS uses a local `SearchIndexService` plus direct SWORD fallback rather than
  treating search as a single implementation path.

Reason:

- The parity goal is Android-style indexed-search behavior and query semantics,
  not identical implementation internals.

## 2. Strong's lookups intentionally bypass normal query decoration

- Status: intentional compatibility preservation

Disposition:

- Strong's and lemma queries are detected early and are not quoted or decorated
  like ordinary word-mode searches.

Reason:

- Decorating these queries as normal text searches would break the Android-style
  entry-attribute behavior.

## 3. Current-book scope is tied to the active reader context

- Status: intentional adaptation

Disposition:

- The current-book search scope is derived from the currently focused book name
  and OSIS book identifier supplied by the reader shell.

Reason:

- On iOS, search is presented as a reader-owned sheet rather than an isolated
  activity with its own canonical navigation context.
