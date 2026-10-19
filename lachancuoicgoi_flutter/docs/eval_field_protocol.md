# Field metrics protocol (local only — v1.6.5)

## Purpose

Collect latency and fallback counters on-device for engineering review.
**No automatic upload to a first-party server in v1.6.5.**

## Consent

Any corpus built from real calls requires **explicit participant consent**
and must strip PII before storage. Prefer synthetic eval fixtures under
`test/fixtures/eval/`.

## Counters

See `lib/analysis/metrics/detection_metrics.dart`:

- L1/L2/L3 call counts
- L3 fallback / timeout counts
- L3 latency samples → p50

## Export

Developer mode may dump `DetectionMetrics.toJson()` to local logs only
after `SystemLogger.scrubForLogging`.
