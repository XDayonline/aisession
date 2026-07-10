function Detect-Codex {
  return Test-Path "$env:USERPROFILE\.codex\sessions"
}

function Get-Codex-Roots {
  return @("$env:USERPROFILE\.codex\sessions")
}

function Test-Codex-Writable {
  $root = "$env:USERPROFILE\.codex\sessions"
  return (Test-Path $root) -and ((Get-Item $root).Attributes -band [System.IO.FileAttributes]::ReadOnly) -ne [System.IO.FileAttributes]::ReadOnly
}

function Get-HistoryTitleMap {
  $indexPath = Join-Path $env:USERPROFILE ".codex\session_index.jsonl"
  $historyPath = Join-Path $env:USERPROFILE ".codex\history.jsonl"
  $titles = @{}

  if (Test-Path $indexPath) {
    $reader = [System.IO.StreamReader]::new($indexPath)
    try {
      while (-not $reader.EndOfStream) {
        $line = $reader.ReadLine()
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
          $obj = $line | ConvertFrom-Json -ErrorAction Stop
        } catch {
          continue
        }
        if ($obj.id -and $obj.thread_name) {
          $titles[[string]$obj.id] = [string]$obj.thread_name
        }
      }
    } finally {
      $reader.Close()
    }
  }

  if (-not (Test-Path $historyPath)) { return $titles }

  $reader = [System.IO.StreamReader]::new($historyPath)
  try {
    while (-not $reader.EndOfStream) {
      $line = $reader.ReadLine()
      if ([string]::IsNullOrWhiteSpace($line)) { continue }
      try {
        $obj = $line | ConvertFrom-Json -ErrorAction Stop
      } catch {
        continue
      }
      if ($obj.session_id -and $obj.title -and -not $titles.ContainsKey([string]$obj.session_id)) {
        $titles[[string]$obj.session_id] = [string]$obj.title
      }
    }
  } finally {
    $reader.Close()
  }

  return $titles
}

function Get-Codex-Sessions {
  $root = "$env:USERPROFILE\.codex\sessions"
  if (-not (Test-Path $root)) { return @() }

  $files = Get-ChildItem -Path $root -Recurse -Filter *.jsonl -File -ErrorAction SilentlyContinue
  if (-not $files) { return @() }

  $historyTitles = Get-HistoryTitleMap
  $sessions = @()

  foreach ($file in $files) {
    $id = $null
    $cwd = $null
    $ts = $null
    $title = $null
    $hasUserMessage = $false

    $reader = [System.IO.StreamReader]::new($file.FullName)
    try {
      while (-not $reader.EndOfStream) {
        $line = $reader.ReadLine()
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
          $obj = $line | ConvertFrom-Json -ErrorAction Stop
        } catch {
          continue
        }

        if ($obj.type -eq "session_meta") {
          if ($obj.payload.id) { $id = $obj.payload.id }
          if ($obj.payload.cwd) { $cwd = $obj.payload.cwd }
          if ($obj.payload.timestamp) { $ts = $obj.payload.timestamp }
          if (-not $title -and $obj.payload.title) { $title = [string]$obj.payload.title }
        }

        if ($obj.type -eq "event_msg" -and $obj.payload.type -eq "user_message") {
          $hasUserMessage = $true
        }

        if ($id -and $cwd -and $ts -and $hasUserMessage) {
          break
        }
      }
    } finally {
      $reader.Close()
    }

    if (-not $title -and $id -and $historyTitles.ContainsKey([string]$id)) {
      $title = [string]$historyTitles[[string]$id]
    }

    $updatedAt = [DateTime]::MinValue
    if ($ts) {
      try { $updatedAt = [DateTime]::Parse($ts, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AdjustToUniversal).ToLocalTime() } catch { }
    }

    $fi = Get-Item -LiteralPath $file.FullName

    $sessions += New-Session `
      -Id $id `
      -Provider "codex" `
      -Title $title `
      -ProjectPath $cwd `
      -SourcePath $file.FullName `
      -UpdatedAt $updatedAt `
      -SizeBytes $fi.Length `
      -IsCurrent $false `
      -IsEmpty (-not $hasUserMessage)
  }

  return $sessions
}

function Remove-Codex-Session {
  param([Session]$Session)

  if (-not (Test-Path -LiteralPath $Session.SourcePath)) { return }

  Remove-Item -LiteralPath $Session.SourcePath -Force

  $historyPath = Join-Path $env:USERPROFILE ".codex\history.jsonl"
  if (-not (Test-Path $historyPath)) { return }

  $tempPath = $historyPath + ".tmp"
  $reader = [System.IO.StreamReader]::new($historyPath)
  $writer = [System.IO.StreamWriter]::new($tempPath, $false, [System.Text.Encoding]::UTF8)
  try {
    while (-not $reader.EndOfStream) {
      $line = $reader.ReadLine()
      if ([string]::IsNullOrWhiteSpace($line)) { continue }
      $keep = $true
      try {
        $obj = $line | ConvertFrom-Json -ErrorAction Stop
        if ($obj.session_id -and $obj.session_id -eq $Session.Id) { $keep = $false }
      } catch {
        $keep = $true
      }
      if ($keep) { $writer.WriteLine($line) }
    }
  } finally {
    $reader.Close()
    $writer.Close()
  }

  Move-Item -LiteralPath $tempPath -Destination $historyPath -Force
}

function Get-Codex-CleanCandidates {
  $sessions = Get-Codex-Sessions
  return $sessions | Where-Object {
    $_.IsEmpty -or (-not $_.ProjectPath) -or (-not (Test-Path -LiteralPath $_.ProjectPath))
  }
}
