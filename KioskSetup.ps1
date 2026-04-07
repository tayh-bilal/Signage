# =========================================================
# FULL AUTOMATIC SIGNAGE KIOSK INSTALLER 
# (WITH AUTO-WIFI, MAC ADDRESS, ANYDESK & WEB APP)
# =========================================================

# =========================================================
# CONFIGURATION
# =========================================================
# If your Lovable app accepts API POST requests, put the URL here.
# Otherwise, the script will still attempt to send it, but you can just use the webpage!
$websiteApiUrl = "https://yourwebsite.com/api/register-screen"
# =========================================================

# 1. REQUIRE ADMIN PRIVILEGES
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: You must run this as Administrator!" -ForegroundColor Red
    Write-Host "Right-click the script and select 'Run with PowerShell', click Yes on the prompt." -ForegroundColor Yellow
    Pause
    Exit
}

Write-Host "Starting Kiosk Setup..." -ForegroundColor Green

# 2. CHECK INTERNET & AUTO-CONNECT WIFI
Write-Host "Checking internet connection..." -ForegroundColor Cyan
$connected = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction SilentlyContinue

if (-not $connected) {
    Write-Host "No internet detected. Attempting to connect to Wi-Fi..." -ForegroundColor Yellow
    $usbDrive = $PSScriptRoot
    $internetFile = "$usbDrive\internet.txt"
    
    if (-not (Test-Path $internetFile)) {
        Write-Host "internet.txt not found on USB." -ForegroundColor Yellow
        $wifiName = Read-Host "Please enter the Wi-Fi Network Name (SSID)"
        $wifiPass = Read-Host "Please enter the Wi-Fi Password"
        
        "$wifiName`n$wifiPass" | Out-File -FilePath $internetFile -Encoding utf8
        Write-Host "Saved your credentials to internet.txt on your USB for next time!" -ForegroundColor Green
    } else {
        Write-Host "Reading internet.txt from USB..." -ForegroundColor Cyan
        $wifiData = Get-Content $internetFile
        $wifiName = $wifiData[0].Trim()
        $wifiPass = $wifiData[1].Trim()
    }
    
    $xmlProfile = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$wifiName</name>
    <SSIDConfig>
        <SSID>
            <name>$wifiName</name>
        </SSID>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <MSM>
        <security>
            <authEncryption>
                <authentication>WPA2PSK</authentication>
                <encryption>AES</encryption>
                <useOneX>false</useOneX>
            </authEncryption>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>false</protected>
                <keyMaterial>$wifiPass</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
</WLANProfile>
"@
    $xmlPath = "$env:TEMP\wifi_profile.xml"
    $xmlProfile | Out-File -FilePath $xmlPath -Encoding utf8
    
    Write-Host "Adding Wi-Fi Profile..." -ForegroundColor Cyan
    netsh wlan add profile filename="$xmlPath" | Out-Null
    Start-Sleep -Seconds 1
    
    Write-Host "Connecting to $wifiName..." -ForegroundColor Cyan
    netsh wlan connect name="$wifiName" | Out-Null
    
    Write-Host "Waiting 10 seconds for connection to stabilize..." -ForegroundColor Cyan
    Start-Sleep -Seconds 10
    
    $connected = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction SilentlyContinue
    if (-not $connected) {
        Write-Host "CRITICAL ERROR: Failed to connect to the internet." -ForegroundColor Red
        Pause
        Exit
    } else {
        Write-Host "Successfully connected to Wi-Fi!" -ForegroundColor Green
    }
} else {
    Write-Host "Internet connection is already active." -ForegroundColor Green
}

# 3. SET POWER SETTINGS
Write-Host "Configuring Power Settings..." -ForegroundColor Cyan
powercfg /x -monitor-timeout-ac 0
powercfg /x -standby-timeout-ac 0

# 4. DISABLE NOTIFICATIONS
Write-Host "Disabling Windows Notifications..." -ForegroundColor Cyan
$pushPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
if (-not (Test-Path $pushPath)) { New-Item $pushPath -Force | Out-Null }
Set-ItemProperty -Path $pushPath -Name "ToastEnabled" -Value 0

# 5. DISABLE WINDOWS UPDATE AUTO-REBOOTS
Write-Host "Disabling Windows Update Interruptions..." -ForegroundColor Cyan
$wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
if (-not (Test-Path $wuPath)) { New-Item $wuPath -Force | Out-Null }
Set-ItemProperty -Path $wuPath -Name "NoAutoUpdate" -Value 1
Set-ItemProperty -Path $wuPath -Name "AUOptions" -Value 2

