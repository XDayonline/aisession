function Format-Timestamp([datetime]$dt) {
  if (-not $dt -or $dt -eq [datetime]::MinValue) { return "-" }
  return $dt.ToString("yyyy-MM-dd HH:mm")
}

function Format-Path([string]$path) {
  if (-not $path) { return "-" }
  $userHome = $env:USERPROFILE
  if ($path.StartsWith($userHome, [StringComparison]::OrdinalIgnoreCase)) {
    return $path.Replace($userHome, "~")
  }
  return $path
}

function Format-Message([string]$msg, [int]$maxLen = 48) {
  if ([string]::IsNullOrWhiteSpace($msg)) { return "-" }
  $m = ($msg -replace "\s+", " ").Trim()
  if ($m.Length -gt $maxLen) { return $m.Substring(0, $maxLen - 3) + "..." }
  return $m
}

function Format-Size([long]$bytes) {
  if ($bytes -lt 0) { return "-" }
  if ($bytes -lt 1KB) { return "$bytes B" }
  if ($bytes -lt 1MB) { return "{0:N1} KB" -f ($bytes / 1KB) }
  if ($bytes -lt 1GB) { return "{0:N1} MB" -f ($bytes / 1MB) }
  return "{0:N2} GB" -f ($bytes / 1GB)
}

function Get-ProviderColor([string]$provider) {
  switch ($provider.ToLower()) {
    'codex'      { return 'Yellow'  }
    'opencode'   { return 'Cyan'    }
    'antigravity'{ return 'Magenta' }
    default      { return 'White'   }
  }
}

function Write-SessionRow([Session]$s, [int]$index) {
  $ts = Format-Timestamp $s.UpdatedAt
  $idShort = if ($s.Id) { $s.Id.Substring(0, [Math]::Min(8, $s.Id.Length)) } else { "-" }
  $proj = if ($s.ProjectPath) { Split-Path $s.ProjectPath -Leaf } else { "-" }
  $title = Format-Message $s.Title
  $size = Format-Size $s.SizeBytes
  $current = if ($s.IsCurrent) { " *" } else { "" }
  $color = if ($s.IsCurrent) { 'Cyan' } else { Get-ProviderColor $s.Provider }

  $line = "[{0,3}] {1,-5} {2} | {3} | {4,-16} | {5,8}{6}" -f $index, ($s.Provider.ToUpper().Substring(0, [Math]::Min(5, $s.Provider.Length))), $ts, $idShort, $proj, $size, $current
  Write-Host $line -ForegroundColor $color
}
