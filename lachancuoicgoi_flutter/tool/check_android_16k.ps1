param(
  [Parameter(Mandatory = $true)]
  [string]$ApkPath
)

$ErrorActionPreference = 'Stop'
$resolvedApk = (Resolve-Path -LiteralPath $ApkPath).Path
$readElf = Get-Command llvm-readelf -ErrorAction SilentlyContinue
if (-not $readElf) {
  $sdkRoots = @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME) |
    Where-Object { $_ -and (Test-Path -LiteralPath $_) } |
    Select-Object -Unique
  foreach ($sdkRoot in $sdkRoots) {
    $ndkRoot = Join-Path $sdkRoot 'ndk'
    if (-not (Test-Path -LiteralPath $ndkRoot)) { continue }
    $candidate = Get-ChildItem -LiteralPath $ndkRoot -Recurse -File -Filter llvm-readelf.exe |
      Sort-Object FullName -Descending |
      Select-Object -First 1
    if ($candidate) {
      $readElf = $candidate
      break
    }
  }
}
if (-not $readElf) {
  throw 'llvm-readelf was not found; install Android NDK before the 16 KB release check.'
}
$readElfPath = if ($readElf.Source) { $readElf.Source } else { $readElf.FullName }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempBase ("lachancuocgoi-16k-" + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($tempRoot) | Out-Null
$resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
if (-not $resolvedTemp.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Refusing to use a temporary path outside the system temp directory.'
}

$archive = $null
try {
  $archive = [IO.Compression.ZipFile]::OpenRead($resolvedApk)
  $libraries = @($archive.Entries | Where-Object { $_.FullName -match '^lib/.+\.so$' })
  if ($libraries.Count -eq 0) { throw 'APK contains no native .so libraries.' }

  $failures = @()
  foreach ($entry in $libraries) {
    $safeName = ($entry.FullName -replace '[^A-Za-z0-9_.-]', '_')
    $destination = Join-Path $resolvedTemp $safeName
    [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destination, $true)
    $loadLines = @(& $readElfPath -lW $destination | Where-Object { $_ -match '^\s*LOAD\s' })
    if ($LASTEXITCODE -ne 0 -or $loadLines.Count -eq 0) {
      $failures += "$($entry.FullName): unreadable ELF program headers"
      continue
    }
    foreach ($line in $loadLines) {
      $parts = @($line.Trim() -split '\s+')
      $alignmentText = $parts[-1]
      try {
        $alignment = [Convert]::ToInt64(($alignmentText -replace '^0x', ''), 16)
      } catch {
        $failures += "$($entry.FullName): unknown LOAD alignment $alignmentText"
        continue
      }
      if ($alignment -lt 0x4000) {
        $failures += "$($entry.FullName): LOAD alignment $alignmentText is below 0x4000"
      }
    }
  }
  if ($failures.Count -gt 0) {
    throw "16 KB ELF check failed:`n$($failures -join "`n")"
  }
  Write-Host "16 KB ELF check passed for $($libraries.Count) native libraries."
} finally {
  if ($archive) { $archive.Dispose() }
  if (Test-Path -LiteralPath $resolvedTemp) {
    Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
  }
}
