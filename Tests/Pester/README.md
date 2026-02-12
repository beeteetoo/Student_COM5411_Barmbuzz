# Tests (Pester Validation)

This folder contains the validation tests for COM5411 (BarmBuzz).  
You use these tests to confirm your build is correct and to create evidence for your submission.

**You are NOT expected to write tests** (unless explicitly told).  
You ARE expected to **RUN them, interpret the output, and commit the results to Git**.

---

## 1. What These Tests Do

There are two kinds of tests you will see in this module:

### 1.1 Pre-flight Tests (Environment + Inputs)
These check that your repo is structured correctly and your environment is ready BEFORE a build.

**Example:** `Preflight-Environment.Tests.ps1`
- Checks PowerShell 7 is installed
- Verifies you're running as Administrator
- Confirms DSC modules are installed
- Validates RSAT tools are present
- Tests WinRM connectivity

### 1.2 Post-build Tests (Verification)
These check that the configuration actually achieved the intended state AFTER the build.

**Example:** `Test-ProofOfLife.Tests.ps1`
- Verifies `C:\TEST\test.txt` exists and has the correct contents
- Confirms DSC configuration was applied successfully

---

## 2. Where the Tests Live

- Pester tests live in: `Tests\Pester\`
- Test files **must** end with: `.Tests.ps1` (Pester convention)
- Test runner: `Invoke-Validation.ps1` (our test harness)

**Structure:**
```
Tests\Pester\
├── Invoke-Validation.ps1       ← Test runner (USE THIS!)
├── Preflight-Environment.Tests.ps1
├── Test-ProofOfLife.Tests.ps1
└── README.md                   ← You are here
```

---

## 3. How to Run Tests (The Easy Way)

**IMPORTANT:** Always run these commands from the **REPO ROOT** (the folder that contains `Run_BuildMain.ps1`).

### 3.1 Setup (One Time)
1. Open **PowerShell 7** as Administrator
2. Navigate to your repo:
   ```powershell
   cd C:\Dev\code-repos\Student_COM5411_Barmbuzz
   ```

### 3.2 Run All Tests (Recommended)
Use the test harness to run all tests in one go:

```powershell
.\Tests\Pester\Invoke-Validation.ps1
```

**What happens:**
- Discovers all `*.Tests.ps1` files in `Tests\Pester\`
- Runs them with detailed output
- Creates an XML result file in `Evidence\Pester\`
- Returns exit code 0 (success) or 1 (failure)

### 3.3 Run Specific Tests
Run one or more specific test files:

```powershell
# Run just the preflight tests
.\Tests\Pester\Invoke-Validation.ps1 .\Tests\Pester\Preflight-Environment.Tests.ps1

# Run multiple specific tests
.\Tests\Pester\Invoke-Validation.ps1 .\Tests\Pester\Preflight-Environment.Tests.ps1 .\Tests\Pester\Test-ProofOfLife.Tests.ps1
```

### 3.4 Run Tests Without Result Files
Skip creating XML result files (useful during development):

```powershell
.\Tests\Pester\Invoke-Validation.ps1 -NoResultFile
```

### 3.5 Change Output Verbosity
Control how much detail you see:

```powershell
# Less detail (default: Detailed)
.\Tests\Pester\Invoke-Validation.ps1 -Output Normal

# Maximum detail (for debugging)
.\Tests\Pester\Invoke-Validation.ps1 -Output Diagnostic
```

---

## 4. Understanding Test Output

### 4.1 Green = Success ✅
```
[+] Must be run from PowerShell 7 (pwsh) (this is the orchestration shell) 5ms (2ms|3ms)
```
✅ Test passed

### 4.2 Red = Failure ❌
```
[-] Windows PowerShell 5.1: ActiveDirectory module is available 341ms (340ms|1ms)
    RuntimeException: RSAT AD tools missing: ActiveDirectory module not found in Windows PowerShell 5.1.
```
❌ Test failed - read the error message for guidance

### 4.3 Yellow/Skipped = Informational ⚠️
```
[!] PowerShell 7: GroupPolicy module discoverable (informational) is skipped
```
⚠️ Test was skipped (usually intentional)

### 4.4 Summary
```
Tests completed in 4.98s
Tests Passed: 25, Failed: 0, Skipped: 1, Inconclusive: 0, NotRun: 0
```
**Goal:** `Failed: 0` (all green!)

---

## 5. Common Workflows

### 5.1 Before Starting Work (Preflight)
```powershell
# Check your environment is ready
.\Tests\Pester\Invoke-Validation.ps1 .\Tests\Pester\Preflight-Environment.Tests.ps1
```

**If tests fail:**
1. Read the error message carefully
2. Most errors tell you to run `.\Run_BuildMain.ps1` first
3. Re-run the test after fixing

### 5.2 After Running Your Build
```powershell
# 1. Run your orchestrator
.\Run_BuildMain.ps1

