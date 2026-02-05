# Tests\Pester\Test-ProofOfLife.Tests.ps1
# Post-build proof-of-life: validates the baseline DSC created files
# Run after orchestration. Expected to fail before first successful build.

$ErrorActionPreference = 'Stop'

Describe "Proof-of-Life (DSC created files)" {

    It "C:\\TEST directory exists" {
        Test-Path 'C:\\TEST' | Should -BeTrue
    }

    It "C:\\TEST\\test.txt exists" {
        Test-Path 'C:\\TEST\\test.txt' | Should -BeTrue
    }

    It "test.txt has expected contents" {
        if (-not (Test-Path 'C:\\TEST\\test.txt')) { Set-ItResult -Failed -Because "File missing"; return }
        $content = Get-Content 'C:\\TEST\\test.txt' -ErrorAction Stop -Raw
        $content | Should -Be 'Proof-of-life: DSC created this file.'
    }
}
