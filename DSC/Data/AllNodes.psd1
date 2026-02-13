<#
CYBERSECURITY WARNING: NO CREDENTIALS IN THIS FILE

This data file is committed to Git. NEVER put passwords, API keys, or secrets here.

ACCEPTABLE DATA (safe to commit):
- Domain names, server names, IP addresses
- Feature lists, role configurations
- Non-sensitive metadata (OU names, group names)
- Certificate thumbprints (public info, not the private key!)

NEVER COMMIT:
- Passwords (plaintext or "obfuscated")
- Connection strings with embedded credentials
- API keys, tokens, or access secrets
- Private keys or PFX files with passwords

WHY THIS MATTERS (Security Mindset):
1. Git History is Permanent: Even if you delete a secret later, it's in the commit history forever
2. Public Repos: Students often make repos public for portfolios - instant breach
3. Credential Scanners: GitHub, GitLab, and Bitbucket scan for secrets automatically
4. Professional Consequences: Companies fire employees for committing secrets (real incidents)

Real-world example (2021): Uber engineer committed AWS keys to GitHub.
Cost: $100k AWS bill before discovered, engineer terminated, company fined.

WHAT TO DO INSTEAD:
- Orchestrator (Run_BuildMain.ps1) handles credential creation securely
- Credentials passed at runtime, never stored in files
- Production: Use Azure KeyVault, AWS Secrets Manager, HashiCorp Vault
- DSC supports certificate encryption for MOF files (we'll cover this later)

IF YOU NEED CREDENTIALS FOR TESTING:
- See Documentation\README.md for the fixed lab passwords
- Use them MANUALLY in PowerShell sessions ONLY
- NEVER put them in code or data files

This is not just a rule - this is professional survival.
#>

@{
    AllNodes = @(
        @{
            NodeName   = 'localhost'
            Role       = 'DC'
            DomainName = 'bolton.barmbuzz.test'
            
            # Network Configuration (Dual NIC setup for DC)
            InterfaceAlias_Internal = 'Ethernet'
            InterfaceAlias_NAT = 'Ethernet 2'
            IPv4Address_Internal = '192.168.99.10'
            PrefixLength_Internal = 24
            DnsServers_Internal = @('127.0.0.1')
            Expect_NAT_Dhcp = $true
            DisableDnsRegistrationOnNat = $true
            
            # AD DS Features
            InstallADDSRole = $true
            InstallRSATADDS = $true
            
            # SECURITY NOTE: Future credential properties will be added by the orchestrator
            # at runtime, not stored here. Example (YOU DON'T ADD THIS YET):
            # DomainCredential = $PSCredentialObject  # Injected by Run_BuildMain.ps1
            
            # CERTIFICATE ENCRYPTION (Production pattern - informational for now):
            # CertificateFile = 'C:\Certs\DscPublicKey.cer'  # Public key for MOF encryption
            # Thumbprint = '1234567890ABCDEF...'            # Certificate thumbprint
            # PsDscAllowPlainTextPassword = $false           # Force encryption (production)
        }
    )
}
