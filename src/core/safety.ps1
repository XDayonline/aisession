function Confirm-DestructiveAction {
  param(
    [string]$Action,
    [string]$Target,
    [switch]$Force
  )

  if ($Force) { return $true }

  Write-Host ""
  Write-Host "ATTENTION: $Action" -ForegroundColor Red
  Write-Host "  $Target" -ForegroundColor Yellow
  Write-Host ""
  Write-Host "Cette action est irreversible." -ForegroundColor Yellow
  $confirm = Read-Host "Confirmer ? (y/N)"
  if ($confirm -notin @("y", "Y")) {
    Write-Host "Annule." -ForegroundColor Cyan
    return $false
  }
  return $true
}

function Assert-SafePath {
  param(
    [string]$Path,
    [string[]]$AllowedRoots
  )

  try {
    $resolved = [System.IO.Path]::GetFullPath($Path)
  } catch {
    return $false
  }

  foreach ($root in $AllowedRoots) {
    try {
      $resolvedRoot = [System.IO.Path]::GetFullPath($root)
    } catch {
      continue
    }
    if ($resolved.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }
  return $false
}

function Write-DryRunBanner {
  Write-Host ""
  Write-Host " [DRY-RUN] Aucune modification effectuee." -ForegroundColor Yellow
  Write-Host " [DRY-RUN] Passez --force pour executer reellement." -ForegroundColor Yellow
  Write-Host ""
}

function Test-CurrentSession {
  param(
    [Session]$Session,
    [string]$CurrentId
  )
  if (-not $CurrentId) { return $false }
  return ($Session.Id -eq $CurrentId)
}

function Warn-CurrentSession {
  param([Session]$Session)
  if ($Session.IsCurrent) {
    Write-Host "ATTENTION: Session courante !" -ForegroundColor Red
    Write-Host "  La session que vous supprimez est active." -ForegroundColor Red
  }
}
