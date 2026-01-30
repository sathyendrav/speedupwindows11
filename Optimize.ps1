# Windows 11 Speed-Up & Debloat Script
# Run as Administrator

# 1. Create a System Restore Point for safety
Write-Host "Creating Restore Point..." -ForegroundColor Cyan
Checkpoint-Computer -Description "BeforeSpeedUp" -RestorePointType "MODIFY_SETTINGS"

# 2. Unlock Ultimate Performance Power Plan
Write-Host "Unlocking Ultimate Performance Plan..." -ForegroundColor Cyan
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61

# 3. Disable Transparency and Visual Effects (Optional - Best for Servers/Old Laptops)
# Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0

# 4. Privacy: Disable Telemetry and Data Collection
Write-Host "Disabling Telemetry..." -ForegroundColor Cyan
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0

# 5. Gaming: Enable Game Mode
Write-Host "Enabling Game Mode..." -ForegroundColor Cyan
Set-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1

# 6. Work: Disable unnecessary Taskbar icons (Widgets & Chat)
Write-Host "Cleaning Taskbar..." -ForegroundColor Cyan
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value 0

Write-Host "Optimization Complete. Please Restart your PC." -ForegroundColor Green