class Session {
  [string]   $Id
  [string]   $Provider
  [string]   $Title
  [string]   $ProjectPath
  [string]   $SourcePath
  [datetime] $UpdatedAt
  [long]     $SizeBytes
  [bool]     $IsCurrent
  [bool]     $IsEmpty
}

function New-Session {
  param(
    [string]$Id,
    [string]$Provider,
    [string]$Title,
    [string]$ProjectPath,
    [string]$SourcePath,
    [datetime]$UpdatedAt,
    [long]$SizeBytes = 0,
    [bool]$IsCurrent = $false,
    [bool]$IsEmpty = $false
  )
  return [Session]@{
    Id          = $Id
    Provider    = $Provider
    Title       = $Title
    ProjectPath = $ProjectPath
    SourcePath  = $SourcePath
    UpdatedAt   = $UpdatedAt
    SizeBytes   = $SizeBytes
    IsCurrent   = $IsCurrent
    IsEmpty     = $IsEmpty
  }
}
