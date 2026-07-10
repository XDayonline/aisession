$ScriptRoot = Split-Path -Parent $PSCommandPath
. "$ScriptRoot\..\src\core\session-model.ps1"
. "$ScriptRoot\..\src\core\formatting.ps1"
. "$ScriptRoot\..\src\core\safety.ps1"

$TestDir = Join-Path $env:TEMP "aisessions-test-codex_$(Get-Random)"
$origHome = $env:USERPROFILE
$env:USERPROFILE = $TestDir

New-Item -ItemType Directory -Path "$TestDir\.codex\sessions\2025\01\15" -Force | Out-Null
New-Item -ItemType Directory -Path "$TestDir\.codex\sessions\2025\06\20" -Force | Out-Null

$session1Data = @(
  '{"type":"session_meta","payload":{"id":"test-id-001","cwd":"C:\\Projects\\Foo","timestamp":"2025-01-15T10:00:00Z","title":"Fix login bug"}}'
  '{"type":"event_msg","payload":{"type":"user_message","message":"Can you fix the login bug?"}}'
) -join "`n"
Set-Content -Path "$TestDir\.codex\sessions\2025\01\15\rollout-test-id-001.jsonl" -Value $session1Data -Encoding UTF8

$session2Data = @(
  '{"type":"session_meta","payload":{"id":"test-id-002","cwd":"C:\\Projects\\Bar","timestamp":"2025-06-20T14:00:00Z","title":"Refactor API"}}'
) -join "`n"
Set-Content -Path "$TestDir\.codex\sessions\2025\06\20\rollout-test-id-002.jsonl" -Value $session2Data -Encoding UTF8

$historyData = @(
  '{"session_id":"test-id-001","title":"Login Fix History"}'
  '{"session_id":"test-id-003","title":"Other Session"}'
) -join "`n"
Set-Content -Path "$TestDir\.codex\history.jsonl" -Value $historyData -Encoding UTF8

. "$ScriptRoot\..\src\providers\codex.ps1"

Describe "Codex Get-Sessions" {
  It "returns sessions from JSONL files" {
    $sessions = Get-Codex-Sessions
    $sessions.Count | Should Be 2
  }

  It "extracts session ID from session_meta" {
    $sessions = Get-Codex-Sessions
    $s1 = $sessions | Where-Object { $_.Id -eq "test-id-001" }
    $s1 | Should Not BeNullOrEmpty
    $s1.Id | Should Be "test-id-001"
  }

  It "marks sessions with user messages as non-empty" {
    $sessions = Get-Codex-Sessions
    ($sessions | Where-Object { $_.Id -eq "test-id-001" }).IsEmpty | Should Be $false
  }

  It "marks sessions without user messages as empty" {
    $sessions = Get-Codex-Sessions
    ($sessions | Where-Object { $_.Id -eq "test-id-002" }).IsEmpty | Should Be $true
  }

  It "sets provider to codex" {
    $sessions = Get-Codex-Sessions
    $sessions[0].Provider | Should Be "codex"
  }

  It "resolves title from jsonl metadata" {
    $sessions = Get-Codex-Sessions
    ($sessions | Where-Object { $_.Id -eq "test-id-001" }).Title | Should Match "Fix login bug"
  }
}

Describe "Codex Remove-Session" {
  It "deletes session file and purges history" {
    $sessions = Get-Codex-Sessions
    $target = $sessions | Where-Object { $_.Id -eq "test-id-002" }
    $target | Should Not BeNullOrEmpty
    Remove-Codex-Session -Session $target
    Test-Path $target.SourcePath | Should Be $false

    $content = Get-Content -LiteralPath "$TestDir\.codex\history.jsonl" -Raw
    $content | Should Match "test-id-001"
    $content | Should Match "test-id-003"
  }
}

Describe "Codex CleanCandidates" {
  It "returns candidates without error" {
    $candidates = Get-Codex-CleanCandidates
    $candidates | Should Not BeNullOrEmpty
  }
}

$env:USERPROFILE = $origHome
Remove-Item -LiteralPath $TestDir -Recurse -Force -ErrorAction SilentlyContinue
