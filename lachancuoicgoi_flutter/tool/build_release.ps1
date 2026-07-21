param(
  [switch]$SkipApk,
  [switch]$SkipBundle
)

$ErrorActionPreference = 'Stop'

function Find-AndroidSdkTool {
  param([Parameter(Mandatory = $true)][string]$Name)

  $onPath = Get-Command $Name -ErrorAction SilentlyContinue
  if ($onPath) { return $onPath.Source }

  $localProperties = Join-Path $projectRoot 'android\local.properties'
  $localSdk = if (Test-Path -LiteralPath $localProperties) {
    (Get-Content -LiteralPath $localProperties |
      Where-Object { $_ -match '^sdk\.dir=' } |
      Select-Object -First 1) -replace '^sdk\.dir=', '' -replace '\\\\', '\'
  }
  $sdkRoots = @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME, $localSdk) |
    Where-Object { $_ -and (Test-Path -LiteralPath $_) } |
    Select-Object -Unique
  foreach ($sdkRoot in $sdkRoots) {
    $buildToolsRoot = Join-Path $sdkRoot 'build-tools'
    if (-not (Test-Path -LiteralPath $buildToolsRoot)) { continue }
    $candidate = Get-ChildItem -LiteralPath $buildToolsRoot -Directory |
      Sort-Object Name -Descending |
      ForEach-Object {
      foreach ($extension in @('.exe', '.bat')) {
        $toolPath = Join-Path $_.FullName "$Name$extension"
        if (Test-Path -LiteralPath $toolPath) { Get-Item -LiteralPath $toolPath }
      }
      } |
      Select-Object -First 1
    if ($candidate) { return $candidate.FullName }
  }
  throw "$Name was not found in PATH or Android SDK Build Tools."
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$releaseName = 'v1.6.1+15'
$releaseRoot = Join-Path $projectRoot "build\release\$releaseName"
$dartSymbols = Join-Path $releaseRoot 'dart-symbols'

Push-Location $projectRoot
try {
  dart run tool/verify_release_version.dart
  if ($LASTEXITCODE -ne 0) { throw 'Release version verification failed.' }

  dart run tool/validate_release_env.dart env.json
  if ($LASTEXITCODE -ne 0) { throw 'Release env validation failed.' }

  flutter pub get --enforce-lockfile
  if ($LASTEXITCODE -ne 0) { throw 'Locked dependency restore failed.' }

  if (-not $SkipBundle) {
    flutter build appbundle --release --obfuscate --split-debug-info=$dartSymbols
    if ($LASTEXITCODE -ne 0) { throw 'AAB build failed.' }
  }

  if (-not $SkipApk) {
    flutter build apk --release --obfuscate --split-debug-info=$dartSymbols
    if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
  }

  $aab = Join-Path $projectRoot 'build\app\outputs\bundle\release\app-release.aab'
  $apk = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-release.apk'
  if (-not $SkipBundle -and -not (Test-Path -LiteralPath $aab)) {
    throw 'AAB build reported success but app-release.aab was not found.'
  }
  if (-not $SkipApk -and -not (Test-Path -LiteralPath $apk)) {
    throw 'APK build reported success but app-release.apk was not found.'
  }
  $baselineAabBytes = 127984341
  if ((-not $SkipBundle) -and (Test-Path -LiteralPath $aab) -and
      ((Get-Item -LiteralPath $aab).Length -gt $baselineAabBytes)) {
    throw "AAB exceeds baseline $baselineAabBytes bytes: $((Get-Item -LiteralPath $aab).Length) bytes."
  }

  if (-not $SkipApk -and (Test-Path -LiteralPath $apk)) {
    $zipalign = Find-AndroidSdkTool 'zipalign'
    & $zipalign -c -P 16 4 $apk
    if ($LASTEXITCODE -ne 0) { throw 'APK failed 16 KB zip alignment verification.' }
  }

  if (-not $SkipApk -and (Test-Path -LiteralPath $apk)) {
    & (Join-Path $PSScriptRoot 'check_android_16k.ps1') -ApkPath $apk
    if ($LASTEXITCODE -ne 0) { throw 'Native ELF 16 KB verification failed.' }

    $aapt = Find-AndroidSdkTool 'aapt'
    $badging = (& $aapt dump badging $apk | Select-Object -First 1)
    if ($badging -notmatch "versionCode='15'" -or
        $badging -notmatch "versionName='1.6.1'") {
      throw "APK version verification failed: $badging"
    }

    $apksigner = Find-AndroidSdkTool 'apksigner'
    & $apksigner verify --verbose --print-certs $apk
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
  }

  if (-not $SkipBundle -and (Test-Path -LiteralPath $aab)) {
    jarsigner -verify $aab | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'AAB signature verification failed.' }
  }

  $mapping = Join-Path $projectRoot 'build\app\outputs\mapping\release\mapping.txt'
  if ((-not $SkipApk -or -not $SkipBundle) -and
      -not (Test-Path -LiteralPath $mapping)) {
    throw 'R8 mapping.txt was not generated.'
  }

  Write-Host "Release artifacts built locally for $releaseName. Nothing was uploaded."
  Write-Host "AAB: $aab"
  Write-Host "APK: $apk"
  Write-Host "Dart symbols: $dartSymbols"
  Write-Host "R8 mapping: $mapping"
  Write-Host 'Before Play upload, set PLAY_VERSION_CODE_ALREADY_USED=true if code 15 is already used; the verifier will stop.'
} finally {
  Pop-Location
}
