<#
CI-ready test runner for the lachancuocgoi_flutter project (PowerShell).

Performs:
  1. `dart analyze lib/ test/`
  2. `flutter test --exclude-tags perf`     (fast suite for PRs)
  3. `flutter test --tags perf`              (slow benchmarks, only when
                                              $env:RUN_PERF = "1")
  4. Prints a pass/fail summary table.

Exits non-zero on the first failing required step.
#>

[CmdletBinding()]
param(
    [switch]$IncludePerf
)

$ErrorActionPreference = 'Continue'
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $ProjectRoot

$summary = New-Object System.Collections.Generic.List[object]

function Invoke-TestStep {
    param(
        [string]$Title,
        [string]$CommandLine
    )
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "▶ $Title"
    Write-Host "============================================================"
    Write-Host "  $CommandLine"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    cmd /c $CommandLine | Out-Host
    $rc = $LASTEXITCODE
    $sw.Stop()
    $status = if ($rc -eq 0) { 'PASS' } else { 'FAIL' }
    $details = "exit=$rc elapsed=$([math]::Round($sw.Elapsed.TotalSeconds, 1))s"
    $script:summary.Add([pscustomobject]@{
        Step    = $Title
        Result  = $status
        Details = $details
    }) | Out-Null
    return $rc
}

# ── 1. Static analysis ──────────────────────────────────────────────
$analyzeRc = Invoke-TestStep -Title 'dart analyze lib/ test/' `
    -CommandLine 'dart analyze lib/ test/'

# ── 2. Fast test suite (excludes perf benchmarks) ──────────────────
$fastRc = Invoke-TestStep -Title 'flutter test --exclude-tags perf' `
    -CommandLine 'flutter test --exclude-tags perf'

# ── 3. Slow perf suite (only if requested) ─────────────────────────
$perfRc = 0
if ($IncludePerf -or $env:RUN_PERF -eq '1') {
    $perfRc = Invoke-TestStep -Title 'flutter test --tags perf' `
        -CommandLine 'flutter test --tags perf'
} else {
    $script:summary.Add([pscustomobject]@{
        Step    = 'flutter test --tags perf'
        Result  = 'SKIP'
        Details = 'set -IncludePerf or $env:RUN_PERF=1 to enable'
    }) | Out-Null
}

# ── 4. Summary table ───────────────────────────────────────────────
Write-Host ""
Write-Host "============================================================"
Write-Host "  TEST SUMMARY"
Write-Host "============================================================"
$summary | Format-Table -AutoSize | Out-String | Write-Host

# Aggregate exit code.
$overall = 0
if ($analyzeRc -ne 0) { $overall = 1 }
if ($fastRc    -ne 0) { $overall = 1 }
if ($IncludePerf -or $env:RUN_PERF -eq '1') {
    if ($perfRc -ne 0) { $overall = 1 }
}

Write-Host ""
if ($overall -eq 0) {
    Write-Host "[OK]  All required steps passed."
    exit 0
} else {
    Write-Host "[FAIL] One or more required steps failed."
    exit 1
}
