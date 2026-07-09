<#
Script to run all integration tests on a connected device using flutter drive in profile mode.
#>

[CmdletBinding()]
param(
    [string]$DeviceId = "fc2407a4"
)

$ErrorActionPreference = 'Continue'
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $ProjectRoot

$tests = @(
    "integration_test/stt_fallback_banner_test.dart",
    "integration_test/history_reactive_test.dart",
    "integration_test/monitoring_flow_test.dart",
    "integration_test/permission_flow_test.dart",
    "integration_test/session_recovery_test.dart"
)

$summary = New-Object System.Collections.Generic.List[object]

Write-Host "============================================================"
Write-Host "STARTING INTEGRATION TESTS ON DEVICE: $DeviceId"
Write-Host "============================================================"

$overallSuccess = $true

foreach ($test in $tests) {
    $testName = [System.IO.Path]::GetFileName($test)
    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "Running: $testName"
    Write-Host "------------------------------------------------------------"
    
    $cmd = "flutter drive --driver=test_driver/integration_test.dart --target=$test -d $DeviceId --profile"
    Write-Host "Command: $cmd"
    
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    cmd /c $cmd | Out-Host
    $rc = $LASTEXITCODE
    $sw.Stop()
    
    $status = if ($rc -eq 0) { 'PASS' } else { 'FAIL' }
    if ($rc -ne 0) {
        $overallSuccess = $false
    }
    
    $details = "exit=$rc elapsed=$([math]::Round($sw.Elapsed.TotalSeconds, 1))s"
    $summary.Add([pscustomobject]@{
        Test    = $testName
        Result  = $status
        Details = $details
    }) | Out-Null
}

Write-Host ""
Write-Host "============================================================"
Write-Host "INTEGRATION TEST SUMMARY"
Write-Host "============================================================"
$summary | Format-Table -AutoSize | Out-String | Write-Host

if ($overallSuccess) {
    Write-Host "[OK] All integration tests passed!"
    exit 0
} else {
    Write-Host "[FAIL] One or more integration tests failed."
    exit 1
}