# 2. Validate the results
.\Tests\Pester\Invoke-Validation.ps1

# 3. Commit evidence
git add Evidence\Pester\*.xml
git commit -m "Evidence: Test results for build $(Get-Date -Format 'yyyy-MM-dd')"
```

### 5.3 Before Submission
```powershell
# Run everything one final time
.\Tests\Pester\Invoke-Validation.ps1

# Verify test results exist
Get-ChildItem Evidence\Pester\*.xml | Select-Object Name, LastWriteTime

# Commit and push
git add Evidence\Pester\
git commit -m "Final evidence: All tests passing"
git push
```

---

## 6. Writing Your Own Tests (Advanced)

**⚠️ Only do this if explicitly instructed by your tutor.**

### 6.1 Pester v5 Basics
Pester v5 uses a structured syntax with `Describe`, `Context`, and `It` blocks.

**Simple Example:**
```powershell
# MyTest.Tests.ps1
Describe "My Custom Validation" {
    
    It "Should find the test file" {
        Test-Path "C:\TEST\test.txt" | Should -BeTrue
    }
    
    It "Should have correct content" {
        $content = Get-Content "C:\TEST\test.txt" -Raw
        $content | Should -Match "BarmBuzz"
    }
}
```

### 6.2 Test Structure (Pester v5)
```powershell
# MyAdvanced.Tests.ps1

Describe "My Advanced Test Suite" {
    
    # BeforeAll runs ONCE before all tests (setup)
    BeforeAll {
        # IMPORTANT: The test harness automatically injects these for you!
        param(
            $RepoRoot,      # Path to repo root (where Run_BuildMain.ps1 lives)
            $EvidenceDir    # Path to Evidence\Pester folder
        )
        
        # Store them in script scope so all tests can use them
        $script:repoRoot = $RepoRoot
        $script:evidenceDir = $EvidenceDir
        
        # Your test-specific variables
        $script:TestPath = "C:\TEST"
        $script:ExpectedFile = Join-Path $TestPath "test.txt"
    }
    
    # Context groups related tests
    Context "File System Checks" {
        
        It "Test folder should exist" {
            Test-Path $script:TestPath | Should -BeTrue
        }
        
        It "Test file should exist" {
            Test-Path $script:ExpectedFile | Should -BeTrue
        }
        
        It "Repo root was injected correctly" {
            $script:repoRoot | Should -Not -BeNullOrEmpty
            Test-Path (Join-Path $script:repoRoot "Run_BuildMain.ps1") | Should -BeTrue
        }
    }
    
    Context "Content Validation" {
        
        It "File should not be empty" {
            $content = Get-Content $script:ExpectedFile -Raw
            $content | Should -Not -BeNullOrEmpty
        }
        
        It "File should contain expected text" {
            $content = Get-Content $script:ExpectedFile -Raw
            $content | Should -Match "BarmBuzz"
        }
    }
}
```

**KEY POINTS:**
- **`param($RepoRoot, $EvidenceDir)`** in `BeforeAll` receives injected values from the harness
- **You don't need to calculate repo paths yourself** - they're provided automatically
- **Legacy support:** If you run the test file directly (not via harness), you'll need fallback logic
- **`$script:` scope** makes variables available to all tests in the file

### 6.3 Common Pester Assertions
```powershell
# Equality
$value | Should -Be "expected"
$value | Should -Not -Be "unexpected"

# Type checks
$object | Should -BeOfType [string]

# Boolean checks
$result | Should -BeTrue
$result | Should -BeFalse

# Null checks
$value | Should -BeNullOrEmpty
$value | Should -Not -BeNullOrEmpty

# Pattern matching
$text | Should -Match "pattern"
$text | Should -MatchExactly "CaseSensitive"

# File/Path checks
$path | Should -Exist
$path | Should -Not -Exist

# Collection checks
$array | Should -Contain "item"
$array | Should -HaveCount 5
```

### 6.4 Running Your Custom Test
Once you've created `MyTest.Tests.ps1` in `Tests\Pester\`:

```powershell
# Our test harness will find it automatically
.\Tests\Pester\Invoke-Validation.ps1

