<#
.SYNOPSIS
    COM5411 Student Repo Scaffold (BarmBuzz) - with detailed root README.md

.DESCRIPTION
    Creates the STUDENT repository structure with empty placeholder files.
    Writes a detailed root README.md so students have all instructions up front.

    Students edit ONLY:
      - DSC\Configurations\StudentConfig.ps1
      - DSC\Data\AllNodes.psd1

    Evidence and outputs are TRACKED IN GIT (per module requirement):
      - DSC\Outputs\
      - Evidence\

.NOTES
    This scaffold intentionally includes no “hidden tutor tests”.
    Validation will be added later by the tutor under Tests\Pester\.

.USAGE
    1) Create an empty folder for the repo.
    2) Open PowerShell in that folder.
    3) Run:  .\New-BarmBuzzStudentRepo.ps1
#>

[CmdletBinding()]
param(
    [switch]$CreateGitignore
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Get-Location

# ------------------------------------------------------------------------------------
# 1) FOLDER STRUCTURE (STUDENT REPO)
# ------------------------------------------------------------------------------------
$folders = @(
    ".",
    "Documentation",
    "Scripts",
    "Scripts\Helpers",
    "Scripts\Prereqs",
    "DSC",
    "DSC\Configurations",
    "DSC\Data",
    "DSC\Outputs",                 # TRACKED
    "Tests",
    "Tests\Pester",                # tutor-provided validation harness lives here
    "Evidence",                    # TRACKED
    "Evidence\Transcripts",
    "Evidence\Pester",
    "Evidence\DSC",
    "Evidence\AD",
    "Evidence\GPOBackups",
    "Evidence\HealthChecks",
    "Evidence\Network",
    "Evidence\Screenshots",
    "Evidence\Git\Reflog",
    "Evidence\AI_LOG"
)

foreach ($folder in $folders) {
    $path = Join-Path $root $folder
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Write-Host "Created: $folder" -ForegroundColor Green
    } else {
        Write-Host "Exists:  $folder" -ForegroundColor Gray
    }
}

# ------------------------------------------------------------------------------------
# 2) FILES (placeholders + stubs)
# ------------------------------------------------------------------------------------
$files = @(
    "README.md",

    "Documentation\README.md",
    "Documentation\Runbook.md",
    "Documentation\DesignNotes.md",

    "Run_BuildMain.ps1",

    "Scripts\Prereqs\BarmBuzz_OneShot_LCM.ps1",
    "Scripts\Helpers\Invoke-BarmBuzzEvidencePack.ps1",

    "DSC\Configurations\StudentConfig.ps1",
    "DSC\Data\AllNodes.psd1",

    "Tests\Pester\README.md",
    "Tests\Pester\Invoke-Validation.ps1",

    # ensure tracked
    "DSC\Outputs\.keep",
    "Evidence\README.md",
    "Evidence\Transcripts\.keep",
    "Evidence\Pester\.keep",
    "Evidence\DSC\.keep",
    "Evidence\AD\.keep",
    "Evidence\GPOBackups\.keep",
    "Evidence\HealthChecks\.keep",
    "Evidence\Network\.keep",
    "Evidence\Screenshots\.keep",
    "Evidence\Git\Reflog\.keep",
    "Evidence\AI_LOG\AI-Usage.md"
)

foreach ($file in $files) {
    $filePath = Join-Path $root $file
    if (-not (Test-Path $filePath)) {
        $parent = Split-Path -Parent $filePath
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        New-Item -ItemType File -Path $filePath -Force | Out-Null
        Write-Host "Created File: $file" -ForegroundColor Cyan
    } else {
        Write-Host "Exists File:  $file" -ForegroundColor Gray
    }
}

# ------------------------------------------------------------------------------------
# 3) CONTENT HELPERS
# ------------------------------------------------------------------------------------
function Set-IfEmpty {
    param([string]$Path, [string]$Content)
    if ((Get-Item $Path).Length -eq 0) {
        Set-Content -Path $Path -Value $Content -Encoding UTF8
    }
}

# ------------------------------------------------------------------------------------
# 4) ROOT README (DETAILED, ALL INSTRUCTIONS UP FRONT)
# ------------------------------------------------------------------------------------
Set-IfEmpty (Join-Path $root "README.md") @"
# COM5411 Enterprise Operating Systems (BarmBuzz) – Student Repository

This repository is the single source of truth for your build, your evidence, and your assessment submission.

If you follow the instructions in this file exactly, you will produce:
- A repeatable infrastructure build (IaC approach using DSC as the automation engine)
- A consistent evidence trail in Git (to protect you from allegations of contract cheating)
- A structure that matches the assessment ZIP layout

