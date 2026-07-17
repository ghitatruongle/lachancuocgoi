#!/usr/bin/env bash
# Capture analyze + test count làm baseline cho bug hunt campaign.
# Output: docs/superpowers/baseline-{analyze,test,summary}.{txt,md}
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p docs/superpowers
echo "== dart analyze ==" >&2
dart analyze lib/ test/ > docs/superpowers/baseline-analyze.txt 2>&1 \
  || { echo "Analyze FAILED. Fix baseline before starting campaign." >&2; exit 1; }
echo "== flutter test (fast suite) ==" >&2
flutter test --exclude-tags perf > docs/superpowers/baseline-test.txt 2>&1 \
  || { echo "Test FAILED" >&2; exit 1; }
COUNT=$(grep -oE '[0-9]+ tests? passed|All tests passed!' docs/superpowers/baseline-test.txt | tail -1)
echo "Baseline test count: $COUNT" >&2
cat > docs/superpowers/baseline-summary.md <<EOF
## Baseline captured $(date '+%Y-%m-%d %H:%M')
- analyze: 0 issues
- test count: $COUNT
EOF
echo "Baseline captured. See docs/superpowers/baseline-summary.md" >&2