function Get-Antigravity-ClisRoot {
  $path = "$env:USERPROFILE\.gemini\antigravity-cli"
  if (Test-Path $path) { return $path }
  return $null
}

function Get-Antigravity-CliRoots {
  $roots = @()
  $cli = Get-Antigravity-ClisRoot
  if ($cli) { $roots += $cli }
  $ide = "$env:USERPROFILE\.gemini\antigravity"
  if (Test-Path $ide) { $roots += $ide }
  return $roots
}

function Get-Antigravity-ConversationDirs {
  $dirs = @()
  $cli = Get-Antigravity-ClisRoot
  if ($cli) {
    $conv = Join-Path $cli "conversations"
    if (Test-Path $conv) { $dirs += $conv }
  }
  $ide = "$env:USERPROFILE\.gemini\antigravity\conversations"
  if (Test-Path $ide) { $dirs += $ide }
  return $dirs
}

function Get-Antigravity-HistoryPath {
  $cli = Get-Antigravity-ClisRoot
  if (-not $cli) { return $null }
  $h = Join-Path $cli "history.jsonl"
  if (Test-Path $h) { return $h }
  return $null
}

function Get-Antigravity-HistoryTitles {
  $historyPath = Get-Antigravity-HistoryPath
  $titles = @{}
  if (-not $historyPath) { return $titles }

  $reader = [System.IO.StreamReader]::new($historyPath)
  try {
    while (-not $reader.EndOfStream) {
      $line = $reader.ReadLine()
      if ([string]::IsNullOrWhiteSpace($line)) { continue }
      try {
        $obj = $line | ConvertFrom-Json -ErrorAction Stop
      } catch { continue }
      if ($obj.conversationId -and $obj.display -and -not $titles.ContainsKey([string]$obj.conversationId)) {
        $titles[[string]$obj.conversationId] = [string]$obj.display
      }
    }
  } finally { $reader.Close() }
  return $titles
}

function Detect-Antigravity {
  $hasAgy = (Get-Command "agy" -ErrorAction SilentlyContinue) -ne $null
  $hasDir = Test-Path "$env:USERPROFILE\.antigravity"
  $hasCli = $null -ne (Get-Antigravity-ClisRoot)
  return $hasAgy -or $hasDir -or $hasCli
}

function Get-Antigravity-Roots {
  $roots = @()
  $cli = Get-Antigravity-ClisRoot
  if ($cli) { $roots += $cli }
  return $roots
}

function Test-Antigravity-Writable {
  $convDirs = Get-Antigravity-ConversationDirs
  if ($convDirs.Count -eq 0) { return $false }
  $anyWritable = $false
  foreach ($d in $convDirs) {
    if (((Get-Item $d).Attributes -band [System.IO.FileAttributes]::ReadOnly) -ne [System.IO.FileAttributes]::ReadOnly) {
      $anyWritable = $true
    }
  }
  return $anyWritable
}

function Get-Antigravity-Info {
  $agyPath = (Get-Command "agy" -ErrorAction SilentlyContinue)
  $cliRoot = Get-Antigravity-ClisRoot
  $convDirs = Get-Antigravity-ConversationDirs

  $info = [PSCustomObject]@{
    AgyInPath        = $agyPath -ne $null
    CliDirExists     = $null -ne $cliRoot
    ConvDirExists    = $convDirs.Count -gt 0
  }

  if ($convDirs.Count -gt 0) {
    $allFiles = @()
    foreach ($d in $convDirs) {
      $allFiles += Get-ChildItem -LiteralPath $d -File -ErrorAction SilentlyContinue
    }
    $info | Add-Member -NotePropertyName ConversationCount -NotePropertyValue $allFiles.Count
    $totalSize = ($allFiles | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    $info | Add-Member -NotePropertyName ConvTotalSizeBytes -NotePropertyValue $totalSize
  }

  return $info
}

function Get-Antigravity-LastProjects {
  $cachePath = "$env:USERPROFILE\.gemini\antigravity-cli\cache\last_conversations.json"
  $projects = @{}
  if (Test-Path $cachePath) {
    try {
      $data = Get-Content -LiteralPath $cachePath -Raw | ConvertFrom-Json
      $data.PSObject.Properties | ForEach-Object { $projects[[string]$_.Value] = [string]$_.Name }
    } catch { }
  }
  return $projects
}

function Get-Antigravity-Sessions {
  $convDirs = Get-Antigravity-ConversationDirs
  if ($convDirs.Count -eq 0) { return @() }

  $titles = Get-Antigravity-HistoryTitles
  $projectMap = Get-Antigravity-LastProjects
  $sessions = @()

  foreach ($convDir in $convDirs) {
    $files = Get-ChildItem -LiteralPath $convDir -File -ErrorAction SilentlyContinue
    if (-not $files) { continue }

    foreach ($f in $files) {
      $id = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
      $updatedAt = $f.LastWriteTime
      $title = if ($titles.ContainsKey($id)) { $titles[$id] } else { $null }
      $projectPath = if ($projectMap.ContainsKey($id)) { $projectMap[$id] } else { $null }

      $sessions += New-Session `
        -Id $id `
        -Provider "antigravity" `
        -Title $title `
        -ProjectPath $projectPath `
        -SourcePath $f.FullName `
        -UpdatedAt $updatedAt `
        -SizeBytes $f.Length `
        -IsCurrent $false `
        -IsEmpty ($f.Length -lt 100)
    }
  }

  return $sessions | Sort-Object -Property UpdatedAt -Descending
}

function Remove-Antigravity-Session {
  param([Session]$Session)

  if (-not (Test-Path -LiteralPath $Session.SourcePath)) { return }

  Remove-Item -LiteralPath $Session.SourcePath -Force

  $historyPath = Get-Antigravity-HistoryPath
  if (-not $historyPath) { return }

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
        if ($obj.conversationId -and $obj.conversationId -eq $Session.Id) { $keep = $false }
      } catch { $keep = $true }
      if ($keep) { $writer.WriteLine($line) }
    }
  } finally {
    $reader.Close()
    $writer.Close()
  }
  Move-Item -LiteralPath $tempPath -Destination $historyPath -Force
}

function Get-Antigravity-CleanCandidates {
  $sessions = Get-Antigravity-Sessions
  return $sessions | Where-Object { $_.IsEmpty }
}
