#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Test script for Claude Code Installer validation
.DESCRIPTION
    Validates the installer in various scenarios and checks all components
#>

[CmdletBinding()]
param(
    [switch]$SkipCleanup
)

$TestResults = @()

function Test-Component {
    param(
        [string]$Name,
        [scriptblock]$Test
    )

    Write-Host "Testing: $Name..." -ForegroundColor Cyan -NoNewline

    try {
        $result = & $Test
        if ($result) {
            Write-Host " PASS" -ForegroundColor Green
            $script:TestResults += [PSCustomObject]@{
                Test = $Name
                Result = "PASS"
                Details = ""
            }
            return $true
        }
        else {
            Write-Host " FAIL" -ForegroundColor Red
            $script:TestResults += [PSCustomObject]@{
                Test = $Name
                Result = "FAIL"
                Details = ""
            }
            return $false
        }
    }
    catch {
        Write-Host " ERROR" -ForegroundColor Red
        $script:TestResults += [PSCustomObject]@{
            Test = $Name
            Result = "ERROR"
            Details = $_.Exception.Message
        }
        return $false
    }
}

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║      Claude Code Installer Test Suite                     ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check if Git is installed
Test-Component "Git Installation" {
    $gitVersion = git --version 2>$null
    return $null -ne $gitVersion
}

# Test 2: Check if Git Bash path is set
Test-Component "Git Bash Environment Variable" {
    $gitBashPath = [Environment]::GetEnvironmentVariable("CLAUDE_CODE_GIT_BASH_PATH", "User")
    if ($gitBashPath -and (Test-Path $gitBashPath)) {
        return $true
    }
    return $false
}

# Test 3: Check if local bin is in PATH
Test-Component "Local Bin in PATH" {
    $localBinPath = "$env:USERPROFILE\.local\bin"
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    return $userPath -like "*$localBinPath*"
}

# Test 4: Check if local bin directory exists
Test-Component "Local Bin Directory Exists" {
    $localBinPath = "$env:USERPROFILE\.local\bin"
    return Test-Path $localBinPath
}

# Test 5: Check if Claude CLI is installed
Test-Component "Claude CLI Installation" {
    $claudeVersion = claude --version 2>$null
    return $null -ne $claudeVersion
}

# Test 6: Check if VSCode is installed
Test-Component "VSCode Installation" {
    $codeVersion = code --version 2>$null
    return $null -ne $codeVersion
}

# Test 7: Check if Claude extension is installed
Test-Component "Claude VSCode Extension" {
    $extensions = code --list-extensions 2>$null
    return $extensions -contains "anthropics.claude-code"
}

# Test 8: Check if installer script exists
Test-Component "Installer Script Exists" {
    return Test-Path ".\Install-ClaudeCode.ps1"
}

# Test 9: Check if build script exists
Test-Component "Build Script Exists" {
    return Test-Path ".\Build-Installer.ps1"
}

# Test 10: PowerShell script syntax validation
Test-Component "PowerShell Script Syntax" {
    $scriptPath = ".\Install-ClaudeCode.ps1"
    $errors = $null
    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $scriptPath -Raw), [ref]$errors)
    return $errors.Count -eq 0
}

# Display Results Summary
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor White
Write-Host "Test Results Summary" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor White
Write-Host ""

$TestResults | Format-Table -AutoSize

$passCount = ($TestResults | Where-Object { $_.Result -eq "PASS" }).Count
$failCount = ($TestResults | Where-Object { $_.Result -eq "FAIL" }).Count
$errorCount = ($TestResults | Where-Object { $_.Result -eq "ERROR" }).Count
$totalCount = $TestResults.Count

Write-Host ""
Write-Host "Total Tests: $totalCount" -ForegroundColor White
Write-Host "Passed: $passCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor Red
Write-Host "Errors: $errorCount" -ForegroundColor Yellow
Write-Host ""

if ($failCount -eq 0 -and $errorCount -eq 0) {
    Write-Host "✓ All tests passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "✗ Some tests failed. Please review the results above." -ForegroundColor Red
    exit 1
}