---

## 0) The One-Rule Workflow

You do **NOT** run a random set of commands.

You run **one entry script**:

**`Run-BarmBuzz.ps1`**

That script will do everything in this order:
1. Environment checks (admin, paths, folder structure)
2. Prerequisites setup (tutor-provided)
3. Compile + apply DSC configuration (your work)
4. Validation (tutor-provided tests)

If something fails, you fix the issue and run `Run_BuildMain.ps1` again.

---

## 1) What You Must Edit (and what you must NOT touch)

You edit **ONLY** these two files:

1. `DSC\Configurations\StudentConfig.ps1`  
   Your DSC configuration logic (the “what to build”)

2. `DSC\Data\AllNodes.psd1`  
   Your configuration data (the “values for this environment”)

Everything else in this repo is tutor-provided scaffolding or evidence structure.
Do not rename folders. Do not invent your own structure. Marking assumes these paths.

---

## 2) Passwords and Accounts (Fixed for this lab)

To reduce mistakes and speed up support, this module uses fixed lab credentials.

### 2.1 Built-in Administrator (Windows)
- Username: **Administrator**
- Password: **superw1n_user**

This is the account used for administration tasks during the build.

### 2.2 End-user accounts you create
All end-user accounts you create for the scenario must use:
- Password: **notlob2k26**

### 2.3 Important: do not improvise passwords
If you use different passwords, you will break automation runs and support will not debug it.

### 2.4 Important: do not place passwords into your config/data files
You must not hardcode passwords into `StudentConfig.ps1` or `AllNodes.psd1`.
The orchestrator will handle credentials (we will provide the mechanism).

For now (Week 1), you are allowed to use the fixed passwords manually if needed.
Once the secrets mechanism is provided, you must use it.

---

## 3) What Must Be Committed to Git (Evidence Discipline)

This module has an explicit anti-contract-cheating design: your Git history is part of your evidence.

