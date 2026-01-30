<#
.SYNOPSIS
  Applies a safe(ish) set of Windows 11 performance tweaks with per-device profiles.

.DESCRIPTION
  Menu-driven (optional) Windows 11 optimization script that supports:
  - Profiles: Laptop, Work, Gaming
  - Feature selection
  - -WhatIf (dry run) via SupportsShouldProcess
  - -Revert using per-run state captured to a timestamped backup folder

  Guard rails:
  - Does NOT disable Windows Defender or Windows Update.
  - Uses per-feature state capture so changes can be reverted.

  Backups/logs are written under the backup root (default: C:\OptimizeBackup),
  inside a per-run folder like: C:\OptimizeBackup\2026-01-30_153012\

  Optional additions:
  - -CreateRestorePoint: attempts to create a Windows restore point before applying.
  - SystemSnapshot feature: writes snapshot-before.json and snapshot-after.json for easy comparison.
  - DeliveryOptimization feature: disables peer-to-peer update delivery (keeps normal downloads).
  - FastStartup feature: disables Fast Startup (helpful for troubleshooting driver wake/boot issues).
  - QuietMode feature: reduces interruptions by disabling toast notifications (gaming-focused).

.PARAMETER Profile
  Device profile. A profile mainly selects sensible defaults for feature targets.

.PARAMETER Features
  Features to apply. If omitted and -Interactive is not used, defaults are chosen by Profile.

.PARAMETER Interactive
  Launches a simple prompt flow for selecting Profile and Features.

.PARAMETER Revert
  Reverts changes from a previous run.

.PARAMETER BackupPath
  Specific run folder to revert from (e.g., C:\OptimizeBackup\2026-01-30_153012).
  If omitted in -Revert mode, the most recent run folder under -BackupRoot is used.

.PARAMETER BackupRoot
  Root folder for backups/logs. Default: C:\OptimizeBackup

.PARAMETER Force
  Allows applying more aggressive settings where applicable. Currently unused for risky areas;
  reserved for future expansion.

.PARAMETER CreateRestorePoint
  Attempts to create a Windows restore point before applying changes. This may fail if System
  Protection is disabled; failures are logged as warnings.

.EXAMPLE
  # Interactive apply
  .\Optimize-Windows11.ps1 -Interactive

.EXAMPLE
  # Apply Gaming defaults (non-interactive) and preview actions
  .\Optimize-Windows11.ps1 -Profile Gaming -WhatIf

.EXAMPLE
  # Apply specific features for Work profile
  .\Optimize-Windows11.ps1 -Profile Work -Features Widgets,Chat,CopilotButton,VisualEffects,GameDVR

.EXAMPLE
  # Gaming profile with quiet mode and delivery optimization
  .\Optimize-Windows11.ps1 -Profile Gaming -Features DeliveryOptimization,QuietMode -WhatIf

.EXAMPLE
  # Revert the most recent run
  .\Optimize-Windows11.ps1 -Revert