# 6. MUTE SYSTEM AUDIO
Write-Host "Muting System Audio..." -ForegroundColor Cyan
$wshShell = New-Object -ComObject WScript.Shell
for ($i=0; $i -lt 50; $i++) {
    $wshShell.SendKeys([char]174)
}

# 7. DOWNLOAD APP
Write-Host "Checking for app updates..." -ForegroundColor Cyan
$repo = "tayh-bilal/Signage"
$installFolder = "$env:LOCALAPPDATA\Programs\signage-player"
$installerPath = "$env:TEMP\SignagePlayerInstaller.exe"

try {
    $latestRelease = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest"
} catch {
    Write-Host "ERROR: Could not find any releases on GitHub." -ForegroundColor Red
    Pause
    Exit
}

$asset = $latestRelease.assets | Where-Object { $_.name -like "*.exe" } | Select-Object -First 1

if (-not $asset) { 
    Write-Host "CRITICAL ERROR: No .exe file found!" -ForegroundColor Red
    Pause
    Exit 
}

Write-Host "Downloading: $($asset.name)..." -ForegroundColor Cyan
Invoke-WebRequest $asset.browser_download_url -OutFile $installerPath

# 8. INSTALL APP
Write-Host "Installing App..." -ForegroundColor Cyan
Start-Process $installerPath -ArgumentList "/S /D=$installFolder" -Wait
Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

# 9. SET KIOSK MODE SHELL
$exePath = "$installFolder\SignagePlayer.exe"
if (Test-Path $exePath) {
    Write-Host "Locking Windows into Kiosk Mode (will activate on next restart)..." -ForegroundColor Yellow
    $shellPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System"
    if (-not (Test-Path $shellPath)) { New-Item -Path $shellPath -Force | Out-Null }
    Set-ItemProperty -Path $shellPath -Name "Shell" -Value $exePath
} else {
    Write-Host "Error: Installation finished but exe not found at $exePath" -ForegroundColor Red
    Pause
    Exit
}

# 10. GET MAC ADDRESS
$macInfo = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.MacAddress } | Select-Object -First 1
$cleanMac = if ($macInfo) { $macInfo.MacAddress.Replace("-", "") } else { "UNKNOWN" }

# 11. BROWSER SETUP & SYNC
Write-Host "======================================================" -ForegroundColor Green
Write-Host "             KIOSK CONFIGURATION COMPLETE             " -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host ""
Write-Host " >>> ACTIVE MAC ADDRESS: $cleanMac <<< " -BackgroundColor Black -ForegroundColor Magenta
Write-Host ""

Write-Host "Opening your Registration Website..." -ForegroundColor Cyan
Start-Process "https://preview--simple-video-booth.lovable.app/"

# Give the browser 2 seconds to open the first tab before launching the second
Start-Sleep -Seconds 2

Write-Host "Opening AnyDesk Download Page..." -ForegroundColor Cyan
Start-Process "https://anydesk.com/en/downloads/windows"

Write-Host ""
Write-Host "ALMOST DONE! PLEASE DO THIS NOW:" -ForegroundColor Yellow
Write-Host " 1. Install AnyDesk from the browser."
Write-Host " 2. Set up the unattended access password."
Write-Host " 3. Copy the 9-digit AnyDesk ID."
Write-Host " 4. Use the open web app tab to register the screen with the MAC Address and AnyDesk ID."
Write-Host ""

# Optional: Still ask employee for the ID in the console to push it via API, or you can remove this block if your Lovable app handles it entirely.
$anydeskId = Read-Host "ENTER THE NEW ANYDESK ID HERE (Or just press Enter to skip)"

if ($anydeskId) {
    Write-Host "Sending data to API..." -ForegroundColor Cyan
    $payload = @{
        MacAddress = $cleanMac
        AnyDeskId  = $anydeskId
    } | ConvertTo-Json

    try {
        Invoke-RestMethod -Uri $websiteApiUrl -Method Post -Body $payload -ContentType "application/json" | Out-Null
        Write-Host "Success! API updated." -ForegroundColor Green
    } catch {
        Write-Host "Warning: API update skipped or failed. Be sure to register it on the website." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Green
Write-Host "ALL DONE! MANUALLY RESTART THE COMPUTER TO ENTER KIOSK MODE." -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Pause