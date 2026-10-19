# ADR-005: Adaptive Timeout for L3 Cloud AI & Safety Filter Consolidation

## Status

Accepted

## Context

In v1.6.1 of La Chan Cuoc Goi:
1. **L3 Cloud Timeout Strategy:** `AnalysisCoordinator._analyzeParallel` applied a static 800ms timeout for L3 (Gemini AI) requests. On unstable 3G/LTE mobile networks, physical Round-Trip Time (RTT) often exceeds 800ms, triggering false-positive L3 fallbacks even when Gemini API responds correctly shortly after.
2. **Redundant Safety Evaluations:** Safety filtering (negative-lookahead, safe context, family terms, question patterns) was evaluated separately in L1 (`L1SafetyFilter`) and L2 (`L2SafetyFilter`), leading to redundant text normalization passes over identical transcript tokens.

## Decision

### 1. Adaptive RTT-Based Timeout for L3 Gemini

Instead of a static 800ms timeout, implement an **Adaptive Timeout Calculator**:
- Track exponential moving average (EMA) of recent successful Gemini response latencies ($RTT_{avg}$).
- Set dynamic L3 timeout:
  $$\text{Timeout}_{L3} = \text{clamp}(RTT_{avg} \times 1.5 + 200\text{ms}, 600\text{ms}, 2500\text{ms})$$
- Default initial fallback timeout starts at 1000ms until enough network samples are collected.

### 2. Consolidated Safety Filter Evaluation

- Normalize and pre-calculate safety context tokens once during L1 execution.
- Pass safety evaluation context metadata to L2 to prevent duplicate regex matching and string normalization.

## Consequences

**Positive:**
- Substantially reduces false fallback rates on poor or high-latency mobile networks.
- Saves CPU cycles and garbage collection overhead by eliminating redundant string normalizations across L1 and L2.
- Improves evaluation score for Engine Phân Tích Đa Tầng.

**Negative:**
- Marginally increases L3 wait time when network is slow before falling back to L1+L2 offline results.

## References

- `lib/analysis/l3/l3_analysis.dart`
- `lib/analysis/l1/l1_safety_filter.dart`
- `docs/adr/002-three-tier-analysis-pipeline.md`
