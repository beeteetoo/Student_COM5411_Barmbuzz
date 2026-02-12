# Tests\Pester\Preflight-Environment.Tests.ps1
# Pester v5.x
#
# COM5411 IaC Environment Preflight (Dual-Shell, Student-Friendly Failures)
#
# INTENT:
#   This test validates the lab environment BEFORE students attempt DSC/AD automation.
#   If something is missing, it FAILS with an explicit instruction:
#       "Run Run_BuildMain.ps1 first, then re-run this test"
#
# ASSUMPTIONS / CONTRACT:
#   - Students run orchestration via PowerShell 7 as Administrator.
#   - Run_BuildMain.ps1 (orchestrator) will call the OneShot scripts that:
#       * set NIC profile Private (if needed)
#       * enable/configure WinRM/PSRemoting (fixes WS-Man ConnectionError)
#       * configure LCM, etc.
#   - DSC resource modules are stored in:
#       C:\Program Files\WindowsPowerShell\Modules
#     so the Windows PowerShell adapter can see them.
#
# HOW TO RUN (from repo root, in PowerShell 7):
#   Invoke-Pester -Path .\Tests\Pester\Preflight-Environment.Tests.ps1 -Output Detailed
#
# If it fails with an instruction to run Run_BuildMain.ps1:
#   1) Close PowerShell
#   2) Open PowerShell 7 as Administrator
#   3) Run:
#         .\Run_BuildMain.ps1
#   4) Re-run this test.
#
# NOTE:
#   This test is a CHECK ONLY. It does not attempt to fix the machine.
#   Fixing is the job of the OneShot scripts called by Run_BuildMain.ps1.

$ErrorActionPreference = 'Stop'

Describe "COM5411 IaC Environment Preflight (Dual-Shell)" {

    # PESTER v5: BeforeDiscovery runs BEFORE test discovery (when Pester scans for tests)
    # Variables here are used in test names and foreach loops that generate tests
    # These need to be available when Pester is building the test structure
    BeforeDiscovery {
        # STUDENT NOTE: The test harness (Invoke-Validation.ps1) automatically injects
        # $RepoRoot and $EvidenceDir via the param() block below!
        # You can access them here during discovery, and again in BeforeAll for test execution
        param(
            $RepoRoot,      # Injected by harness: path to repo root
            $EvidenceDir    # Injected by harness: path to Evidence\Pester
        )
        
        # Variables needed during discovery phase (for foreach loops, test names)
        $ExpectedModuleRoot = "C:\Program Files\WindowsPowerShell\Modules"

        # Versions pinned in your lab baseline
        # NOTE: PSDesiredStateConfiguration 2.0.7 requires PS 6.1+ and won't load in WinPS 5.1
        # So we test it separately for PS7 only
        $Pinned = @{
            ActiveDirectoryDsc          = [version]'6.6.0'
            GroupPolicyDsc              = [version]'1.0.3'
            Pester                      = [version]'5.7.1'
        }

        # PS7-only modules (won't work in Windows PowerShell 5.1)
        $PS7OnlyPinned = @{
            PSDesiredStateConfiguration = [version]'2.0.7'
        }

        $RequiredUnpinned = @(
            "ComputerManagementDsc"
        )
    }

    # PESTER v5: BeforeAll runs BEFORE tests execute (after discovery is complete)
    # Variables here need $script: scope to be accessible in test bodies
    # Functions defined here are available to all tests
    BeforeAll {
        # STUDENT NOTE: Receive injected data from the test harness
        # The harness (Invoke-Validation.ps1) passes RepoRoot and EvidenceDir automatically
        param(
            $RepoRoot,      # Injected: repo root path
            $EvidenceDir    # Injected: Evidence\Pester path
        )
        
        # Store in script scope so all tests can access them
        $script:repoRoot = $RepoRoot
        $script:evidenceDir = $EvidenceDir

        # LEGACY FALLBACK: If not injected (running test file directly), calculate it
        if (-not $script:repoRoot) {
            # Pester file is: Tests\Pester\Preflight-Environment.Tests.ps1
            # Repo root is:   ..\..\ from this file
            $here = Split-Path -Parent $PSCommandPath
            $script:repoRoot = (Resolve-Path (Join-Path $here "..\..")).Path
        }

        function Test-IsAdmin {
            $p = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
            return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        }

        function Invoke-WinPS {
            param([Parameter(Mandatory)][string]$Command)

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "powershell.exe"
            $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"$Command`""
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError  = $true
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow  = $true

            $p = New-Object System.Diagnostics.Process
            $p.StartInfo = $psi
            $null = $p.Start()
            $stdout = $p.StandardOutput.ReadToEnd()
            $stderr = $p.StandardError.ReadToEnd()
            $p.WaitForExit()

            [pscustomobject]@{
                ExitCode = $p.ExitCode
                StdOut   = $stdout.Trim()
                StdErr   = $stderr.Trim()
            }
        }

        function Get-TopModuleInCurrentShell {
            param([Parameter(Mandatory)][string]$Name)

            Get-Module -ListAvailable -Name $Name |
                Sort-Object Version -Descending |
                Select-Object -First 1
        }

        function Get-ModulePathInWinPS {
            param([Parameter(Mandatory)][string]$Name)

            # PESTER v5: Filter by Program Files path to exclude built-in system32 modules
            # This ensures we're checking the modules installed by Run_BuildMain.ps1
            $cmd = @"
`$targetPath = 'C:\Program Files\WindowsPowerShell\Modules'
`$m = Get-Module -ListAvailable -Name '$Name' | Where-Object { `$_.ModuleBase -like (`$targetPath + '\*') } | Sort-Object Version -Descending | Select-Object -First 1
if (`$null -eq `$m) { exit 2 }
Write-Output `$m.Path
"@
            Invoke-WinPS -Command $cmd
        }

        function Get-ModuleVersionInWinPS {
            param([Parameter(Mandatory)][string]$Name)

            $cmd = @"
`$targetPath = 'C:\Program Files\WindowsPowerShell\Modules'
`$m = Get-Module -ListAvailable -Name '$Name' | Where-Object { `$_.ModuleBase -like (`$targetPath + '\*') } | Sort-Object Version -Descending | Select-Object -First 1
if (`$null -eq `$m) { exit 2 }
Write-Output (`$m.Version.ToString())
"@
            Invoke-WinPS -Command $cmd
        }

        function Test-ModuleInWinPS {
            param([Parameter(Mandatory)][string]$Name)

            # PESTER v5: For RSAT modules, don't filter by path (they live in system32)
            # RSAT tools are installed via Windows Capabilities/Features, not PSGallery
            $cmd = @"
`$m = Get-Module -ListAvailable -Name '$Name' | Select-Object -First 1
if (`$null -eq `$m) { exit 2 }
Write-Output `$m.Path
"@
            Invoke-WinPS -Command $cmd
        }

        function Fail-WithRunBuildMain {
            param(
                [Parameter(Mandatory)][string]$Problem,
                [string]$Details = ""
            )

            $msg = @"
$Problem

NEXT STEP (do this first, then re-run Preflight):
  1) Open PowerShell 7 as Administrator
  2) From the REPO ROOT run:
       .\Run_BuildMain.ps1
  3) Then re-run:
       Invoke-Pester -Path .\Tests\Pester\Preflight-Environment.Tests.ps1 -Output Detailed
