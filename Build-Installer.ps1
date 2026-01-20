#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Build script to create the Claude Code Installer EXE
.DESCRIPTION
    This script packages the PowerShell installer into a standalone executable
#>

[CmdletBinding()]
param(
    [string]$OutputPath = ".\build",
    [string]$OutputName = "ClaudeCodeInstaller.exe",
    [string]$IconFile = ".\InterWorks-Logo.ico"  # Path to your company logo .ico file
)

Write-Host "Building Claude Code Installer..." -ForegroundColor Cyan
Write-Host ""

# Check if ps2exe module is installed
$ps2exeInstalled = Get-Module -ListAvailable -Name ps2exe

if (-not $ps2exeInstalled) {
    Write-Host "ps2exe module is not installed. Installing..." -ForegroundColor Yellow
    try {
        Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber
        Write-Host "ps2exe module installed successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to install ps2exe module: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please install manually using:" -ForegroundColor Yellow
        Write-Host "  Install-Module -Name ps2exe -Scope CurrentUser" -ForegroundColor White
        exit 1
    }
}

# Import ps2exe module
Import-Module ps2exe

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

$outputFile = Join-Path $OutputPath $OutputName
$scriptPath = ".\Install-ClaudeCode.ps1"

Write-Host "Converting PowerShell script to EXE..." -ForegroundColor Cyan

try {
    # Check if icon file exists
    $useIcon = $false
    if ($IconFile -and (Test-Path $IconFile)) {
        $useIcon = $true
        Write-Host "Using custom icon: $IconFile" -ForegroundColor Green
    }
    elseif ($IconFile) {
        Write-Host "Warning: Icon file not found at '$IconFile', building without custom icon" -ForegroundColor Yellow
    }

    # Build parameters for ps2exe
    $ps2exeParams = @{
        InputFile = $scriptPath
        OutputFile = $outputFile
        NoConsole = $false
        NoOutput = $false
        NoError = $false
        RequireAdmin = $true
        Title = "Claude Code Installer"
        Description = "Automated installer for Claude Code CLI and VSCode extension"
        Company = "InterWorks"
        Product = "Claude Code Installer"
        Copyright = "Copyright © $(Get-Date -Format yyyy) InterWorks"
        Version = "1.1.0.0"
        Verbose = $true
    }

    # Add IconFile if it exists
    if ($useIcon) {
        $ps2exeParams['IconFile'] = $IconFile
    }

    Invoke-PS2EXE @ps2exeParams

    if (Test-Path $outputFile) {
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
        Write-Host "  Build Successful!" -ForegroundColor Green
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
        Write-Host ""
        Write-Host "Installer created at: $outputFile" -ForegroundColor White
        Write-Host "File size: $([math]::Round((Get-Item $outputFile).Length / 1MB, 2)) MB" -ForegroundColor Gray
        Write-Host ""
    }
    else {
        Write-Host "Build failed: Output file was not created" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "Error building installer: $_" -ForegroundColor Red
    exit 1
}
