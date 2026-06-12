#!/usr/bin/env bash
#
# CI-ready test runner for the lachancuocgoi_flutter project.
#
# Performs:
#   1. `dart analyze lib/ test/`
#   2. `flutter test --exclude-tags perf`     (fast suite for PRs)
#   3. `flutter test --tags perf`              (slow benchmarks)
#   4. Prints a pass/fail summary table.
#
# Exits non-zero on the first failing step.

set -u  # Treat unset variables as errors.
# NOTE: `set -e` is intentionally omitted so we can run all three
# stages and report each result independently. We check each exit
# code explicitly.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Use python3 for portable arithmetic (macOS/Linux/CI containers).
summary_rows=()

record() {
  local step="$1"
  local status="$2"
  local details="$3"
  summary_rows+=("$step | $status | $details")
}

run_step() {
  local title="$1"
  shift
  echo
  echo "============================================================"
  echo "▶ $title"
  echo "============================================================"
  "$@"
  local rc=$?
  if [ $rc -eq 0 ]; then
    record "$title" "PASS" "exit 0"
  else
    record "$title" "FAIL" "exit $rc"
  fi
  return $rc
}

# ── 1. Static analysis ────────────────────────────────────────────────
run_step "dart analyze lib/ test/" dart analyze lib/ test/ \
  && ANALYZE_OK=1 || ANALYZE_OK=0

# ── 2. Fast test suite (excludes perf benchmarks) ───────────────────
run_step "flutter test --exclude-tags perf" \
  flutter test --exclude-tags perf \
  && FAST_OK=1 || FAST_OK=0

# ── 3. Slow perf suite (only if requested) ───────────────────────────
PERF_OK=1
PERF_DETAILS="skipped (set RUN_PERF=1 to enable)"
if [ "${RUN_PERF:-0}" = "1" ]; then
  run_step "flutter test --tags perf" \
    flutter test --tags perf \
    && PERF_OK=1 || PERF_OK=0
  PERF_DETAILS="ran"
fi
record "flutter test --tags perf" "SKIP/PASS" "$PERF_DETAILS"

# ── 4. Summary ───────────────────────────────────────────────────────
echo
echo "============================================================"
echo "  TEST SUMMARY"
echo "============================================================"
printf "%-44s | %-6s | %s\n" "STEP" "RESULT" "DETAILS"
printf -- "---------------------------------------------+--------+----------------\n"
for row in "${summary_rows[@]}"; do
  IFS='|' read -r step status details <<< "$row"
  printf "%-44s | %-6s | %s\n" "$(echo "$step" | sed 's/ *$//')" \
    "$(echo "$status" | sed 's/ *$//')" "$(echo "$details" | sed 's/^ *//')"
done

# Aggregate exit code: fail if any required step failed.
OVERALL=0
if [ "${ANALYZE_OK:-0}" -ne 1 ]; then OVERALL=1; fi
if [ "${FAST_OK:-0}"    -ne 1 ]; then OVERALL=1; fi
if [ "${RUN_PERF:-0}" = "1" ] && [ "${PERF_OK:-0}" -ne 1 ]; then OVERALL=1; fi

echo
if [ "$OVERALL" -eq 0 ]; then
  echo "✅  All required steps passed."
  exit 0
else
  echo "❌  One or more required steps failed."
  exit 1
fi
