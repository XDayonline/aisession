#!/usr/bin/env pwsh
[CmdletBinding()]
param(
  [string]$InstallDir = "$env:USERPROFILE\.local\bin",
  [switch]$Local
)

if ($Local) {
  $InstallDir = Split-Path -Parent $PSCommandPath
}

$targetDir = if ($Local) { $InstallDir } else { $InstallDir }
if (-not (Test-Path $targetDir)) {
  New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

$scriptDir = Split-Path -Parent $PSCommandPath
$entryPoint = Join-Path $scriptDir "src\aisessions.ps1"
$targetPath = Join-Path $targetDir "aisessions.ps1"

Copy-Item -LiteralPath $entryPoint -Destination $targetPath -Force

if (-not $Local) {
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if ($userPath -notlike "*$targetDir*") {
    $newPath = "$targetDir;" + $userPath
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "Ajoute $targetDir au PATH utilisateur." -ForegroundColor Green
  }
}

Write-Host "aisessions installe dans $targetDir" -ForegroundColor Green
Write-Host "Usage : aisessions doctor" -ForegroundColor Cyan