You MUST commit:
- Your changes to `StudentConfig.ps1` and `AllNodes.psd1`
- Outputs under `DSC\Outputs\`
- Evidence under `Evidence\`

This is deliberate. These are the artefacts that prove *you* ran the build and generated outputs.

### What goes where

- `DSC\Outputs\`
  Compiled configuration outputs (e.g., MOF files). Generated when you run the build.

- `Evidence\Transcripts\`
  PowerShell transcripts from build runs (proof you executed the pipeline).

- `Evidence\DSC\`
  DSC build logs, apply outputs, and any staging artefacts.

- `Evidence\Pester\`
  Validation outputs (later) from tutor-provided tests.

- `Evidence\AD\`
  Exports/snapshots of AD objects and directory state (later).

- `Evidence\GPOBackups\`
  Backups/exports of GPOs (later).

- `Evidence\HealthChecks\`
  Health check outputs (dcdiag/repadmin summaries etc., later).

- `Evidence\Network\`
  Evidence for DNS/time/IP configuration (because most failures are networking).

- `Evidence\Git\Reflog\`
  Evidence of your Git activity as required.

- `Evidence\AI_LOG\AI-Usage.md`
  You must log any AI usage here, including what you changed afterwards.

---

## 4) First-Time Setup (Week 1 baseline)

### Step A: Create your repo and first commit
From the repo root:

1. `git init`
2. `git add .`
3. `git commit -m "Initial scaffold"`

### Step B: Open PowerShell as Administrator
You must run builds as Administrator.

- Start Menu → PowerShell → Right-click → Run as Administrator
- Then `cd` into your repo folder

### Step C: Run the orchestrator (placeholder for now)
Run:

`.\Run-BarmBuzz.ps1`

Right now the orchestrator is a placeholder in this scaffold.
Your tutor will provide the working orchestrator and prerequisite scripts.

---

## 5) Your Work Each Week (the pattern)

Each week you will:
1. Edit `AllNodes.psd1` to describe the desired environment (data)
2. Edit `StudentConfig.ps1` to implement the desired environment (configuration)
3. Run `Run-BarmBuzz.ps1` to compile/apply
4. Review outputs written into `DSC\Outputs\` and `Evidence\`
5. Commit the changes and generated outputs to Git

Your commits should be small and meaningful:
- "Add OU structure for Corp"
- "Add groups GG-Staff and GG-IT-Admins"
- "Link baseline GPO to Workstations OU"

---

## 6) Common Failure Modes (read this before asking for help)

1. You did not run PowerShell as Administrator  
   Result: DSC cannot apply config, AD install fails, permission errors.

2. You edited files outside the two student files  
   Result: merge conflicts, broken scaffolding, unexpected marking failures.

3. Your folder names don’t match the scaffold  
   Result: build scripts cannot find assets; evidence is not where expected.

4. You used different passwords  
   Result: scripts break, users cannot authenticate, support cannot reproduce.

5. You did not commit generated evidence  
   Result: you lose proof of work and may be challenged on authenticity.

---

## 7) Minimal Student Responsibilities (Pass-focused)

To pass you must show:
- A working automated build pipeline (repeatable runs)
- Correct AD structures (OUs/users/groups) driven from your code/data
- Evidence outputs committed to Git
- Validation outputs (later, tutor-provided tests)

Higher grades add extra architecture and security sophistication, but a pass is achievable with the baseline.

---

## 8) Where to Start Right Now

Open:
- `DSC\Data\AllNodes.psd1`
- `DSC\Configurations\StudentConfig.ps1`

Week 1 goal:
- Make a tiny, safe DSC resource work (e.g., create a folder, set a registry value).
This proves you can compile/apply and generate outputs and evidence.

Then you will expand toward AD DS, OUs, users, groups, and policy.

"@

# ------------------------------------------------------------------------------------
# 5) Other stub content
# ------------------------------------------------------------------------------------
Set-IfEmpty (Join-Path $root "Documentation\README.md") @"
# Documentation

Use these files for your written artefacts:
- Runbook.md: what you did, week by week
- DesignNotes.md: why you designed it this way
"@

Set-IfEmpty (Join-Path $root "Documentation\Runbook.md") @"
# Runbook (Student)

Keep a dated log of:
- what you changed
- what you ran (commands)
- where the evidence is stored (paths)
"@

Set-IfEmpty (Join-Path $root "Documentation\DesignNotes.md") @"
# Design Notes (Student)

Explain your decisions:
- OU structure rationale
- Group model rationale
- GPO linking choices (later)
- Any security controls you applied
"@

Set-IfEmpty (Join-Path $root "DSC\Configurations\StudentConfig.ps1") @"
<#
STUDENT TASK:
- Define Configuration StudentBaseline
- Use ConfigurationData (AllNodes.psd1)
- DO NOT hardcode passwords here.
#>

Configuration StudentBaseline {
    param()

    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node `$AllNodes.NodeName {

        # WEEK 1:
        # Put a simple resource here to prove the pipeline works.
        # Examples:
        # - File resource to create a folder
        # - Registry resource to set a harmless key/value
        #
        # WEEK 2+:
        # Expand toward AD DS, DNS, domain build, then OU/users/groups.
    }
}
"@

Set-IfEmpty (Join-Path $root "DSC\Data\AllNodes.psd1") @"
@{
    AllNodes = @(
        @{
            NodeName   = 'localhost'
            Role       = 'DC'
            DomainName = 'bolton.barmbuzz.test'
        }
    )
}
"@

Set-IfEmpty (Join-Path $root "Tests\Pester\README.md") @"
# Validation Tests (Tutor-Provided)

You will run:
- Tests\Pester\Invoke-Validation.ps1

Outputs will be written under:
- Evidence\Pester\
"@

Set-IfEmpty (Join-Path $root "Tests\Pester\Invoke-Validation.ps1") @"
# Placeholder - tutor will supply later.
Write-Host 'Validation harness will be added by the tutor.'
"@

Set-IfEmpty (Join-Path $root "Evidence\AI_LOG\AI-Usage.md") @"
# AI Usage Log (AI_LOG)

Record any AI/tool usage:
- date/time
- tool used
- what it generated
- what you changed afterwards
"@

if ($CreateGitignore) {
    $gi = Join-Path $root ".gitignore"
    if (-not (Test-Path $gi)) { New-Item -ItemType File -Path $gi -Force | Out-Null }
    Set-IfEmpty $gi @"
# Evidence and Outputs are tracked by design.
# Do NOT ignore Evidence/ or DSC/Outputs/ here.

.vscode/
*.tmp
*.log
"@
    Write-Host "Created .gitignore (minimal; does not ignore Evidence/ or DSC/Outputs/)." -ForegroundColor Yellow
}

Write-Host "`nScaffold complete (STUDENT repo)." -ForegroundColor Yellow
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1) git init" -ForegroundColor Yellow
Write-Host "2) git add ." -ForegroundColor Yellow
Write-Host "3) git commit -m 'Initial scaffold'" -ForegroundColor Yellow
