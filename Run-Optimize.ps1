<#
.SYNOPSIS
  Convenience wrapper for Optimize-Windows11.ps1.

.DESCRIPTION
  Provides a simpler entry point for running Optimize-Windows11.ps1 with common options.
  Supports -WhatIf for safe previews and forwards arguments to the main script.

.EXAMPLE
  ./Run-Optimize.ps1 -Profile Gaming -WhatIf

.EXAMPLE
  ./Run-Optimize.ps1 -Profile Work -CreateRestorePoint

.EXAMPLE
  ./Run-Optimize.ps1 -Revert
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
  [Parameter()]
  [ValidateSet('Laptop', 'Work', 'Gaming')]
  [Alias('Profile')]
  [string]$DeviceProfile,

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
  [string]$BackupRoot,

  [Parameter()]
  [switch]$CreateRestorePoint,

  [Parameter()]
  [switch]$Force
)

$scriptPath = Join-Path $PSScriptRoot 'Optimize-Windows11.ps1'
if (-not (Test-Path -LiteralPath $scriptPath)) {
  throw "Optimize-Windows11.ps1 not found at: $scriptPath"
}

$params = @{}

if ($DeviceProfile) { $params.Profile = $DeviceProfile }
if ($Features -and $Features.Count -gt 0) { $params.Features = $Features }
if ($Interactive) { $params.Interactive = $true }
if ($Revert) { $params.Revert = $true }
if ($BackupPath) { $params.BackupPath = $BackupPath }
if ($BackupRoot) { $params.BackupRoot = $BackupRoot }
if ($CreateRestorePoint) { $params.CreateRestorePoint = $true }
if ($Force) { $params.Force = $true }

# Respect -WhatIf from this wrapper.
if ($WhatIfPreference) { $params.WhatIf = $true }

& $scriptPath @params