.EXAMPLE
  # Revert a specific run
  .\Optimize-Windows11.ps1 -Revert -BackupPath C:\OptimizeBackup\2026-01-30_153012
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
  [Parameter()]
  [ValidateSet('Laptop', 'Work', 'Gaming')]
  [string]$Profile,

  [Parameter()]
  [ValidateSet('Widgets', 'Chat', 'CopilotButton', 'VisualEffects', 'GameDVR', 'PowerPlan', 'SearchIndexing', 'StartupAppsReport', 'SystemSnapshot', 'DeliveryOptimization', 'FastStartup', 'QuietMode')]
  [string[]]$Features,

  [Parameter()]
  [switch]$Interactive,

  [Parameter()]
  [switch]$Revert,

  [Parameter()]
  [string]$BackupPath,

  [Parameter()]
  [string]$BackupRoot = 'C:\OptimizeBackup',

  [Parameter()]
  [switch]$CreateRestorePoint,

  [Parameter()]
  [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-IsAdministrator {
  $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function New-RunId {
  return (Get-Date).ToString('yyyy-MM-dd_HHmmss')
}

function Ensure-Directory {
  param([Parameter(Mandatory)] [string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Write-Log {
  param(
    [Parameter(Mandatory)] [string]$Message,
    [ValidateSet('INFO', 'WARN', 'ERROR')]
    [string]$Level = 'INFO'
  )
  $ts = (Get-Date).ToString('s')
  Write-Host "[$ts] [$Level] $Message"
}

function Get-OsBuildNumber {
  try {
    return [Environment]::OSVersion.Version.Build
  } catch {
    return $null
  }
}

function Try-CreateRestorePoint {
  param(
    [Parameter(Mandatory)] [string]$Description
  )

  if (-not (Get-Command -Name Checkpoint-Computer -ErrorAction SilentlyContinue)) {
    Write-Log -Level 'WARN' -Message 'Checkpoint-Computer not available; cannot create restore point.'
    return
  }

  try {
    if ($PSCmdlet.ShouldProcess('System Restore', "Create restore point: $Description")) {
      Checkpoint-Computer -Description $Description -RestorePointType 'MODIFY_SETTINGS' | Out-Null
      Write-Log -Message 'Restore point created.'
    }
  } catch {
    Write-Log -Level 'WARN' -Message ("Restore point creation failed: {0}" -f $_.Exception.Message)
  }
}

function Get-SystemSnapshot {
  param(
    [Parameter(Mandatory)] [string]$Profile,
    [Parameter(Mandatory)] [string[]]$Features
  )

  $build = Get-OsBuildNumber
  $powerGuid = Get-ActivePowerSchemeGuid
  $wsearch = Get-Service -Name 'WSearch' -ErrorAction SilentlyContinue

  return [pscustomobject]@{
    CapturedAt = (Get-Date).ToString('s')
    Computer   = $env:COMPUTERNAME
    User       = $env:USERNAME
    OsBuild    = $build
    Profile    = $Profile
    Features   = $Features
    PowerPlan  = [pscustomobject]@{ ActiveGuid = $powerGuid }
    Services   = [pscustomobject]@{
      WSearch = if ($null -ne $wsearch) { [string]$wsearch.Status } else { 'Missing' }
    }
    Registry   = [pscustomobject]@{
      Taskbar = [pscustomobject]@{
        WidgetsTaskbarDa = (Get-RegistryValueState -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarDa')
        ChatTaskbarMn    = (Get-RegistryValueState -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarMn')
        CopilotButton    = (Get-RegistryValueState -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowCopilotButton')
      }
      Visuals = [pscustomobject]@{
        Transparency     = (Get-RegistryValueState -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'EnableTransparency')
        TaskbarAnimations = (Get-RegistryValueState -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAnimations')
        VisualFxSetting  = (Get-RegistryValueState -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting')
      }
      GameDVR = [pscustomobject]@{
        GameDvrEnabled   = (Get-RegistryValueState -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled')
        AppCaptureEnabled = (Get-RegistryValueState -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AppCaptureEnabled')
      }
      Notifications = [pscustomobject]@{
        ToastEnabled = (Get-RegistryValueState -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications' -Name 'ToastEnabled')
      }
      DeliveryOptimization = [pscustomobject]@{
        DODownloadMode = (Get-RegistryValueState -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' -Name 'DODownloadMode')
      }
      Power = [pscustomobject]@{
        HiberbootEnabled = (Get-RegistryValueState -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled')
      }
    }
  }
}

function Add-SystemSnapshotAction {
  param(
    [Parameter(Mandatory)] [AllowEmptyCollection()] [System.Collections.Generic.List[object]]$Actions,
    [Parameter(Mandatory)] [ValidateSet('Before', 'After')] [string]$Stage,
    [Parameter(Mandatory)] [string]$Feature
  )

  $Actions.Add([pscustomobject]@{ Type = 'SystemSnapshot'; Feature = $Feature; Stage = $Stage })
}

function Get-LatestRunFolder {
  param([Parameter(Mandatory)] [string]$Root)
  if (-not (Test-Path -LiteralPath $Root)) {
    return $null
  }

  $folders = Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue |
    Sort-Object -Property Name -Descending

  return $folders | Select-Object -First 1
}

function Save-Json {
  param(
    [Parameter(Mandatory)] [object]$Object,
    [Parameter(Mandatory)] [string]$Path
  )
  $Object | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Load-Json {
  param([Parameter(Mandatory)] [string]$Path)
  return Get-Content -LiteralPath $Path -Encoding UTF8 | ConvertFrom-Json
}

function Get-RegistryValueState {
  param(
    [Parameter(Mandatory)] [string]$Path,
    [Parameter(Mandatory)] [string]$Name
  )

  $item = Get-ItemProperty -LiteralPath $Path -ErrorAction SilentlyContinue
  if ($null -eq $item) {
    return [pscustomobject]@{ Exists = $false; Value = $null }
  }

  $properties = $item.PSObject.Properties.Name
  if ($properties -notcontains $Name) {
    return [pscustomobject]@{ Exists = $false; Value = $null }
  }

  return [pscustomobject]@{ Exists = $true; Value = $item.$Name }
}

function Ensure-RegistryKey {
  param([Parameter(Mandatory)] [string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -Path $Path -Force | Out-Null
  }
}

function Add-RegistryAction {
  param(
    [Parameter(Mandatory)] [AllowEmptyCollection()] [System.Collections.Generic.List[object]]$Actions,
    [Parameter(Mandatory)] [string]$Path,
    [Parameter(Mandatory)] [string]$Name,
    [Parameter(Mandatory)] [ValidateSet('DWord', 'String')] [string]$Type,
    [Parameter(Mandatory)] $DesiredValue,
    [Parameter(Mandatory)] [string]$Feature
  )

  $prev = Get-RegistryValueState -Path $Path -Name $Name
  $Actions.Add([pscustomobject]@{
      Type         = 'Registry'
      Feature      = $Feature
      Path         = $Path
      Name         = $Name
      ValueType    = $Type
      DesiredValue = $DesiredValue
      Previous     = $prev
    })
}

function Invoke-RegistryAction {
  param(
    [Parameter(Mandatory)] $Action
  )

  $target = "$($Action.Path)\\$($Action.Name)"
  if (-not $PSCmdlet.ShouldProcess($target, "Set $($Action.ValueType) to $($Action.DesiredValue)")) {
    return
  }

  Ensure-RegistryKey -Path $Action.Path

  if ($Action.ValueType -eq 'DWord') {
    New-ItemProperty -LiteralPath $Action.Path -Name $Action.Name -Value ([int]$Action.DesiredValue) -PropertyType DWord -Force | Out-Null
  } else {
    New-ItemProperty -LiteralPath $Action.Path -Name $Action.Name -Value ([string]$Action.DesiredValue) -PropertyType String -Force | Out-Null
  }
}

function Revert-RegistryAction {
  param([Parameter(Mandatory)] $Action)

  $target = "$($Action.Path)\\$($Action.Name)"
  if (-not $PSCmdlet.ShouldProcess($target, 'Revert registry value')) {
    return
  }

  Ensure-RegistryKey -Path $Action.Path

  if ($Action.Previous.Exists -eq $true) {
    $prevValue = $Action.Previous.Value
    if ($Action.ValueType -eq 'DWord') {
      New-ItemProperty -LiteralPath $Action.Path -Name $Action.Name -Value ([int]$prevValue) -PropertyType DWord -Force | Out-Null
    } else {
      New-ItemProperty -LiteralPath $Action.Path -Name $Action.Name -Value ([string]$prevValue) -PropertyType String -Force | Out-Null
    }
  } else {
    Remove-ItemProperty -LiteralPath $Action.Path -Name $Action.Name -ErrorAction SilentlyContinue
  }
}

function Get-ServiceState {
  param([Parameter(Mandatory)] [string]$Name)

  $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
  if ($null -eq $svc) {
    return $null
  }

  $cim = Get-CimInstance -ClassName Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue
  $startMode = if ($null -ne $cim) { $cim.StartMode } else { $null }

  return [pscustomobject]@{
    Exists    = $true
    Status    = [string]$svc.Status
    StartMode = [string]$startMode
  }
}

function Add-ServiceAction {
  param(
    [Parameter(Mandatory)] [AllowEmptyCollection()] [System.Collections.Generic.List[object]]$Actions,
    [Parameter(Mandatory)] [string]$Name,
    [Parameter(Mandatory)] [ValidateSet('Automatic', 'Manual', 'Disabled')] [string]$DesiredStartMode,
    [Parameter(Mandatory)] [ValidateSet('Running', 'Stopped')] [string]$DesiredStatus,
    [Parameter(Mandatory)] [string]$Feature
  )

  $prev = Get-ServiceState -Name $Name
  if ($null -eq $prev) {
    $Actions.Add([pscustomobject]@{ Type = 'ServiceMissing'; Feature = $Feature; Name = $Name })
    return
  }

  $Actions.Add([pscustomobject]@{
      Type            = 'Service'
      Feature         = $Feature
      Name            = $Name
      DesiredStartMode = $DesiredStartMode
      DesiredStatus    = $DesiredStatus
      Previous        = $prev
    })
}

function Invoke-ServiceAction {
  param([Parameter(Mandatory)] $Action)

  if ($Action.Type -eq 'ServiceMissing') {
    Write-Log -Level 'WARN' -Message "Service '$($Action.Name)' not found; skipping."
    return
  }

  $target = "Service $($Action.Name)"
  if (-not $PSCmdlet.ShouldProcess($target, "Set start mode $($Action.DesiredStartMode) and $($Action.DesiredStatus)")) {
    return
  }

  Set-Service -Name $Action.Name -StartupType $Action.DesiredStartMode
  if ($Action.DesiredStatus -eq 'Running') {
    Start-Service -Name $Action.Name -ErrorAction SilentlyContinue
  } else {
    Stop-Service -Name $Action.Name -Force -ErrorAction SilentlyContinue
  }
}

function Revert-ServiceAction {
  param([Parameter(Mandatory)] $Action)

  if ($Action.Type -eq 'ServiceMissing') {
    return
  }

  $target = "Service $($Action.Name)"
  if (-not $PSCmdlet.ShouldProcess($target, 'Revert service start mode/status')) {
    return
  }

  $prevMode = $Action.Previous.StartMode
  $prevStatus = $Action.Previous.Status

  # Win32_Service StartMode values are: Auto, Manual, Disabled
  $startup = switch ($prevMode) {
    'Auto' { 'Automatic' }
    'Automatic' { 'Automatic' }
    'Manual' { 'Manual' }
    'Disabled' { 'Disabled' }
    default { 'Manual' }
  }

  Set-Service -Name $Action.Name -StartupType $startup
  if ($prevStatus -eq 'Running') {
    Start-Service -Name $Action.Name -ErrorAction SilentlyContinue
  } else {
    Stop-Service -Name $Action.Name -Force -ErrorAction SilentlyContinue
  }
}

function Get-ActivePowerSchemeGuid {
  $out = powercfg /getactivescheme 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $out) {
    return $null
  }

  # Example: "Power Scheme GUID: 381b... (Balanced)"
  $m = [regex]::Match(($out | Out-String), 'Power Scheme GUID:\s*([a-fA-F0-9-]{36})')
  if (-not $m.Success) {
    return $null
  }

  return $m.Groups[1].Value
}

function Ensure-UltimatePerformancePlan {
  # Creates ultimate performance plan if missing.
  # Returns GUID or $null.
  $dup = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
  if ($LASTEXITCODE -ne 0) {
    return $null
  }

  $m = [regex]::Match(($dup | Out-String), '([a-fA-F0-9-]{36})')
  if (-not $m.Success) {
    return $null
  }

  return $m.Groups[1].Value
}

function Add-PowerPlanAction {
  param(
    [Parameter(Mandatory)] [AllowEmptyCollection()] [System.Collections.Generic.List[object]]$Actions,
    [Parameter(Mandatory)] [ValidateSet('Balanced', 'HighPerformance', 'UltimatePerformance')] [string]$Desired,
    [Parameter(Mandatory)] [string]$Feature
  )

  $prevGuid = Get-ActivePowerSchemeGuid
  $Actions.Add([pscustomobject]@{
      Type        = 'PowerPlan'
      Feature     = $Feature
      Desired     = $Desired
      PreviousGuid = $prevGuid
    })
}

function Invoke-PowerPlanAction {
  param([Parameter(Mandatory)] $Action)

  $target = 'Power plan'
  if (-not $PSCmdlet.ShouldProcess($target, "Set active plan to $($Action.Desired)")) {
    return
  }

  $desiredGuid = switch ($Action.Desired) {
    'Balanced' { '381b4222-f694-41f0-9685-ff5bb260df2e' }
    'HighPerformance' { '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' }
    'UltimatePerformance' {
      $u = Ensure-UltimatePerformancePlan
      if (-not $u) {
        Write-Log -Level 'WARN' -Message 'Ultimate Performance plan could not be created; falling back to High performance.'
        '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
      } else {
        $u
      }
    }
  }

  powercfg -setactive $desiredGuid | Out-Null
  $Action | Add-Member -NotePropertyName DesiredGuid -NotePropertyValue $desiredGuid -Force
}

function Revert-PowerPlanAction {
  param([Parameter(Mandatory)] $Action)

  if (-not $Action.PreviousGuid) {
    Write-Log -Level 'WARN' -Message 'Previous power scheme GUID not captured; skipping power plan revert.'
    return
  }

  $target = 'Power plan'
  if (-not $PSCmdlet.ShouldProcess($target, "Restore active plan to $($Action.PreviousGuid)")) {
    return
  }

  powercfg -setactive $Action.PreviousGuid | Out-Null
}

function Add-StartupAppsReportAction {
  param(
    [Parameter(Mandatory)] [AllowEmptyCollection()] [System.Collections.Generic.List[object]]$Actions,
    [Parameter(Mandatory)] [string]$Feature
  )

  $Actions.Add([pscustomobject]@{ Type = 'StartupAppsReport'; Feature = $Feature })
}

function Invoke-StartupAppsReportAction {
  param(
    [Parameter(Mandatory)] $Action,
    [Parameter(Mandatory)] [string]$RunFolder
  )

  $target = 'Startup apps report'
  if (-not $PSCmdlet.ShouldProcess($target, 'Generate report (no changes)')) {
    return
  }

  $reportPath = Join-Path $RunFolder 'startup-apps.csv'

  $startupEntries = @()

  # Registry run keys (common locations)
  $runKeys = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
  )

  foreach ($rk in $runKeys) {
    if (Test-Path -LiteralPath $rk) {
      $props = (Get-ItemProperty -LiteralPath $rk).PSObject.Properties |
        Where-Object { $_.Name -notin @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider') }

      foreach ($p in $props) {
        $startupEntries += [pscustomobject]@{
          Source = $rk
          Name   = $p.Name
          Value  = [string]$p.Value
        }
      }
    }
  }

  $startupEntries | Sort-Object Source, Name | Export-Csv -LiteralPath $reportPath -NoTypeInformation -Encoding UTF8
  Write-Log -Message "Startup report written to: $reportPath"
}

function Build-Plan {
  param(
    [Parameter(Mandatory)] [string]$Profile,
    [Parameter(Mandatory)] [string[]]$Features
  )

  $actions = New-Object 'System.Collections.Generic.List[object]'

  $wantsSnapshot = ($Features -contains 'SystemSnapshot')
  if ($wantsSnapshot) {
    Add-SystemSnapshotAction -Actions $actions -Feature 'SystemSnapshot' -Stage 'Before'
  }

  foreach ($feature in $Features) {
    switch ($feature) {
      'SystemSnapshot' {
        # Handled by the pre/post actions above/below.
      }
      'Widgets' {
        Add-RegistryAction -Actions $actions -Feature $feature -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarDa' -Type 'DWord' -DesiredValue 0
      }
      'Chat' {
        Add-RegistryAction -Actions $actions -Feature $feature -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarMn' -Type 'DWord' -DesiredValue 0
      }
      'CopilotButton' {
        # Hides Copilot button. This does not remove Copilot components.
        Add-RegistryAction -Actions $actions -Feature $feature -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowCopilotButton' -Type 'DWord' -DesiredValue 0
      }
      'VisualEffects' {
        # Minimal, low-risk visuals trimming
        Add-RegistryAction -Actions $actions -Feature $feature -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'EnableTransparency' -Type 'DWord' -DesiredValue 0
        Add-RegistryAction -Actions $actions -Feature $feature -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAnimations' -Type 'DWord' -DesiredValue 0
        Add-RegistryAction -Actions $actions -Feature $feature -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting' -Type 'DWord' -DesiredValue 2
      }
      'GameDVR' {
        # Disable Game DVR / background recording
        Add-RegistryAction -Actions $actions -Feature $feature -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled' -Type 'DWord' -DesiredValue 0
        Add-RegistryAction -Actions $actions -Feature $feature -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AppCaptureEnabled' -Type 'DWord' -DesiredValue 0
        Add-RegistryAction -Actions $actions -Feature $feature -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name 'AllowGameDVR' -Type 'DWord' -DesiredValue 0
      }
      'PowerPlan' {
        $desired = switch ($Profile) {
          'Laptop' { 'Balanced' }
          'Work' { 'Balanced' }
          'Gaming' { 'UltimatePerformance' }
        }
        Add-PowerPlanAction -Actions $actions -Feature $feature -Desired $desired
      }
      'SearchIndexing' {
        # Uses Windows Search service (WSearch) as the main control.
        # Profile-based default: keep for Laptop/Work; disable for Gaming.
        $mode = switch ($Profile) {
          'Gaming' { 'Disabled' }
          default { 'Automatic' }
        }
        $status = if ($mode -eq 'Disabled') { 'Stopped' } else { 'Running' }
        Add-ServiceAction -Actions $actions -Feature $feature -Name 'WSearch' -DesiredStartMode $mode -DesiredStatus $status
      }
      'DeliveryOptimization' {
        # Disable P2P/peer delivery while keeping normal Windows Update downloads.
        # 0 = HTTP only (no P2P)
        Add-RegistryAction -Actions $actions -Feature $feature -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' -Name 'DODownloadMode' -Type 'DWord' -DesiredValue 0
      }
      'FastStartup' {
        # Disable Fast Startup for troubleshooting (revert restores prior value).
        Add-RegistryAction -Actions $actions -Feature $feature -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -Type 'DWord' -DesiredValue 0
      }
      'QuietMode' {
        # Gaming-focused "quiet mode": disable toast notifications.
        Add-RegistryAction -Actions $actions -Feature $feature -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications' -Name 'ToastEnabled' -Type 'DWord' -DesiredValue 0
      }
      'StartupAppsReport' {
        Add-StartupAppsReportAction -Actions $actions -Feature $feature
      }
    }
  }

  if ($wantsSnapshot) {
    Add-SystemSnapshotAction -Actions $actions -Feature 'SystemSnapshot' -Stage 'After'
  }

  return $actions
}

function Get-DefaultFeaturesForProfile {
  param([Parameter(Mandatory)] [string]$Profile)

  switch ($Profile) {
    'Laptop' { return @('SystemSnapshot', 'Widgets', 'Chat', 'CopilotButton', 'VisualEffects', 'PowerPlan', 'StartupAppsReport') }
    'Work'   { return @('SystemSnapshot', 'Widgets', 'Chat', 'CopilotButton', 'VisualEffects', 'DeliveryOptimization', 'PowerPlan', 'StartupAppsReport') }
    'Gaming' { return @('SystemSnapshot', 'Widgets', 'Chat', 'CopilotButton', 'VisualEffects', 'QuietMode', 'DeliveryOptimization', 'GameDVR', 'PowerPlan', 'SearchIndexing', 'StartupAppsReport') }
  }
}

function Prompt-ForProfile {
  $choices = @('Laptop', 'Work', 'Gaming')
  Write-Host ''
  Write-Host 'Select a profile:'
  for ($i = 0; $i -lt $choices.Count; $i++) {
    Write-Host ("  {0}) {1}" -f ($i + 1), $choices[$i])
  }

  while ($true) {
    $raw = Read-Host 'Enter number'
    $n = $null
    if ([int]::TryParse($raw, [ref]$n)) {
      if ($n -ge 1 -and $n -le $choices.Count) {
        return $choices[$n - 1]
      }
    }
    Write-Host 'Invalid selection. Try again.'
  }
}

function Prompt-ForFeatures {
  param(
    [Parameter(Mandatory)] [string[]]$Defaults
  )

  $all = @('Widgets', 'Chat', 'CopilotButton', 'VisualEffects', 'QuietMode', 'DeliveryOptimization', 'FastStartup', 'GameDVR', 'PowerPlan', 'SearchIndexing', 'StartupAppsReport', 'SystemSnapshot')

  Write-Host ''
  Write-Host 'Select features (comma-separated numbers). Press Enter to accept defaults.'
  Write-Host ("Defaults: {0}" -f ($Defaults -join ', '))
  for ($i = 0; $i -lt $all.Count; $i++) {
    Write-Host ("  {0}) {1}" -f ($i + 1), $all[$i])
  }

  $raw = Read-Host 'Selection'
  if ([string]::IsNullOrWhiteSpace($raw)) {
    return $Defaults
  }

  $selected = New-Object System.Collections.Generic.List[string]
  foreach ($token in $raw.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) {
    $n = $null
    if ([int]::TryParse($token, [ref]$n) -and $n -ge 1 -and $n -le $all.Count) {
      $selected.Add($all[$n - 1])
    }
  }

  if ($selected.Count -eq 0) {
    return $Defaults
  }

  return $selected.ToArray() | Select-Object -Unique
}

function Show-Plan {
  param([Parameter(Mandatory)] [object[]]$Actions)

  Write-Host ''
  Write-Host 'Planned actions:'

  $reg = @($Actions | Where-Object { $_.Type -eq 'Registry' }).Count
  $svc = @($Actions | Where-Object { $_.Type -like 'Service*' }).Count
  $pwr = @($Actions | Where-Object { $_.Type -eq 'PowerPlan' }).Count
  $rep = @($Actions | Where-Object { $_.Type -eq 'StartupAppsReport' }).Count
  $snap = @($Actions | Where-Object { $_.Type -eq 'SystemSnapshot' }).Count

  Write-Host ("  Registry changes: {0}" -f $reg)
  Write-Host ("  Service changes:  {0}" -f $svc)
  Write-Host ("  Power plan:       {0}" -f $pwr)
  Write-Host ("  Reports:          {0}" -f $rep)
  Write-Host ("  Snapshots:        {0}" -f $snap)

  foreach ($a in $Actions) {
    switch ($a.Type) {
      'Registry' {
        Write-Host ("  [Registry] {0}: {1} -> {2}" -f $a.Feature, "$($a.Path)\\$($a.Name)", $a.DesiredValue)
      }
      'Service' {
        Write-Host ("  [Service]  {0}: {1} start={2} status={3}" -f $a.Feature, $a.Name, $a.DesiredStartMode, $a.DesiredStatus)
      }
      'ServiceMissing' {
        Write-Host ("  [Service]  {0}: {1} (missing; will skip)" -f $a.Feature, $a.Name)
      }
      'PowerPlan' {
        Write-Host ("  [Power]    {0}: {1}" -f $a.Feature, $a.Desired)
      }
      'StartupAppsReport' {
        Write-Host ("  [Report]   {0}: startup-apps.csv" -f $a.Feature)
      }
      'SystemSnapshot' {
        Write-Host ("  [Snapshot] {0}: {1}" -f $a.Feature, $a.Stage)
      }
    }
  }
}

function Apply-Actions {
  param(
    [Parameter(Mandatory)] [object[]]$Actions,
    [Parameter(Mandatory)] [string]$RunFolder
  )

  $results = New-Object 'System.Collections.Generic.List[object]'

  foreach ($a in $Actions) {
    try {
      switch ($a.Type) {
        'Registry' { Invoke-RegistryAction -Action $a }
        'Service' { Invoke-ServiceAction -Action $a }
        'ServiceMissing' { Invoke-ServiceAction -Action $a }
        'PowerPlan' { Invoke-PowerPlanAction -Action $a }
        'StartupAppsReport' { Invoke-StartupAppsReportAction -Action $a -RunFolder $RunFolder }
        'SystemSnapshot' {
          $snap = Get-SystemSnapshot -Profile $script:Profile -Features $script:Features
          $name = if ($a.Stage -eq 'Before') { 'snapshot-before.json' } else { 'snapshot-after.json' }
          $outPath = Join-Path $RunFolder $name
          if ($PSCmdlet.ShouldProcess($outPath, "Write system snapshot ($($a.Stage))")) {
            $snap | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $outPath -Encoding UTF8
            Write-Log -Message "Snapshot written to: $outPath"
          }
        }
      }

      $results.Add([pscustomobject]@{ Feature = $a.Feature; Type = $a.Type; Status = 'OK' })
    } catch {
      Write-Log -Level 'ERROR' -Message "Failed action [$($a.Type)] feature [$($a.Feature)]: $($_.Exception.Message)"
      $results.Add([pscustomobject]@{ Feature = $a.Feature; Type = $a.Type; Status = 'FAILED'; Error = $_.Exception.Message })
    }
  }

  return $results
}

function Revert-Actions {
  param(
    [Parameter(Mandatory)] [object[]]$Actions
  )

  $results = New-Object 'System.Collections.Generic.List[object]'

  foreach ($a in $Actions) {
    try {
      switch ($a.Type) {
        'Registry' { Revert-RegistryAction -Action $a }
        'Service' { Revert-ServiceAction -Action $a }
        'ServiceMissing' { }
        'PowerPlan' { Revert-PowerPlanAction -Action $a }
        'StartupAppsReport' { }
      }

      $results.Add([pscustomobject]@{ Feature = $a.Feature; Type = $a.Type; Status = 'OK' })
    } catch {
      Write-Log -Level 'ERROR' -Message "Failed revert [$($a.Type)] feature [$($a.Feature)]: $($_.Exception.Message)"
      $results.Add([pscustomobject]@{ Feature = $a.Feature; Type = $a.Type; Status = 'FAILED'; Error = $_.Exception.Message })
    }
  }

  return $results
}

# --- Entry point ---

# Windows PowerShell 5.1 does not have the $IsWindows automatic variable.
if ($env:OS -ne 'Windows_NT') {
  throw 'This script is intended to run on Windows.'
}

if (-not (Test-IsAdministrator)) {
  throw 'Administrator privileges are required.'
}

Ensure-Directory -Path $BackupRoot

$osBuild = Get-OsBuildNumber
if ($null -ne $osBuild -and $osBuild -lt 22000) {
  Write-Log -Level 'WARN' -Message ("This appears to be Windows build {0}; this script targets Windows 11 (build 22000+)." -f $osBuild)
}

if ($Revert) {
  if (-not $BackupPath) {
    $latest = Get-LatestRunFolder -Root $BackupRoot
    if ($null -eq $latest) {
      throw "No run folders found under $BackupRoot"
    }
    $BackupPath = $latest.FullName
  }

  $manifestPath = Join-Path $BackupPath 'manifest.json'
  if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "manifest.json not found in $BackupPath"
  }

  $manifest = Load-Json -Path $manifestPath
  $actionsToRevert = @($manifest.Actions)

  Write-Log -Message "Reverting from: $BackupPath"
  Show-Plan -Actions $actionsToRevert

  $results = Revert-Actions -Actions $actionsToRevert

  $revertLog = Join-Path $BackupPath 'revert-results.json'
  Save-Json -Object $results -Path $revertLog

  Write-Log -Message "Revert complete. Results: $revertLog"
  return
}

if ($Interactive -or -not $Profile) {
  if (-not $Profile) {
    $Profile = Prompt-ForProfile
  }

  $defaults = Get-DefaultFeaturesForProfile -Profile $Profile
  if (-not $Features -or $Features.Count -eq 0) {
    $Features = Prompt-ForFeatures -Defaults $defaults
  }
} else {
  if (-not $Features -or $Features.Count -eq 0) {
    $Features = Get-DefaultFeaturesForProfile -Profile $Profile
  }
}

# In interactive mode, prompt for a restore point so users don't miss the option.
if ($Interactive -and -not $WhatIfPreference -and -not $CreateRestorePoint) {
  try {
    $CreateRestorePoint = $PSCmdlet.ShouldContinue(
      'Create a System Restore Point before applying changes? (Recommended)',
      'Restore Point'
    )
  } catch {
    # If the host cannot prompt, keep current value.
  }
}

$runId = New-RunId
$runFolder = Join-Path $BackupRoot $runId
Ensure-Directory -Path $runFolder

$logPath = Join-Path $runFolder 'run.log'
try {
  Start-Transcript -LiteralPath $logPath -Append | Out-Null
} catch {
  # Transcript can fail in some hosts; continue without it.
}

Write-Log -Message "Run folder: $runFolder"
Write-Log -Message "Profile: $Profile"
Write-Log -Message ("Features: {0}" -f ($Features -join ', '))

if ($CreateRestorePoint -and -not $WhatIfPreference) {
  Try-CreateRestorePoint -Description "Optimize-Windows11 $runId ($Profile)"
}

$actions = Build-Plan -Profile $Profile -Features $Features
Show-Plan -Actions $actions

# Confirmation (interactive only). -Confirm:$false suppresses ShouldContinue prompts.
if ($Interactive -and -not $WhatIfPreference) {
  $ok = $PSCmdlet.ShouldContinue('Apply these changes?', 'Confirm')
  if (-not $ok) {
    Write-Log -Level 'WARN' -Message 'Cancelled by user.'
    try { Stop-Transcript | Out-Null } catch { }
    return
  }
}

# Save manifest BEFORE applying so we always have something to revert from.
$manifest = [pscustomobject]@{
  RunId     = $runId
  CreatedAt = (Get-Date).ToString('s')
  Computer  = $env:COMPUTERNAME
  User      = $env:USERNAME
  Profile   = $Profile
  Features  = $Features
  Actions   = $actions
}

$manifestOut = Join-Path $runFolder 'manifest.json'
Save-Json -Object $manifest -Path $manifestOut

$results = Apply-Actions -Actions $actions -RunFolder $runFolder
$resultsOut = Join-Path $runFolder 'results.json'
Save-Json -Object $results -Path $resultsOut

Write-Log -Message "Done. Manifest: $manifestOut"
Write-Log -Message "Results:  $resultsOut"

try { Stop-Transcript | Out-Null } catch { }
