# Parity Documentation

This subtree holds cross-platform parity material.

Use domain folders so each parity area can carry, as needed:

- source-of-truth contract
- documented iOS dispositions/divergences
- verification matrix
- regression evidence
- machine-readable baselines

Current maturity:

- `settings/` is the most complete domain and already includes guardrails,
  verification, regression evidence, and baselines
- higher-risk domains such as `bridge/`, `sync/`, `bookmarks/`, and `search/`
  now also include explicit guardrails because their contract drift is hard to
  catch after the fact
- the remaining domains currently center on contract, dispositions,
  verification, and regression evidence, with room to add guardrails or
  baselines where they justify the maintenance cost

Current domains:

- [bridge/](bridge/README.md)
- [reader/](reader/README.md)
- [bookmarks/](bookmarks/README.md)
- [search/](search/README.md)
- [reading-plans/](reading-plans/README.md)
- [settings/](settings/README.md)
- [sync/](sync/README.md)
