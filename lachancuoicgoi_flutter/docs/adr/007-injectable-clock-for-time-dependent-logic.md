# ADR-007: Injectable Clock & Clock-Independent Fixtures for Time-Dependent Logic

## Status

Accepted as guidance (smoke-test fix applied; product-side DI refactor queued as future work)

## Context

Several features depend on wall-clock time:

1. `CallHistoryRetention` cleanup runs at app start (`_cleanupExpiredHistory` in `lib/app/lachancuocgoi_app.dart`) and after each save (`SessionEnder`), deleting rows older than the retention window (default 30 days).
2. History rows store `dateTime`/`recordedAt` timestamps.

The `platform_demo_smoke_test` fixture inserted a history row with a **hardcoded timestamp** (`DateTime(2026, 7, 18, 9)`). While the app-start retention cleanup stayed inside a 30-day window (test committed 2026-07-23), the fixture survived and the test passed. Once the system clock passed ~2026-08-17, the cleanup silently deleted the fixture row before `ResultPage` resolved it, so the page rendered its empty state and the test failed with `Found 0 widgets with text containing OTP`.

Root cause class: **tests that depend on the system clock** — they pass for a limited time and break later without any code change.

## Decision

1. **Tests:** provide clock-independent fixtures.
   - Fixture timestamps may be `DateTime.now()`-derived, or
   - the retention policy under test may be pinned explicitly (e.g. `SharedPreferences` `CALL_HISTORY_RETENTION = forever`) so cleanup cannot delete fixture rows mid-test.
2. **Product code (targeted refactor):** inject `now`/clock as a parameter or lightweight abstraction (`DateTime Function()` / `Clock`) for retention cutoffs (`CallHistoryRetentionService.cleanup`, `AppDatabase.deleteOlderThan` callers), so both product and tests can freeze time deterministically.
3. When dates appear in golden/eval fixtures, they must be either relative to the clock or protected by an explicit retention override.

## Consequences

**Positive:**
- Time-dependent tests become deterministic and never rot silently with the calendar.
- Retention behavior becomes testable: cutoff windows can be exercised with fixed timestamps.
- Matches the direction of ADR-005 (adaptive-timeout consolidation) by keeping time policy explicit.

**Negative:**
- Small refactor cost: every retention call site gains a `now` parameter (default keeps current behavior).
- Fixture style gains one more convention contributors must follow.

## References

- `test/smoke/platform_demo_smoke_test.dart` (retention override fix)
- `lib/data/call_history_retention.dart` (`cleanup(now:)` parameter precedent already present)
- `lib/app/lachancuocgoi_app.dart` (`_cleanupExpiredHistory` at startup)
- `lib/ui/monitoring_page/session_ender.dart` (post-save cleanup hook)
