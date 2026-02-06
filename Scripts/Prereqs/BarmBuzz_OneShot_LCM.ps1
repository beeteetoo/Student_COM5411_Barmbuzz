<#
.SYNOPSIS
    STAFF PROVIDED: Local Configuration Manager (LCM) Setup.
    
.DESCRIPTION
    Configures the DSC engine on Windows Server 2025 to handle 
    unattended reboots and persistent state.

    Student Responsibility: Students do not need to edit or explain this code.
    You need to ensure it is called as part of their "Execution Order" in the README
    and that it is executed before attempting to apply the BarmBuzz_DC01 configuration.

    This is a "One-Shot" script. It is idempotent; running it 
    multiple times will not damage the environment.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "--- [STAFF-ONLY] Configuring Persistent LCM Settings ---" -ForegroundColor Cyan

Configuration SetBarmBuzzLCM {
    Node "localhost" {
        LocalConfigurationManager {
            # Allows the server to restart itself to finish AD promotion 
            # Active Directory binaries and Domain Promotion both require 
            # reboots on Server 2025. This setting enables the "hands-off" 
            # experience required for Grade A/A*
            RebootNodeIfNeeded = $true
            
            # Ensures the build resumes automatically after reboot 
            # This is the most critical setting for the "Live Build". 
            # Without this, when the server reboots after becoming a Domain Controller, and would have to log in 
            # and manually re-run the script. 
            # With this setting, the Bolton DC build is truly automated.    
            ActionAfterReboot = 'ContinueConfiguration'
            
            # Prevents the configuration from 'drifting' after the build
            ConfigurationMode = 'ApplyOnly'
            
            # Critical for Grade C/B: Allows credential handling for AD 
            AllowModuleOverwrite = $true
        }
    }
}

# Compile the meta-config to a temporary location 
$TempPath = Join-Path $env:TEMP "LCM_Config"
if (-not (Test-Path $TempPath)) { New-Item -Path $TempPath -ItemType Directory | Out-Null }

SetBarmBuzzLCM -OutputPath $TempPath | Out-Null

# Apply settings to the local machine 
Write-Host "[*] Applying persistent automation settings..." -ForegroundColor Gray
Set-DscLocalConfigurationManager -Path $TempPath -Force

Write-Host "[+] LCM configured. Server is now reboot-ready." -ForegroundColor Green

# ---------------------------------------------------------------------------
# MODULE BASELINE (pinned installs via PSResourceGet)
# ---------------------------------------------------------------------------
Write-Host "[*] Ensuring DSC modules are installed/pinned (PSResourceGet) ..." -ForegroundColor Yellow

function Ensure-PSResourceGet {
    if (-not (Get-Module -ListAvailable Microsoft.PowerShell.PSResourceGet)) {
        throw "PSResourceGet missing. Install Microsoft.PowerShell.PSResourceGet before proceeding."
    }
}

function Install-PinnedModule {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][version]$Version,
        [string]$Destination = "C:\\Program Files\\WindowsPowerShell\\Modules"
    )
    Ensure-PSResourceGet
    $installed = Get-Module -ListAvailable -Name $Name | Where-Object { $_.Version -eq $Version }
    if ($installed) {
        Write-Host "    -> $Name@$Version already present (skipping)." -ForegroundColor Green
        return
    }
    Write-Host "    -> $Name@$Version" -ForegroundColor Gray
    Save-PSResource -Name $Name -Version $Version -Repository PSGallery -Path $Destination -TrustRepository -ErrorAction Stop | Out-Null
}

# Pinned versions per lab baseline
$Pinned = @{
    PSDesiredStateConfiguration = [version]'2.0.7'
    ActiveDirectoryDsc          = [version]'6.6.0'
    GroupPolicyDsc              = [version]'1.0.3'
    Pester                      = [version]'5.7.1'
}

foreach ($k in $Pinned.Keys) {
    Install-PinnedModule -Name $k -Version $Pinned[$k]
}

# Required (unpinned) extras
Save-PSResource -Name 'ComputerManagementDsc' -Repository PSGallery -Path 'C:\\Program Files\\WindowsPowerShell\\Modules' -TrustRepository -ErrorAction SilentlyContinue | Out-Null

Write-Host "[+] DSC module baseline ensured at C:\\Program Files\\WindowsPowerShell\\Modules." -ForegroundColor Green