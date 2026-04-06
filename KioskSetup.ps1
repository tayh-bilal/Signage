# =========================================================
# FULL AUTOMATIC SIGNAGE KIOSK INSTALLER
# =========================================================

# 1. REQUIRE ADMIN PRIVILEGES
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: You must run this as Administrator!" -ForegroundColor Red
    Write-Host "Right-click the Start Menu -> Windows PowerShell (Admin) -> Run the script from there." -ForegroundColor Yellow
    Pause
    Exit
}

Write-Host "Starting Kiosk Setup..." -ForegroundColor Green

# 2. SET POWER SETTINGS (Never Sleep)
Write-Host "Configuring Power Settings..." -ForegroundColor Cyan
powercfg /x -monitor-timeout-ac 0
powercfg /x -standby-timeout-ac 0

# 3. DISABLE NOTIFICATIONS (No popups)
Write-Host "Disabling Windows Notifications..." -ForegroundColor Cyan
$pushPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
if (-not (Test-Path $pushPath)) { New-Item $pushPath -Force | Out-Null }
Set-ItemProperty -Path $pushPath -Name "ToastEnabled" -Value 0

# 4. DISABLE WINDOWS UPDATE AUTO-REBOOTS
Write-Host "Disabling Windows Update Interruptions..." -ForegroundColor Cyan
$wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
if (-not (Test-Path $wuPath)) { New-Item $wuPath -Force | Out-Null }
Set-ItemProperty -Path $wuPath -Name "NoAutoUpdate" -Value 1
Set-ItemProperty -Path $wuPath -Name "AUOptions" -Value 2

# 5. DOWNLOAD APP FROM GITHUB
Write-Host "Checking for app updates..." -ForegroundColor Cyan
$repo = "tayh-bilal/Signage"
$installFolder = "$env:LOCALAPPDATA\Programs\signage-player"
$installerPath = "$env:TEMP\SignagePlayerInstaller.exe"

try {
    $latestRelease = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest"
} catch {
    Write-Host "ERROR: Could not find any releases on GitHub. Is the repo public?" -ForegroundColor Red
    Pause
    Exit
}

Write-Host "Found Version: $($latestRelease.tag_name)" -ForegroundColor Green

$asset = $latestRelease.assets | Where-Object { $_.name -like "*.exe" } | Select-Object -First 1

if (-not $asset) { 
    Write-Host "CRITICAL ERROR: No .exe file found in release $($latestRelease.tag_name)!" -ForegroundColor Red
    Pause
    Exit 
}

Write-Host "Downloading: $($asset.name)..." -ForegroundColor Cyan
Invoke-WebRequest $asset.browser_download_url -OutFile $installerPath

# 6. INSTALL APP
Write-Host "Installing App..." -ForegroundColor Cyan
Start-Process $installerPath -ArgumentList "/S /D=$installFolder" -Wait

# Cleanup Installer
Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

# 7. RUN KIOSK MODE
$exePath = "$installFolder\SignagePlayer.exe"

if (Test-Path $exePath) {
    Write-Host "Locking Windows into Kiosk Mode..." -ForegroundColor Yellow
    
    # Check if the Registry folder exists, if not, create it
    $shellPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System"
    if (-not (Test-Path $shellPath)) { New-Item -Path $shellPath -Force | Out-Null }
    
    # Set the App as the Windows Shell
    Set-ItemProperty -Path $shellPath -Name "Shell" -Value $exePath
    
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "INSTALL COMPLETE! RESTARTING IN 5 SECONDS" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    Start-Sleep -Seconds 5
    Restart-Computer
} else {
    Write-Host "Error: Installation finished but exe not found at $exePath" -ForegroundColor Red
    Pause
}