# Capture analyze + test count làm baseline cho bug hunt campaign.
# Output: docs/superpowers/baseline-{analyze,test,summary}.{txt,md}
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

if (-not (Test-Path 'docs/superpowers')) {
  New-Item -ItemType Directory -Path 'docs/superpowers' | Out-Null
}

Write-Host '== dart analyze ==' -ForegroundColor Cyan
& dart analyze lib/ test/ 2>&1 | Out-File -Encoding utf8 docs/superpowers/baseline-analyze.txt
if ($LASTEXITCODE -ne 0) {
  Write-Host 'Analyze FAILED. Fix baseline before starting campaign.' -ForegroundColor Red
  exit 1
}

Write-Host '== flutter test (fast suite) ==' -ForegroundColor Cyan
$testOut = & flutter test --exclude-tags perf --reporter expanded 2>&1
$testOut | Out-File -Encoding utf8 docs/superpowers/baseline-test.txt

$passedLine = ($testOut | Select-String -Pattern 'All tests passed!|\+[0-9]+ -[0-9]+|All tests? passed' | Select-Object -Last 1)
$count = if ($passedLine) { $passedLine.Line.Trim() } else { 'unknown' }

Write-Host "Baseline test count: $count" -ForegroundColor Green
@"
## Baseline captured $(Get-Date -Format 'yyyy-MM-dd HH:mm')
- analyze: 0 issues
- test count: $count
"@ | Out-File -Encoding utf8 docs/superpowers/baseline-summary.md

Write-Host 'Baseline captured. See docs/superpowers/baseline-summary.md' -ForegroundColor Green