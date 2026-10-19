# Test taxonomy (v1.6.5)

Canonical layout (new tests go here):

- `test/analysis/` — L1/L2/L3, fusion, eval, PII
- `test/services/` — bridges, permissions
- `test/ui/` — widget/onboarding tests
- `test/data/` — database / session recovery
- `test/core/` — domain helpers

Legacy folders still present for compatibility (do not add new files here):

- `test/L/` → prefer `test/analysis/`
- `test/Other/` → prefer `test/services/` or `test/data/` or `test/analysis/`
- `test/UI/` → prefer `test/ui/`

CI continues to run `flutter test --exclude-tags perf` over the whole tree.
