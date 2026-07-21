# Target device serial
$Serial = "fc2407a4"
$AdbPath = "C:\Users\Acer\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$DesktopDir = "C:\Users\Acer\Desktop"

if (-not (Test-Path $AdbPath)) {
    if (Get-Command adb -ErrorAction SilentlyContinue) {
        $AdbPath = "adb"
    } else {
        Write-Error "adb.exe not found. Please install Android SDK Platform Tools."
        Exit
    }
}

# Check if device is connected
$State = & $AdbPath -s $Serial get-state 2>$null
if ($State -ne "device") {
    Write-Error "Device $Serial is not connected or unauthorized."
    Exit
}

# Get screen size
$SizeOutput = & $AdbPath -s $Serial shell wm size
if ($SizeOutput -match "(\d+x\d+)") {
    $Resolution = $Matches[1]
} else {
    $Resolution = "720x1480"
}

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Android Screen Recorder (PowerShell)" -ForegroundColor Cyan
Write-Host "Device: Samsung SM-J610F ($Serial)" -ForegroundColor Cyan
Write-Host "Resolution: $Resolution (Highest)" -ForegroundColor Cyan
Write-Host "Save location: $DesktopDir" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Starting recording..." -ForegroundColor Green
Write-Host "Press [Ctrl + C] to STOP and SAVE the video." -ForegroundColor Yellow
Write-Host "===============================================" -ForegroundColor Cyan

$TempFile = "/sdcard/temp_recording.mp4"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$OutputFile = Join-Path $DesktopDir "record_$Timestamp.mp4"

# Start screenrecord process
$ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
$ProcessInfo.FileName = $AdbPath
$ProcessInfo.Arguments = "-s $Serial shell screenrecord --size $Resolution --bit-rate 8000000 $TempFile"
$ProcessInfo.UseShellExecute = $false
$ProcessInfo.CreateNoWindow = $true
$Process = [System.Diagnostics.Process]::Start($ProcessInfo)

# Wait for Ctrl+C or process exit
try {
    while (-not $Process.HasExited) {
        Start-Sleep -Milliseconds 500
    }
} finally {
    if (-not $Process.HasExited) {
        Write-Host "`nStopping recording..." -ForegroundColor Yellow
        $Process.Kill()
        # Wait a moment for device to finalize file
        Start-Sleep -Seconds 2
    }
    
    Write-Host "Downloading video to Desktop..." -ForegroundColor Green
    & $AdbPath -s $Serial pull $TempFile $OutputFile
    
    if (Test-Path $OutputFile) {
        Write-Host "Success! Video saved to: $OutputFile" -ForegroundColor Green
        Write-Host "Cleaning up temporary file on device..." -ForegroundColor Gray
        & $AdbPath -s $Serial shell rm $TempFile
    } else {
        Write-Host "Error: Failed to download the video." -ForegroundColor Red
    }
}
