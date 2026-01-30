<#
.SYNOPSIS
Speed up Windows 11 by disabling unnecessary features.
Choose profile: Laptop, Desktop, Gaming, Work, Server.

.NOTES
⚠️ Always create a System Restore Point before running.
Undo commands are included for restoring defaults.
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Laptop","Desktop","Gaming","Work","Server")]
    [string]$Profile
)

function Disable-ServiceSafe($serviceName) {
    Write-Host "Disabling service: $serviceName"
    sc stop $serviceName
    sc config $serviceName start=disabled
}

function Enable-ServiceSafe($serviceName) {
    Write-Host "Restoring service: $serviceName"
    sc config $serviceName start=auto
}

switch ($Profile) {
    "Laptop" {
        # Disable transparency
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f
        # Remove Bing apps
        Get-AppxPackage *bing* | Remove-AppxPackage
    }

    "Desktop" {
        # Disable Cortana
        Get-AppxPackage *cortana* | Remove-AppxPackage
        # Disable Widgets
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 0 /f
        # Disable Telemetry
        Disable-ServiceSafe "DiagTrack"
    }

    "Gaming" {
        # Disable Xbox Game Bar
        Get-AppxPackage Microsoft.XboxGamingOverlay | Remove-AppxPackage
        # Disable DVR
        reg add "HKCU\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 0 /f
        # Disable SysMain
        Disable-ServiceSafe "SysMain"
    }

    "Work" {
        # Remove consumer apps
        Get-AppxPackage *xbox* | Remove-AppxPackage
        # Disable notifications
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications" /v ToastEnabled /t REG_DWORD /d 0 /f
        # Disable Widgets
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 0 /f
    }

    "Server" {
        # Disable Print Spooler
        Disable-ServiceSafe "spooler"
        # Disable Windows Search
        Disable-ServiceSafe "WSearch"
        # Disable GUI effects
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f
    }
}

Write-Host "Optimization for $Profile applied successfully!"
