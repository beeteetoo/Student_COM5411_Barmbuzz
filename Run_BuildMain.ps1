<#
========================================================================================
COM5411 Enterprise Operating Systems – BarmBuzz
Run_BuildMain.ps1  (STUDENT REPO – Canonical Orchestrator)

YOU RUN ONE COMMAND:
    .\Run_BuildMain.ps1

YOU EDIT ONLY TWO FILES:
    1) DSC\Configurations\StudentConfig.ps1
    2) DSC\Data\AllNodes.psd1

EVERYTHING ELSE IS TUTOR-PROVIDED OR EVIDENCE OUTPUT.

This orchestrator uses repo-rooted relative paths via $PSScriptRoot, runs in PowerShell 7
as Administrator, stages evidence automatically, and calls OneShot prereqs early.
========================================================================================
#>

[CmdletBinding()]
param(
    [switch]$Pause
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Repo root is where this script lives.
$RootPath = $PSScriptRoot

# Paths
$StudentConfigScript = Join-Path $RootPath "DSC\Configurations\StudentConfig.ps1"
$StudentDataFile     = Join-Path $RootPath "DSC\Data\AllNodes.psd1"
$OutputsRoot         = Join-Path $RootPath "DSC\Outputs"
$EvidenceRoot        = Join-Path $RootPath "Evidence"
$ConfigName          = "StudentBaseline"

# OneShots (direct paths) and helper wrapper
$PrereqLcmScript     = Join-Path $RootPath "Scripts\Prereqs\BarmBuzz_OneShot_LCM.ps1"
$PrereqNetworkScript = Join-Path $RootPath "Scripts\Prereqs\BarmBuzz_OneShot_Network.ps1"
$OneShotsHelperPath  = Join-Path $RootPath "Scripts\Helpers\Invoke-BarmBuzz-OneShots.ps1"

# Flag files for idempotency
$LcmFlagFile     = Join-Path $EvidenceRoot "prereq_lcm_complete.flag"
$NetworkFlagFile = Join-Path $EvidenceRoot "prereq_network_complete.flag"

function New-FolderIfMissing {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

function Assert-Admin {
    $principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "You must run PowerShell as Administrator."
    }
}

function Assert-AllNodesData {
    param([Parameter(Mandatory)]$ConfigData)
    if (-not ($ConfigData -is [hashtable])) { throw "AllNodes.psd1 must return a hashtable." }
    if (-not $ConfigData.ContainsKey("AllNodes")) { throw "AllNodes.psd1 must contain the key 'AllNodes'." }
    if (-not ($ConfigData.AllNodes -is [System.Array])) { throw "AllNodes must be an array." }
    $local = $ConfigData.AllNodes | Where-Object { $_.NodeName -eq "localhost" } | Select-Object -First 1
    if (-not $local) { throw "AllNodes must include NodeName = 'localhost' for this lab VM build." }
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "        COM5411 BarmBuzz Build Runner      " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "[*] Repo root: $RootPath" -ForegroundColor Gray
Write-Host "[*] PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
Write-Host "[*] You edit ONLY: DSC\\Configurations\\StudentConfig.ps1 and DSC\\Data\\AllNodes.psd1" -ForegroundColor Gray

# Evidence folders
New-FolderIfMissing -Path $OutputsRoot
New-FolderIfMissing -Path $EvidenceRoot
New-FolderIfMissing -Path (Join-Path $EvidenceRoot "Transcripts")
New-FolderIfMissing -Path (Join-Path $EvidenceRoot "DSC")
New-FolderIfMissing -Path (Join-Path $EvidenceRoot "Network")
New-FolderIfMissing -Path (Join-Path $EvidenceRoot "AI_LOG")
New-FolderIfMissing -Path (Join-Path $EvidenceRoot "Git\Reflog")

# Start transcript
$RunStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$TranscriptPath = Join-Path $EvidenceRoot ("Transcripts\{0}_Run_BuildMain.txt" -f $RunStamp)
Start-Transcript -Path $TranscriptPath -Force | Out-Null
Write-Host "[+] Transcript started: Evidence\\Transcripts\\$(Split-Path -Leaf $TranscriptPath)" -ForegroundColor Green

try {
    Assert-Admin
    Write-Host "[+] Admin privileges confirmed." -ForegroundColor Green

    # Required inputs present
    if (-not (Test-Path $StudentConfigScript)) { throw "Missing: DSC\\Configurations\\StudentConfig.ps1" }
    if (-not (Test-Path $StudentDataFile))     { throw "Missing: DSC\\Data\\AllNodes.psd1" }
    if (-not (Test-Path $PrereqLcmScript))     { throw "Missing: Scripts\\Prereqs\\BarmBuzz_OneShot_LCM.ps1" }
    if (-not (Test-Path $PrereqNetworkScript)) { throw "Missing: Scripts\\Prereqs\\BarmBuzz_OneShot_Network.ps1" }

    Write-Host "`n[Phase 1] Prerequisites..." -ForegroundColor Yellow

    # If helper exists, use it; else call scripts directly
    if (Test-Path $OneShotsHelperPath) {
        . $OneShotsHelperPath
        if (Get-Command Invoke-BarmBuzz-OneShots -ErrorAction SilentlyContinue) {
            Invoke-BarmBuzz-OneShots -RootPath $RootPath -LcmFlagFile $LcmFlagFile -NetworkFlagFile $NetworkFlagFile
        } else {
            Write-Host "[*] Helper not loaded; falling back to direct OneShots." -ForegroundColor Gray
        }
    }

    if (-not (Test-Path $LcmFlagFile)) {
        & $PrereqLcmScript
        New-Item -Path $LcmFlagFile -ItemType File -Force | Out-Null
        Write-Host "[+] LCM configured and flagged." -ForegroundColor Green
    } else {
        Write-Host "[*] LCM already configured (skipping)." -ForegroundColor Gray
    }

    if (-not (Test-Path $NetworkFlagFile)) {
        & $PrereqNetworkScript
        New-Item -Path $NetworkFlagFile -ItemType File -Force | Out-Null
        Write-Host "[+] Network configured and flagged." -ForegroundColor Green
    } else {
        Write-Host "[*] Network already configured (skipping)." -ForegroundColor Gray
    }

    Write-Host "[+] Phase 1 complete." -ForegroundColor Green

    Write-Host "`n[Phase 2] Compile + Apply DSC..." -ForegroundColor Yellow

    $ConfigData = Import-PowerShellDataFile -Path $StudentDataFile
    Assert-AllNodesData -ConfigData $ConfigData
    . $StudentConfigScript
    if (-not (Get-Command $ConfigName -ErrorAction SilentlyContinue)) {
        throw "StudentConfig.ps1 must define a Configuration named '$ConfigName'."
    }
    Write-Host "[+] Found configuration: $ConfigName" -ForegroundColor Green

    $CompileOut = Join-Path $OutputsRoot $ConfigName
    New-FolderIfMissing -Path $CompileOut
    Write-Host "[*] Compiling -> DSC\\Outputs\\$ConfigName" -ForegroundColor Gray
    & $ConfigName -ConfigurationData $ConfigData -OutputPath $CompileOut
    Write-Host "[+] Compilation complete." -ForegroundColor Green

    Get-ChildItem -Path $CompileOut -Recurse |
        Select-Object FullName, Length, LastWriteTime |
        Out-File (Join-Path $EvidenceRoot ("DSC\{0}_compiled_files.txt" -f $RunStamp)) -Encoding UTF8

    Write-Host "[*] Applying configuration (waits until complete)..." -ForegroundColor Gray
    Start-DscConfiguration -Path $CompileOut -Wait -Force -Verbose 4>&1 |
        Tee-Object -FilePath (Join-Path $EvidenceRoot ("DSC\{0}_apply_verbose.txt" -f $RunStamp))
    Write-Host "[+] Apply complete." -ForegroundColor Green

    ipconfig /all | Out-File (Join-Path $EvidenceRoot ("Network\{0}_ipconfig.txt" -f $RunStamp)) -Encoding UTF8
    w32tm /query /status 2>&1 | Out-File (Join-Path $EvidenceRoot ("Network\{0}_w32tm_status.txt" -f $RunStamp)) -Encoding UTF8

    Write-Host "`n[Phase 3] Validation..." -ForegroundColor Yellow
    Write-Host "[*] Pester validation will be added later." -ForegroundColor Gray

    Write-Host "`n[+] BUILD SUCCESS" -ForegroundColor Green
    Write-Host "[*] Next steps (commit outputs + evidence):" -ForegroundColor Gray
    Write-Host "    git add DSC\Outputs Evidence" -ForegroundColor Gray
    Write-Host "    git commit -m \"Build $RunStamp\"" -ForegroundColor Gray
}
catch {
    Write-Host "`n[-] BUILD FAILED" -ForegroundColor Red
    Write-Host ("Message: {0}" -f $_.Exception.Message) -ForegroundColor Red
    try { Stop-Transcript | Out-Null } catch { }
    exit 1
}
finally {
    try { Stop-Transcript | Out-Null } catch { }
    if ($Pause) { Read-Host -Prompt "Press Enter to exit" | Out-Null }
}