# Or run it directly
.\Tests\Pester\Invoke-Validation.ps1 .\Tests\Pester\MyTest.Tests.ps1
```

### 6.5 Best Practices for Test Writing

**DO:**
- ✅ Name files with `.Tests.ps1` suffix
- ✅ Use descriptive test names (the `It` string)
- ✅ Group related tests in `Context` blocks
- ✅ Use `BeforeAll` for setup that runs once
- ✅ Test one thing per `It` block
- ✅ Include helpful error messages

**DON'T:**
- ❌ Modify system state in tests (tests should be read-only)
- ❌ Depend on test execution order
- ❌ Use external dependencies unless necessary
- ❌ Write tests that take forever to run

**Example with Good Practices:**
```powershell
Describe "Domain Controller Validation" {
    
    BeforeAll {
        $script:DCName = "DC01"
        $script:DomainName = "barmbuzz.local"
    }
    
    Context "Active Directory Domain Services" {
        
        It "Domain Controller should be reachable" {
            $ping = Test-Connection $script:DCName -Count 1 -Quiet
            if (-not $ping) {
                throw "DC01 is not reachable. Check network connectivity."
            }
            $ping | Should -BeTrue
        }
        
        It "Domain should be operational" {
            $domain = Get-ADDomain -ErrorAction SilentlyContinue
            if (-not $domain) {
                throw "Domain $($script:DomainName) is not accessible. Has ADDS been installed?"
            }
            $domain.Name | Should -Be $script:DomainName
        }
    }
}
```

---

## 7. Troubleshooting

### Problem: "The property 'X' cannot be found on this object"
**Cause:** Pester v5 scoping issue  
**Fix:** Check if you're using `$script:` prefix for variables in test bodies

### Problem: "Tests not found"
**Cause:** File doesn't end with `.Tests.ps1`  
**Fix:** Rename your file: `MyTests.ps1` → `MyTests.Tests.ps1`

### Problem: "Module Pester not found"
**Cause:** Pester not installed  
**Fix:** Run `.\Run_BuildMain.ps1` (it installs Pester 5.7.1)

### Problem: Tests pass locally but fail in CI/automation
**Cause:** Environment differences  
**Fix:** Run preflight tests first to validate environment

### Problem: "Access Denied" errors
**Cause:** Not running as Administrator  
**Fix:** Right-click PowerShell 7 → Run as Administrator

---

## 8. Evidence and Submission

### What Gets Committed to Git
```
Evidence\Pester\
├── PesterResults_20260212_111453.xml
├── PesterResults_20260212_112517.xml
└── PesterResults_20260212_112941.xml
```

These XML files are **proof you ran the tests** and **show the results**.

### Before You Submit
```powershell
# 1. Run all tests
.\Tests\Pester\Invoke-Validation.ps1

# 2. Check for failures
# Output should say: "Tests Passed: X, Failed: 0"

# 3. Add evidence
git add Evidence\Pester\

# 4. Commit with meaningful message
git commit -m "Evidence: All validation tests passing"

# 5. Push to remote
git push origin main
```

Your tutor will review:
- ✅ Test result XML files in `Evidence\Pester\`
- ✅ Whether all tests passed (0 failures)
- ✅ Timestamps showing when tests were run

---

## 9. Quick Reference

| Task | Command |
|------|---------|
| Run all tests | `.\Tests\Pester\Invoke-Validation.ps1` |
| Run specific test | `.\Tests\Pester\Invoke-Validation.ps1 .\Tests\Pester\MyTest.Tests.ps1` |
| Run without XML output | `.\Tests\Pester\Invoke-Validation.ps1 -NoResultFile` |
| Run with minimal output | `.\Tests\Pester\Invoke-Validation.ps1 -Output Normal` |
| Check preflight | `.\Tests\Pester\Invoke-Validation.ps1 .\Tests\Pester\Preflight-Environment.Tests.ps1` |
| View results | `Get-ChildItem Evidence\Pester\*.xml \| Sort-Object LastWriteTime` |

---

## 10. Further Reading

- **Pester Documentation:** https://pester.dev/docs/quick-start
- **Pester v5 Migration:** https://pester.dev/docs/migrations/v4-to-v5
- **Should Assertions:** https://pester.dev/docs/commands/Should

---

**Remember:** Tests are here to **help you succeed**, not trip you up.  
If tests fail, they're telling you what needs fixing. Read the error messages carefully! 🎓