"@

            if ($Details) {
                $msg += "`nDETAILS:`n$Details`n"
            }

            throw $msg
        }

        # $script:repoRoot is already set from injected parameter above
        $script:IsAdmin  = Test-IsAdmin

        # PESTER v5: Re-declare the same variables from BeforeDiscovery with $script: scope
        # This makes them accessible in test bodies (which run after discovery)
        # Course convention: legacy modules must be visible to Windows PowerShell adapter
        $script:ExpectedModuleRoot = "C:\Program Files\WindowsPowerShell\Modules"

        # Versions pinned in your lab baseline
        # NOTE: PSDesiredStateConfiguration 2.0.7 requires PS 6.1+ and won't load in WinPS 5.1
        $script:Pinned = @{
            ActiveDirectoryDsc          = [version]'6.6.0'
            GroupPolicyDsc              = [version]'1.0.3'
            Pester                      = [version]'5.7.1'
        }

        # PS7-only modules (won't work in Windows PowerShell 5.1)
        $script:PS7OnlyPinned = @{
            PSDesiredStateConfiguration = [version]'2.0.7'
        }

        $script:RequiredUnpinned = @(
            "ComputerManagementDsc"
        )
    }

    Context "Entry requirements" {

        It "Must be run from PowerShell 7 (pwsh) (this is the orchestration shell)" {
            if ($PSVersionTable.PSVersion.Major -ne 7) {
                Fail-WithRunBuildMain -Problem "You are not running PowerShell 7." -Details "Detected: $($PSVersionTable.PSVersion)"
            }
            $PSVersionTable.PSVersion.Major | Should -Be 7
        }

        It "Should be run as Administrator (recommended for meaningful preflight)" {
            if (-not $script:IsAdmin) {
                Fail-WithRunBuildMain -Problem "You are not running as Administrator." -Details "DSC + WinRM checks require elevation. Right-click PowerShell 7 -> Run as Administrator."
            }
            $script:IsAdmin | Should -BeTrue
        }

        It "Repo root contains Run_BuildMain.ps1 (orchestrator)" {
            $path = Join-Path $script:RepoRoot "Run_BuildMain.ps1"
            if (-not (Test-Path $path)) {
                throw "Cannot find Run_BuildMain.ps1 at repo root: $path"
            }
            Test-Path $path | Should -BeTrue
        }
    }

    Context "Diagnostics (support visibility)" {

        It "PSModulePath is set in PowerShell 7 (current process)" {
            ($env:PSModulePath -split ';') | Should -Not -BeNullOrEmpty
        }

        It "PSModulePath is set in Windows PowerShell 5.1" {
            $r = Invoke-WinPS -Command '$env:PSModulePath'
            $r.ExitCode | Should -Be 0
            $r.StdOut | Should -Not -BeNullOrEmpty
        }
    }

    Context "Toolchain (PowerShell 7)" {

        It "DSC v3 CLI exists on PATH (dsc.exe)" {
            try {
                (Get-Command dsc -ErrorAction Stop).Source | Should -Not -BeNullOrEmpty
            }
            catch {
                Fail-WithRunBuildMain -Problem "DSC v3 CLI (dsc.exe) not found on PATH." -Details $_.Exception.Message
            }
        }

        It "PSResourceGet is available (Microsoft.PowerShell.PSResourceGet)" {
            $m = Get-Module -ListAvailable Microsoft.PowerShell.PSResourceGet
            if (-not $m) {
                Fail-WithRunBuildMain -Problem "PSResourceGet is missing (Microsoft.PowerShell.PSResourceGet)." -Details "This is required to install/pin modules."
            }
            $m | Should -Not -BeNullOrEmpty
        }
    }

    Context "DSC resource modules (pinned + placed for adapter visibility)" {

        It "Canonical module root exists (C:\Program Files\WindowsPowerShell\Modules)" {
            if (-not (Test-Path $script:ExpectedModuleRoot)) {
                Fail-WithRunBuildMain -Problem "Expected module folder missing: $script:ExpectedModuleRoot" -Details "Your lab baseline installs DSC modules here so the WindowsPowerShell adapter can see them."
            }
            Test-Path $script:ExpectedModuleRoot | Should -BeTrue
        }

        # PESTER v5: Use -ForEach parameter instead of foreach loops around It blocks
        # Variables from BeforeDiscovery are used here (no $script: prefix needed)
        # The hashtable properties become variables inside the It block
        It "PowerShell 7: <name> is installed and pinned to <ver>" -ForEach @(
            foreach ($name in $Pinned.Keys) {
                @{ name = $name; ver = $Pinned[$name] }
            }
        ) {
            $m = Get-TopModuleInCurrentShell -Name $name
            if (-not $m) {
                Fail-WithRunBuildMain -Problem "Module missing in PowerShell 7: $name" -Details "Run_BuildMain.ps1 should install/pin required modules."
            }
            ([version]$m.Version) | Should -Be $ver
        }

        It "Windows PowerShell 5.1: <name> is installed, pinned to <ver>, and stored under WindowsPowerShell\Modules" -ForEach @(
            foreach ($name in $Pinned.Keys) {
                @{ name = $name; ver = $Pinned[$name] }
            }
        ) {
            $v = Get-ModuleVersionInWinPS -Name $name
            if ($v.ExitCode -ne 0) {
                Fail-WithRunBuildMain -Problem "Module missing in Windows PowerShell 5.1: $name" -Details "Run_BuildMain.ps1 should install/pin modules into $script:ExpectedModuleRoot."
            }
            ([version]$v.StdOut) | Should -Be $ver

            $p = Get-ModulePathInWinPS -Name $name
            $p.ExitCode | Should -Be 0
            $p.StdOut | Should -Match ([regex]::Escape($script:ExpectedModuleRoot))
        }

        # PESTER v5: Separate test for modules that only work in PS7 (not WinPS 5.1)
        # PSDesiredStateConfiguration 2.0.7 requires PowerShell 6.1+
        It "PowerShell 7: <name> is installed and pinned to <ver> (PS7-only)" -ForEach @(
            foreach ($name in $PS7OnlyPinned.Keys) {
                @{ name = $name; ver = $PS7OnlyPinned[$name] }
            }
        ) {
            $m = Get-TopModuleInCurrentShell -Name $name
            if (-not $m) {
                Fail-WithRunBuildMain -Problem "Module missing in PowerShell 7: $name" -Details "Run_BuildMain.ps1 should install/pin required modules."
            }
            ([version]$m.Version) | Should -Be $ver
        }

        It "PowerShell 7: <name> is installed" -ForEach @(
            foreach ($name in $RequiredUnpinned) {
                @{ name = $name }
            }
        ) {
            $m = Get-TopModuleInCurrentShell -Name $name
            if (-not $m) {
                Fail-WithRunBuildMain -Problem "Module missing in PowerShell 7: $name" -Details "Run_BuildMain.ps1 should install required modules."
            }
            $m | Should -Not -BeNullOrEmpty
        }

        It "Windows PowerShell 5.1: <name> is installed under WindowsPowerShell\Modules" -ForEach @(
            foreach ($name in $RequiredUnpinned) {
                @{ name = $name }
            }
        ) {
            $p = Get-ModulePathInWinPS -Name $name
            if ($p.ExitCode -ne 0) {
                Fail-WithRunBuildMain -Problem "Module missing in Windows PowerShell 5.1: $name" -Details "Run_BuildMain.ps1 should install required modules into $script:ExpectedModuleRoot."
            }
            $p.StdOut | Should -Match ([regex]::Escape($script:ExpectedModuleRoot))
        }
    }

    Context "RSAT / admin tooling (AD + GPO management)" {

        It "Windows PowerShell 5.1: ActiveDirectory module is available" {
            $p = Test-ModuleInWinPS -Name "ActiveDirectory"
            if ($p.ExitCode -ne 0) {
                Fail-WithRunBuildMain -Problem "RSAT AD tools missing: ActiveDirectory module not found in Windows PowerShell 5.1." -Details "Run_BuildMain.ps1 should install RSAT (client capabilities or server features)."
            }
            $p.StdOut | Should -Not -BeNullOrEmpty
        }

        It "Windows PowerShell 5.1: GroupPolicy module is available" {
            $p = Test-ModuleInWinPS -Name "GroupPolicy"
            if ($p.ExitCode -ne 0) {
                Fail-WithRunBuildMain -Problem "RSAT GPO tools missing: GroupPolicy module not found in Windows PowerShell 5.1." -Details "Run_BuildMain.ps1 should install RSAT/GPMC."
            }
            $p.StdOut | Should -Not -BeNullOrEmpty
        }

        It "PowerShell 7: ActiveDirectory module discoverable (informational)" {
            $m = Get-TopModuleInCurrentShell -Name "ActiveDirectory"
            if (-not $m) {
                Set-ItResult -Skipped -Because "ActiveDirectory not discoverable in PS7. Acceptable if WinPS 5.1 has it (adapter path)."
                return
            }
            $m.Path | Should -Not -BeNullOrEmpty
        }

        It "PowerShell 7: GroupPolicy module discoverable (informational)" {
            $m = Get-TopModuleInCurrentShell -Name "GroupPolicy"
            if (-not $m) {
                Set-ItResult -Skipped -Because "GroupPolicy not discoverable in PS7. Acceptable if WinPS 5.1 has it (adapter path)."
                return
            }
            $m.Path | Should -Not -BeNullOrEmpty
        }
    }

    Context "WinRM / WS-Man local connectivity (common lab failure)" {

        It "WinRM service exists" {
            Get-Service WinRM | Should -Not -BeNullOrEmpty
        }

        It "WinRM should be Running (if not: run Run_BuildMain.ps1 which calls OneShot Network)" {
            $svc = Get-Service WinRM
            if ($svc.Status -ne 'Running') {
                Fail-WithRunBuildMain -Problem "WinRM service is not running (Status: $($svc.Status))." -Details "This causes WS-Man ConnectionError. Run_BuildMain.ps1 (Admin) to apply the OneShot Network baseline."
            }
            $svc.Status | Should -Be 'Running'
        }

        It "WS-Man should respond locally (Test-WSMan localhost)" {
            try {
                Test-WSMan localhost | Out-Null
            }
            catch {
                Fail-WithRunBuildMain -Problem "WS-Man failed (Test-WSMan localhost)." -Details $_.Exception.Message
            }
        }
    }

    Context "Developer tooling" {

        It "Git is installed (git.exe on PATH)" {
            try {
                (Get-Command git -ErrorAction Stop).Source | Should -Not -BeNullOrEmpty
            }
            catch {
                Fail-WithRunBuildMain -Problem "Git not found on PATH." -Details $_.Exception.Message
            }
        }

        It "VS Code installed (code.exe on PATH) [optional]" {
            if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
                Set-ItResult -Skipped -Because "VS Code not found on PATH (OK if not installed on this VM)."
                return
            }
            (Get-Command code).Source | Should -Not -BeNullOrEmpty
        }
    }
}
