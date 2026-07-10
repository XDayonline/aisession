function Detect-OpenCode {
  return (Get-Command "opencode" -ErrorAction SilentlyContinue) -ne $null
}

function Get-OpenCode-Roots {
  return @("$env:USERPROFILE\.local\share\opencode")
}

function Test-OpenCode-Writable {
  return (Get-Command "opencode" -ErrorAction SilentlyContinue) -ne $null
}

function Get-OpenCode-CurrentSessionId {
  try {
    $envPath = "$env:USERPROFILE\.config\opencode\projects"
    if (Test-Path $envPath) {
      $projectName = (Get-ChildItem $envPath -Directory | Select-Object -First 1).Name
      if ($projectName) {
        $sessionFile = "$envPath\$projectName\.opencode\session"
        if (Test-Path $sessionFile) {
          return (Get-Content $sessionFile -Raw).Trim()
        }
      }
    }
  } catch {
  }
  return $null
}

function Get-OpenCode-Sessions {
  $currentSessionId = Get-OpenCode-CurrentSessionId
  $dbPath = "$env:USERPROFILE\.local\share\opencode\opencode.db"

  if (-not (Test-Path $dbPath)) { return @() }

  $scriptPath = "$env:TEMP\aisessions_opencode.py"
  $scriptContent = @"
import sqlite3, json
db_path = r'$dbPath'
conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row
cursor = conn.cursor()

msg_count = {}
for row in cursor.execute('SELECT session_id, COUNT(*) AS cnt FROM message GROUP BY session_id'):
    msg_count[row['session_id']] = row['cnt']

sessions = []
for row in cursor.execute('SELECT id, title, directory, time_created, time_updated FROM session ORDER BY time_updated DESC'):
    sessions.append({
        'id': row['id'],
        'title': row['title'] or '',
        'directory': row['directory'] or '',
        'time_created': row['time_created'],
        'time_updated': row['time_updated'],
        'message_count': msg_count.get(row['id'], 0)
    })
print(json.dumps(sessions))
conn.close()
"@

  try {
    Set-Content -Path $scriptPath -Value $scriptContent -Force -ErrorAction SilentlyContinue
    $jsonOutput = python $scriptPath 2>$null
    if (-not $jsonOutput) { return @() }

    $sessionsData = $jsonOutput | ConvertFrom-Json -ErrorAction SilentlyContinue
    if (-not $sessionsData) { return @() }

    $sessions = @()
    foreach ($s in $sessionsData) {
      $updatedAt = [datetime]::MinValue
      if ($s.time_updated -and $s.time_updated -gt 0) {
        try {
          $updatedAt = [DateTimeOffset]::FromUnixTimeMilliseconds($s.time_updated).LocalDateTime
        } catch {
          $updatedAt = [datetime]::MinValue
        }
      }

      $isEmpty = if ($null -ne $s.message_count) { $s.message_count -eq 0 } else { $false }

      $sizeBytes = -1
      $diffPath = "$env:USERPROFILE\.local\share\opencode\storage\session_diff\$($s.id).json"
      if (Test-Path -LiteralPath $diffPath) {
        $diffSize = (Get-Item -LiteralPath $diffPath).Length
        if ($diffSize -gt 2) { $sizeBytes = $diffSize }
      }

      $sessions += New-Session `
        -Id $s.id `
        -Provider "opencode" `
        -Title $s.title `
        -ProjectPath $s.directory `
        -SourcePath $dbPath `
        -UpdatedAt $updatedAt `
        -SizeBytes $sizeBytes `
        -IsCurrent ($s.id -eq $currentSessionId) `
        -IsEmpty $isEmpty
    }

    return $sessions
  } catch {
    return @()
  }
}

function Remove-OpenCode-Session {
  param([Session]$Session)

  if (-not (Get-Command "opencode" -ErrorAction SilentlyContinue)) {
    throw "OpenCode CLI non disponible, suppression impossible"
  }

  opencode session delete $Session.Id 2>&1 | Out-Null

  if ($LASTEXITCODE -ne 0) {
    throw "Echec de la suppression de la session OpenCode: $($Session.Id)"
  }
}

function Get-OpenCode-CleanCandidates {
  $sessions = Get-OpenCode-Sessions
  return $sessions | Where-Object { -not (Test-Path $_.ProjectPath) }
}
