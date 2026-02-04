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

Write-Host "--- BarmBuzz Network & Remoting Prep ---" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 2. NETWORK CATEGORY (The Firewall Fix)
# ---------------------------------------------------------------------------
# Problem: Fresh VMs often treat the network as 'Public'.
# Consequence: Windows Firewall blocks WinRM (Port 5985).
# Fix: Force it to 'Private'.

Write-Host "[*] Checking Network Connection Profile..." -ForegroundColor Yellow
$Connection = Get-NetConnectionProfile

if ($Connection.NetworkCategory -ne 'Private') {
    Write-Host "    Current Profile: $($Connection.NetworkCategory). Changing to Private..." -ForegroundColor Gray
    
    # We use -Force to suppress prompts
    Set-NetConnectionProfile -InterfaceIndex $Connection.InterfaceIndex -NetworkCategory Private
    
    Write-Host "    [+] Network is now Private." -ForegroundColor Green
} else {
    Write-Host "    [+] Network is already Private." -ForegroundColor Green
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

# Pause so they can see the green text
# Read-Host "`nPress Enter to exit"