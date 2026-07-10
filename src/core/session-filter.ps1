function Normalize-SessionPath {
  param([string]$Path)

  if (-not $Path) { return "" }
  return ([System.IO.Path]::GetFullPath($Path)).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Test-IsSessionPathUnder {
  param(
    [string]$ProjectPath,
    [string]$CurrentDir
  )

  $project = Normalize-SessionPath $ProjectPath
  $current = Normalize-SessionPath $CurrentDir
  if (-not $project -or -not $current) { return $false }
  if ($project -eq $current) { return $true }

  $prefix = $current + [System.IO.Path]::DirectorySeparatorChar
  return $project.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)
}

function Filter-SessionsByScope {
  param(
    [Session[]]$Sessions,
    [string]$CurrentDir,
    [ValidateSet("Exact", "Tree", "All")]
    [string]$Mode = "Exact"
  )

  if ($Mode -eq "All") { return $Sessions }

  if ($Mode -eq "Tree") {
    return $Sessions | Where-Object { Test-IsSessionPathUnder -ProjectPath $_.ProjectPath -CurrentDir $CurrentDir }
  }

  $current = Normalize-SessionPath $CurrentDir
  return $Sessions | Where-Object { (Normalize-SessionPath $_.ProjectPath) -eq $current }
}
