$ScriptRoot = Split-Path -Parent $PSCommandPath
. "$ScriptRoot\..\src\core\session-model.ps1"
. "$ScriptRoot\..\src\core\session-filter.ps1"

$homeDir = "C:\Users\TestUser"
$sessions = @(
  (New-Session -Id "home" -Provider "opencode" -ProjectPath $homeDir -UpdatedAt (Get-Date))
  (New-Session -Id "rap" -Provider "opencode" -ProjectPath "$homeDir\Dev\rapevents-admin" -UpdatedAt (Get-Date))
  (New-Session -Id "aisession" -Provider "opencode" -ProjectPath "$homeDir\Dev\aisession" -UpdatedAt (Get-Date))
  (New-Session -Id "other" -Provider "opencode" -ProjectPath "D:\Other" -UpdatedAt (Get-Date))
)

Describe "Session Filter" {
  It "Exact returns only current directory sessions" {
    $result = Filter-SessionsByScope -Sessions $sessions -CurrentDir $homeDir -Mode "Exact"
    $result.Count | Should Be 1
    $result[0].Id | Should Be "home"
  }

  It "Tree returns current directory and subdirectory sessions" {
    $result = Filter-SessionsByScope -Sessions $sessions -CurrentDir $homeDir -Mode "Tree"
    $result.Count | Should Be 3
  }

  It "All returns every session" {
    $result = Filter-SessionsByScope -Sessions $sessions -CurrentDir $homeDir -Mode "All"
    $result.Count | Should Be 4
  }
}
