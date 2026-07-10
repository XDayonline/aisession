function Convert-CleanAgeToDays {
  param([string]$OlderThan)

  if (-not $OlderThan) { return $null }
  if ($OlderThan -match '^(\d+)d$') { return [int]$Matches[1] }
  if ($OlderThan -as [int]) { return [int]$OlderThan }
  return $null
}

function Select-CleanCandidates {
  param(
    [Session[]]$Sessions,
    [switch]$Empty,
    [switch]$Orphaned,
    [string]$OlderThan,
    [datetime]$Now = (Get-Date)
  )

  $candidates = @()

  if ($Empty) {
    $candidates += $Sessions | Where-Object { $_.IsEmpty }
  }

  if ($Orphaned) {
    $candidates += $Sessions | Where-Object {
      $_.ProjectPath -and -not (Test-Path -LiteralPath $_.ProjectPath -ErrorAction SilentlyContinue)
    }
  }

  if ($OlderThan) {
    $days = Convert-CleanAgeToDays -OlderThan $OlderThan
    if ($null -ne $days) {
      $cutoff = $Now.AddDays(-$days)
      $candidates += $Sessions | Where-Object { $_.UpdatedAt -lt $cutoff }
    }
  }

  return $candidates | Sort-Object -Unique -Property Provider, Id
}
