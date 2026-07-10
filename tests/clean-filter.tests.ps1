$ScriptRoot = Split-Path -Parent $PSCommandPath
. "$ScriptRoot\..\src\core\session-model.ps1"
. "$ScriptRoot\..\src\core\clean-filter.ps1"

$now = [datetime]"2026-06-02T12:00:00"
$sessions = @(
  (New-Session -Id "empty" -Provider "codex" -UpdatedAt $now.AddDays(-1) -IsEmpty $true)
  (New-Session -Id "old" -Provider "codex" -UpdatedAt $now.AddDays(-40) -IsEmpty $false)
  (New-Session -Id "recent" -Provider "opencode" -UpdatedAt $now.AddDays(-1) -IsEmpty $false)
)

Describe "Clean Filter" {
  It "returns no candidates when no criteria are provided" {
    $result = Select-CleanCandidates -Sessions $sessions -Now $now
    $result.Count | Should Be 0
  }

  It "returns only empty sessions when Empty is selected" {
    $result = Select-CleanCandidates -Sessions $sessions -Empty -Now $now
    $result.Count | Should Be 1
    $result[0].Id | Should Be "empty"
  }

  It "returns sessions older than the threshold" {
    $result = Select-CleanCandidates -Sessions $sessions -OlderThan "30d" -Now $now
    $result.Count | Should Be 1
    $result[0].Id | Should Be "old"
  }

  It "returns orphaned sessions when Orphaned is selected" {
    $orphan = New-Session -Id "orphan" -Provider "codex" -ProjectPath "C:\DoesNotExist_$(Get-Random)" -UpdatedAt $now
    $all = $sessions + $orphan
    $result = Select-CleanCandidates -Sessions $all -Orphaned -Now $now
    $result.Count | Should Be 1
    $result[0].Id | Should Be "orphan"
  }
}
