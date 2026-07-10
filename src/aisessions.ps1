#!/usr/bin/env pwsh
[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [ValidateSet('doctor', 'list', 'delete', 'clean', 'pick', 'help')]
  [string]$Command = 'help',

  [Parameter(Position = 1)]
  [string]$Argument,

  [switch]$All,
  [Alias('Here')]
  [switch]$FilterHere,
  [switch]$Tree,
  [string]$Provider,
  [Alias('dry-run')]
  [switch]$DryRun,
  [switch]$Force,
  [Alias('older-than')]
  [string]$OlderThan,
  [switch]$Empty,
  [switch]$Orphaned
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $PSCommandPath

. "$ScriptDir\core\session-model.ps1"
. "$ScriptDir\core\session-filter.ps1"
. "$ScriptDir\core\clean-filter.ps1"
. "$ScriptDir\core\formatting.ps1"
. "$ScriptDir\core\safety.ps1"
. "$ScriptDir\core\interactive.ps1"

$providers = @()

$providerNames = @("codex", "opencode", "antigravity")
foreach ($name in $providerNames) {
  $path = "$ScriptDir\providers\$name.ps1"
  if (Test-Path $path) {
    . $path
    $providers += $name
  }
}

function Show-Help {
  Write-Host "aisession - Gerer les sessions d'agents IA" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Usage:" -ForegroundColor White
  Write-Host "  aisession doctor              Diagnostiquer l'environnement"
  Write-Host "  aisession list                Sessions du dossier courant uniquement"
  Write-Host "  aisession list --tree         Sessions du dossier courant + sous-dossiers"
  Write-Host "  aisession list --all          Toutes les sessions"
  Write-Host "  aisession list --provider X   Filtrer par provider"
  Write-Host "  aisession delete <id>         Supprimer une session"
  Write-Host "  aisession pick                Selection interactive (fleches)"
  Write-Host "  aisession clean               Nettoyage guide"
  Write-Host "  aisession clean --empty       Sessions vides uniquement"
  Write-Host "  aisession clean --orphaned    Sessions orphelines (projet supprime)"
  Write-Host "  aisession clean --older-than 30d  Sessions anciennes"
  Write-Host ""
  Write-Host "Options globales:" -ForegroundColor White
  Write-Host "  --dry-run   Simuler sans modifier"
  Write-Host "  --force     Supprimer sans confirmation"
  Write-Host "  --help      Afficher cette aide"
  Write-Host ""
  Write-Host "Astuce: utilisez toujours --dry-run avant --force." -ForegroundColor DarkGray
}

function Get-Sessions {
  $allSessions = @()
  $activeProviders = $providers
  if ($Provider) {
    $activeProviders = $providers | Where-Object { $_ -eq $Provider }
  }

  foreach ($p in $activeProviders) {
    $detected = & "Detect-$p" -ErrorAction SilentlyContinue
    if (-not $detected) { continue }
    $sessions = & "Get-$p-Sessions" -ErrorAction SilentlyContinue
    if ($sessions) { $allSessions += $sessions }
  }

  $mode = if ($All) { "All" } elseif ($Tree) { "Tree" } else { "Exact" }
  $allSessions = Filter-SessionsByScope -Sessions $allSessions -CurrentDir (Get-Location).Path -Mode $mode

  return $allSessions | Sort-Object -Property UpdatedAt -Descending
}

switch ($Command) {
  'doctor' {
    Write-Host "aisessions doctor" -ForegroundColor Cyan
    Write-Host ("{0,-20} {1}" -f "Detecte:", ($providers -join ", "))
    Write-Host ""

    foreach ($p in $providers) {
      $detected = & "Detect-$p" -ErrorAction SilentlyContinue
      $writable = if ($detected) { & "Test-$p-Writable" -ErrorAction SilentlyContinue } else { $false }

      Write-Host ("{0,-12}" -f $p) -NoNewline -ForegroundColor Magenta
      if ($detected) {
        Write-Host " [OK]" -NoNewline -ForegroundColor Green
        Write-Host " detecte"
        $roots = & "Get-$p-Roots" -ErrorAction SilentlyContinue
        if ($roots) {
          foreach ($r in $roots) {
            Write-Host ("  {0}" -f (Format-Path $r))
          }
        }
      } else {
        Write-Host " [--]" -NoNewline -ForegroundColor DarkGray
        Write-Host " non detecte"
      }
    }
  }

  'list' {
    $sessions = Get-Sessions

    if (-not $sessions -or $sessions.Count -eq 0) {
      Write-Host "Aucune session trouvee." -ForegroundColor Yellow
      exit 0
    }

    Write-Host ("{0} session(s) trouvee(s)" -f $sessions.Count) -ForegroundColor Cyan
    Write-Host ""

    $index = 1
    foreach ($s in $sessions) {
      Write-SessionRow $s $index
      if ($s.Title) {
        Write-Host "  Title: " -NoNewline -ForegroundColor Magenta
        Write-Host (Format-Message $s.Title)
      }
      $index++
    }
  }

  'delete' {
    if (-not $Argument) {
      Write-Host "Usage: aisessions delete <id>" -ForegroundColor Yellow
      exit 1
    }

    $sessions = Get-Sessions
    $target = $null

    if ($Argument -as [int]) {
      $idx = [int]$Argument
      if ($idx -ge 1 -and $idx -le $sessions.Count) {
        $target = $sessions[$idx - 1]
      }
    } else {
      $target = $sessions | Where-Object { $_.Id -eq $Argument }
    }

    if (-not $target) {
      Write-Host "Session introuvable: $Argument" -ForegroundColor Yellow
      exit 1
    }

    if ($DryRun) {
      Write-Host " [DRY-RUN] Session ciblee:" -ForegroundColor Yellow
      Write-Host "  Provider:  $($target.Provider)"
      Write-Host "  ID:        $($target.Id)"
      Write-Host "  Title:     $(Format-Message $target.Title)"
      Write-Host "  Chemin:    $(Format-Path $target.SourcePath)"
      Write-DryRunBanner
      exit 0
    }

    Warn-CurrentSession $target

    $ok = Confirm-DestructiveAction -Action "Suppression de session" -Target "$($target.Provider) / $($target.Id)" -Force:$Force
    if (-not $ok) { exit 0 }

    & "Remove-$($target.Provider)-Session" -Session $target -ErrorAction Stop
    Write-Host "Supprime: $($target.Id)" -ForegroundColor Green
  }

  'pick' {
    $sessions = Get-Sessions

    if (-not $sessions -or $sessions.Count -eq 0) {
      Write-Host "Aucune session trouvee." -ForegroundColor Yellow
      exit 0
    }

    if (-not [Console]::IsInputRedirected) {
      $selected = Select-SessionInteractive -Items $sessions
    } else {
      Write-Host "Mode interactif non disponible (redirection detectee)." -ForegroundColor Yellow
      exit 1
    }

    if (-not $selected) {
      Write-Host "Annule." -ForegroundColor Cyan
      exit 0
    }

    $action = Select-Action -Provider $selected.Provider
    if (-not $action) {
      Write-Host "Annule." -ForegroundColor Cyan
      exit 0
    }

    if ($action -eq 'delete') {
      if ($selected.IsCurrent) {
        Write-Host "ATTENTION: Session courante !" -ForegroundColor Red
      }
      $ok = Confirm-DestructiveAction -Action "Suppression" -Target "$($selected.Provider) / $($selected.Id)" -Force:$Force
      if (-not $ok) { exit 0 }
      & "Remove-$($selected.Provider)-Session" -Session $selected -ErrorAction Stop
      Write-Host "Supprime: $($selected.Id)" -ForegroundColor Green
    }

    if ($action -eq 'resume') {
      if ($selected.Provider -eq 'codex') {
        if (-not (Get-Command "codex" -ErrorAction SilentlyContinue)) {
          Write-Host "Codex CLI non disponible." -ForegroundColor Red
          exit 1
        }
        & codex resume $selected.Id
      } elseif ($selected.Provider -eq 'opencode') {
        if (-not (Get-Command "opencode" -ErrorAction SilentlyContinue)) {
          Write-Host "OpenCode CLI non disponible." -ForegroundColor Red
          exit 1
        }
        & opencode -s $selected.Id
      } else {
        Write-Host "Resume non supporte pour $($selected.Provider)." -ForegroundColor Yellow
        exit 1
      }
    }
  }

  'clean' {
    $All = $true
    if (-not $Empty -and -not $Orphaned -and -not $OlderThan) {
      Write-Host "Aucun critere de nettoyage fourni." -ForegroundColor Yellow
      Write-Host "Exemples:" -ForegroundColor Cyan
      Write-Host "  aisession clean -empty -dry-run"
      Write-Host "  aisession clean -orphaned -dry-run"
      Write-Host "  aisession clean -older-than 30d -dry-run"
      exit 1
    }

    $sessions = Get-Sessions
    $candidates = Select-CleanCandidates -Sessions $sessions -Empty:$Empty -Orphaned:$Orphaned -OlderThan $OlderThan

    if ($candidates.Count -eq 0) {
      Write-Host "Aucune session a nettoyer." -ForegroundColor Cyan
      exit 0
    }

    Write-Host ("{0} session(s) candidate(s) au nettoyage:" -f $candidates.Count) -ForegroundColor Yellow
    $idx = 1
    foreach ($c in $candidates) {
      Write-SessionRow $c $idx
      $idx++
    }

    if ($DryRun) {
      Write-DryRunBanner
      exit 0
    }

    $ok = Confirm-DestructiveAction -Action "Nettoyage" -Target "$($candidates.Count) session(s)" -Force:$Force
    if (-not $ok) { exit 0 }

    $removed = 0
    foreach ($c in $candidates) {
      try {
        & "Remove-$($c.Provider)-Session" -Session $c -ErrorAction Stop
        Write-Host "Supprime: $($c.Id)" -ForegroundColor Green
        $removed++
      } catch {
        Write-Host "Erreur: $($c.Id) - $_" -ForegroundColor Red
      }
    }
    Write-Host "Termine: $removed session(s) supprimee(s)." -ForegroundColor Cyan
  }

  default {
    Show-Help
  }
}
