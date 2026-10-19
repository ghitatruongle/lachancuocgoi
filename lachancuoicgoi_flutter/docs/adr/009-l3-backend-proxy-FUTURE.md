# ADR-009: L3 Backend Proxy — FUTURE / Deferred (not used in v1.6.5)

## Status

**Deferred** — design may exist; **not used** at runtime in **v1.6.5**.

## Context

Client-bundled Gemini keys are an accepted risk for v1.6.5 (see `docs/THREAT_MODEL.md`).
A reverse proxy would move keys server-side but requires hosting and operational budget.

## Decision for v1.6.5

1. Keep device → Gemini with keys from `env.json`.
2. Allow dormant stubs/docs (`BackendTokenCredentialProvider`, OpenAPI sketch) with
   **default off** and **no production DI wiring**.
3. Do **not** require `L3_BACKEND_URL` for release validation.

## Consequences

- Security score remains under client-key ceiling.
- Future versions may flip this ADR to Accepted and wire backend without redesigning L1/L2.

## Non-goals (v1.6.5)

- Deployed production proxy
- User-facing “use server analysis” toggle in release builds
- Failing CI when a backend is offline
