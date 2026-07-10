$ScriptRoot = Split-Path -Parent $PSCommandPath
. "$ScriptRoot\..\src\core\session-model.ps1"
. "$ScriptRoot\..\src\core\safety.ps1"

Describe "Safety Assert-SafePath" {
  It "returns true for paths inside allowed root" {
    Assert-SafePath -Path "C:\Projects\Foo\sub" -AllowedRoots @("C:\Projects") | Should Be $true
  }

  It "returns true for exact match" {
    Assert-SafePath -Path "C:\Projects" -AllowedRoots @("C:\Projects") | Should Be $true
  }

  It "returns false for paths outside allowed root" {
    Assert-SafePath -Path "D:\Other" -AllowedRoots @("C:\Projects") | Should Be $false
  }
}

Describe "Safety Warn-CurrentSession" {
  It "does not throw" {
    $s = New-Session -Id "test" -Provider "codex" -UpdatedAt (Get-Date) -IsCurrent $true
    { Warn-CurrentSession -Session $s } | Should Not Throw
  }
}
