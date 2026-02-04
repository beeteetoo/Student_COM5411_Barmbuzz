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