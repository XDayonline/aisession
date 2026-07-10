function Select-SessionInteractive {
  param(
    [Session[]]$Items,
    [int]$PageSize = 5
  )

  $index = 0
  $pageSize = [Math]::Max(3, [Math]::Min(15, $PageSize))

  while ($true) {
    Clear-Host
    Write-Host "Selectionne une session (fleches, Entree, Echap)" -ForegroundColor Cyan
    Write-Host ("Total: {0} | Page: {1}" -f $Items.Count, $pageSize)
    Write-Host ""

    $start = [Math]::Max(0, $index - [Math]::Floor($pageSize / 2))
    $end = [Math]::Min($Items.Count - 1, $start + $pageSize - 1)
    $start = [Math]::Max(0, $end - $pageSize + 1)

    for ($i = $start; $i -le $end; $i++) {
      $s = $Items[$i]
      $tsShort = Format-Timestamp $s.UpdatedAt
      $idShort = if ($s.Id) { $s.Id.Substring(0, [Math]::Min(8, $s.Id.Length)) } else { "-" }
      $proj = if ($s.ProjectPath) { Split-Path $s.ProjectPath -Leaf } else { "-" }
      $title = Format-Message $s.Title
      $badge = Format-ProviderBadge $s.Provider
      $current = if ($s.IsCurrent) { " [CURRENT]" } else { "" }

      $line = "[{0,3}] {1,-5} {2} | {3} | {4}{5}" -f ($i + 1), $badge, $tsShort, $idShort, $proj, $current
      if ($i -eq $index) {
        Write-Host ("> " + $line) -ForegroundColor Green
        if ($s.Title) {
          Write-Host "  Title: " -NoNewline -ForegroundColor Magenta
          Write-Host $title
        }
      } else {
        if ($s.IsCurrent) {
          Write-Host ("  " + $line) -ForegroundColor Cyan
        } else {
          Write-Host ("  " + $line)
        }
        if ($s.Title) {
          Write-Host "  Title: " -NoNewline -ForegroundColor Magenta
          Write-Host $title
        }
      }
    }

    Write-Host ""
    Write-Host "Astuce: Left/Right ou PageUp/PageDown pour aller plus vite" -ForegroundColor DarkGray

    try {
      $key = [Console]::ReadKey($true)
    } catch {
      return $null
    }
    if (([ConsoleModifiers]::Control -band $key.Modifiers) -and $key.Key -eq 'C') { return $null }
    switch ($key.Key) {
      'UpArrow'   { if ($index -gt 0) { $index-- } }
      'DownArrow' { if ($index -lt ($Items.Count - 1)) { $index++ } }
      'LeftArrow' { $index = [Math]::Max(0, $index - $pageSize) }
      'RightArrow' { $index = [Math]::Min($Items.Count - 1, $index + $pageSize) }
      'PageUp'    { $index = [Math]::Max(0, $index - $pageSize) }
      'PageDown'  { $index = [Math]::Min($Items.Count - 1, $index + $pageSize) }
      'Home'      { $index = 0 }
      'End'       { $index = $Items.Count - 1 }
      'Enter'     { return $Items[$index] }
      'Escape'    { return $null }
    }
  }
}

function Select-Action {
  param([string]$Provider)

  while ($true) {
    Write-Host ""
    Write-Host "Action: [D]elete, [R]esume, [C]ancel" -ForegroundColor Cyan
    try {
      $key = [Console]::ReadKey($true)
    } catch {
      return $null
    }
    if (([ConsoleModifiers]::Control -band $key.Modifiers) -and $key.Key -eq 'C') { return $null }
    switch ($key.Key) {
      'D' { return 'delete' }
      'R' { return 'resume' }
      'C' { return $null }
      'Escape' { return $null }
    }
  }
}
