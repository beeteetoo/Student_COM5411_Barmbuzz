<#
.SYNOPSIS
    STAFF PROVIDED: Network & Remoting Prep.
    https://learn.microsoft.com/en-us/windows/win32/winrm/windows-remote-management-architecture
.DESCRIPTION
    1. Forces the Network Connection Profile to 'Private'.
       (Fixes the issue where Windows Firewall blocks WinRM on 'Public' networks).
    2. Enables and starts the WinRM Service (PSRemoting).
    3. Verifies connectivity.

    Run this ONCE on any fresh VM before attempting the assignment.
#>

# 1. SAFETY & HYGIENE
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Check for Admin Rights
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Throw "CRITICAL: You must run this script as Administrator."
}

Write-Host "--- BarmBuzz Network, PSRemoting & RSAT Prep ---" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 2. NETWORK CATEGORY (The Firewall Fix)
# ---------------------------------------------------------------------------
# Problem: Fresh VMs often treat the network as 'Public'.
# Consequence: Windows Firewall blocks WinRM (Port 5985).
# Fix: Force it to 'Private'.

Write-Host "[*] Checking Network Connection Profiles (all connected NICs)..." -ForegroundColor Yellow
$profiles = Get-NetConnectionProfile | Where-Object {
    $_.IPv4Connectivity -ne 'NoTraffic' -and (
        -not ($_.PSObject.Properties.Name -contains 'NetworkConnectivityLevel') -or
        $_.NetworkConnectivityLevel -ne 'Disconnected'
    )
}
if (-not $profiles) {
    Write-Host "    [-] No active connection profiles found." -ForegroundColor Yellow
} else {
    foreach ($p in $profiles) {
        if ($p.NetworkCategory -ne 'Private') {
            Write-Host "    Changing '$($p.Name)' (Idx $($p.InterfaceIndex)) from $($p.NetworkCategory) -> Private" -ForegroundColor Gray
            Set-NetConnectionProfile -InterfaceIndex $p.InterfaceIndex -NetworkCategory Private -ErrorAction Stop
        } else {
            Write-Host "    '$($p.Name)' already Private." -ForegroundColor Green
        }
    }
}

# ---------------------------------------------------------------------------
# 3. WINRM SERVICE (The SOAP Messages over HTTP/HTTPS)
# ---------------------------------------------------------------------------
# Problem: WinRM is disabled by default on Windows Client OS (Win10/11).
# Fix: Enable-PSRemoting handles the service start and firewall exceptions.

Write-Host "`n[*] Configuring Windows Remote Management (WinRM)..." -ForegroundColor Yellow

# -SkipNetworkProfileCheck: We fixed the profile above, but this double-checks safety.
# -Force: Suppress "Are you sure?" prompts.
Enable-PSRemoting -SkipNetworkProfileCheck -Force

# ---------------------------------------------------------------------------
# 4. VERIFICATION - As with all IAC, verify your work
# ---------------------------------------------------------------------------
Write-Host "`n[*] Verifying Connectivity..." -ForegroundColor Yellow

Try {
    # Test-WSMan sends a 'Hello' packet to the local WinRM service.
    $Test = Test-WSMan -ErrorAction Stop
    Write-Host "    [+] WinRM is responding! (Protocol Version: $($Test.ProductVersion))" -ForegroundColor Green
    Write-Host "    [+] Ready for Orchestration." -ForegroundColor Green
}
Catch {
    Write-Error "    [-] WinRM Failed to respond. Check if the 'Windows Remote Management' service is running."
}

# ---------------------------------------------------------------------------
# 5. RSAT INSTALL (AD + GPO tooling) with OS detection via WinPS (5.1)
# ---------------------------------------------------------------------------
Write-Host "`n[*] Ensuring RSAT tools (AD + GPO) are installed..." -ForegroundColor Yellow

function Invoke-WinPSCommand {
    param([Parameter(Mandatory)][string]$Script)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"$Script`""
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    $null = $p.Start()
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    return [pscustomobject]@{ ExitCode = $p.ExitCode; StdOut = $out; StdErr = $err }
}

$osProductType = (Get-CimInstance Win32_OperatingSystem).ProductType  # 1=Client, 2=Domain Controller, 3=Server
if ($osProductType -eq 1) {
    # Windows Client: use Windows Capabilities
    $clientScript = @'
Try {
    Add-WindowsCapability -Online -Name RSAT.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0 -ErrorAction Stop | Out-Null
    Add-WindowsCapability -Online -Name Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0 -ErrorAction Stop | Out-Null
    Write-Output ''RSAT capabilities installed (client).''
} Catch { Write-Error $_ }
'@
    $r = Invoke-WinPSCommand -Script $clientScript
    if ($r.ExitCode -ne 0) {
        Write-Warning "RSAT install (client) may have failed. StdErr: $($r.StdErr)"
    } else {
        Write-Host "    [+] RSAT (client) processed." -ForegroundColor Green
    }
}
else {
    # Windows Server: use Windows Features
    $serverScript = @'
Try {
    Import-Module ServerManager -ErrorAction Stop
    Install-WindowsFeature RSAT-AD-PowerShell -ErrorAction Stop | Out-Null
    Install-WindowsFeature GPMC -ErrorAction Stop | Out-Null
    Write-Output ''RSAT features installed (server).''
} Catch { Write-Error $_ }
'@
    $r = Invoke-WinPSCommand -Script $serverScript
    if ($r.ExitCode -ne 0) {
        Write-Warning "RSAT install (server) may have failed. StdErr: $($r.StdErr)"
    } else {
        Write-Host "    [+] RSAT (server) processed." -ForegroundColor Green
    }
}

Write-Host "[+] Network/Remoting/RSAT baseline complete." -ForegroundColor Green