# ADR-002: Three-Tier Scam Detection Pipeline

## Status

Accepted

## Context

The core feature of La Chan Cuoc Goi is real-time scam call detection. Requirements:
- **Low latency:** Detect scams within milliseconds during live calls
- **High accuracy:** Minimize false positives (annoying users) and false negatives (missing scams)
- **Offline capability:** Work without internet connection
- **Privacy:** Process sensitive call data on-device when possible
- **Scalability:** Support evolving scam patterns without app updates

Single-tier approaches have limitations:
- **Keyword-only (L1):** Fast but high false positive rate
- **ML-only (L2):** Better accuracy but slower, requires model loading
- **Cloud-only (L3):** Most accurate but privacy concerns, latency, connectivity dependency

## Decision

Implement a **three-tier cascading pipeline** with parallel execution and graceful degradation:

```
┌─────────────────────────────────────────────────────────────┐
│                    Real-Time Transcript                      │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
     ┌──────────────┐                ┌──────────────┐
     │    L1        │                │    L2        │
     │  Keyword     │   Parallel     │   On-Device  │
     │  Matching    │ ───────────►   │     AI       │
     │  <1ms        │                │  50-200ms    │
     └──────┬───────┘                └──────┬───────┘
            │                                │
            └───────────────┬────────────────┘
                            ▼
              ┌─────────────────────────┐
              │      Fast-Track?        │
              │  L1=RED or L2=ORANGE+?  │
              └────────┬────────────────┘
                       │
              Yes ─────┴──────────── No
                       │                │
                       ▼                ▼
              ┌──────────────┐   ┌──────────────┐
              │   RESULT     │   │    L3        │
              │  (No cloud)  │   │  Cloud AI    │
              │              │   │  1-5s        │
              └──────────────┘   └──────┬───────┘
                                        ▼
                                 ┌──────────────┐
                                 │   RESULT     │
                                 └──────────────┘
```

### Tier Details

**L1 — Keyword Matching (Aho-Corasick)**
- Technique: Flat-array trie with bigram corrections, 6-rule negative lookahead
- Latency: <1ms
- Purpose: Immediate red-flag detection for known scam keywords
- Fallback: Trie fallback if vocabulary fails to load

**L2 — On-Device AI (TFLite + GDetection)**
- Technique: BERT intent classifier (Isolate) + scenario matching + WFSA state machine
- Latency: 50-200ms
- Purpose: Contextual analysis, scam pattern recognition
- Fallback: Intent-disabled mode if TFLite unavailable

**L3 — Cloud AI (Gemini API)**
- Technique: LLM analysis with PII stripping, circuit breaker, multi-key rotation
- Latency: 1-5s
- Purpose: Deep contextual analysis, summarization, edge cases
- Fallback: L2 result if cloud fails or consent not given

### Execution Strategy

1. **Parallel mode:** Run L1 + L2 concurrently
2. **Adaptive timeout:** L3 timeout calibrated by EMA RTT measurement (alpha=0.3)
3. **Fast-track:** Skip L3 if L1=RED or L2=ORANGE+ (high confidence)
4. **Graceful degradation:** Each tier has fallback to lower tier

### Privacy Model

```
Audio → Vosk STT (local) → Transcript
                         ↓
              L1/L2 Analysis (local, always)
                         ↓
              PII Stripping (local)
                         ↓
              L3 Cloud Analysis (only with explicit consent)
```

## Rationale

This architecture balances:
- **Speed:** L1 provides instant feedback for obvious scams
- **Accuracy:** L2/L3 catch nuanced patterns keywords miss
- **Privacy:** Offline processing by default, cloud only with consent
- **Reliability:** Works without internet, degrades gracefully
- **User trust:** Transparent about what data goes where

## Consequences

**Positive:**
- Detection accuracy significantly higher than single-tier
- Average latency under 200ms for 90% of calls (fast-track)
- Privacy-preserving by default
- Resilient to cloud service outages
- Extensible: new L2 scenarios or L3 prompts can be added without app update

**Negative:**
- Increased code complexity (3 analyzers + coordinator + orchestrator)
- Higher memory usage (multiple models loaded)
- More test cases required (~1,600 tests in current suite)
- L3 costs money (mitigated by quota limits and circuit breaker)

**Mitigations:**
- Clear separation of concerns (pure Dart analysis engine)
- Comprehensive eval corpus (300 cases, precision/recall ≥90%)
- Circuit breaker prevents runaway L3 calls
- Coverage baseline gate (76.62%) ensures quality

## References

- `lib/analysis/analysis_coordinator.dart` — Pipeline orchestration
- `lib/analysis/l1/` — Aho-Corasick implementation
- `lib/analysis/l2/` — TFLite + GDetection
- `lib/analysis/l3/` — Gemini API integration
- `docs/eval_corpus_readme.md` — Evaluation methodology
