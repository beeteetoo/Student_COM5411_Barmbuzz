function Invoke-BarmBuzz-OneShots {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$RootPath,
        [string]$LcmFlagFile,
        [string]$NetworkFlagFile
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    $lcmScript     = Join-Path $RootPath 'Scripts\Prereqs\BarmBuzz_OneShot_LCM.ps1'
    $networkScript = Join-Path $RootPath 'Scripts\Prereqs\BarmBuzz_OneShot_Network.ps1'

    if (-not (Test-Path $lcmScript))     { throw "Missing: $lcmScript" }
    if (-not (Test-Path $networkScript)) { throw "Missing: $networkScript" }

    Write-Host "[*] Invoke-BarmBuzz-OneShots: LCM then Network" -ForegroundColor Gray

    if (-not [string]::IsNullOrWhiteSpace($LcmFlagFile) -and (Test-Path $LcmFlagFile)) {
        Write-Host "[*] LCM already configured (flag present)." -ForegroundColor Gray
    } else {
        & $lcmScript
        if ($LcmFlagFile) { New-Item -Path $LcmFlagFile -ItemType File -Force | Out-Null }
    }

    if (-not [string]::IsNullOrWhiteSpace($NetworkFlagFile) -and (Test-Path $NetworkFlagFile)) {
        Write-Host "[*] Network already configured (flag present)." -ForegroundColor Gray
    } else {
        & $networkScript
        if ($NetworkFlagFile) { New-Item -Path $NetworkFlagFile -ItemType File -Force | Out-Null }
    }
}
