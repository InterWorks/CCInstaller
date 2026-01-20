# Quick Start Guide

Get your Claude Code installer up and running in 5 minutes.

## Step 1: Build the Installer

Open PowerShell as Administrator in this directory and run:

```powershell
.\Build-Installer.ps1
```

The installer will be created in the `.\build` directory.

## Step 2: Test the Installer

### Option A: Test on Your Current Machine

```powershell
# Run the built EXE
.\build\ClaudeCodeInstaller.exe
```

### Option B: Test with PowerShell Script Directly

```powershell
# Interactive mode (recommended for first test)
.\Install-ClaudeCode.ps1

# Or silent mode
.\Install-ClaudeCode.ps1 -Silent -InstallCLI -InstallExtension
```

## Step 3: Validate Installation

Run the test suite:

```powershell
.\Test-Installer.ps1
```

## Step 4: Deploy to Your Team

### Method 1: File Share (Simplest)

1. Copy `ClaudeCodeInstaller.exe` to a network share
2. Send your team an email with the download link
3. Instruct them to:
   - Download the file
   - Right-click → "Run as Administrator"
   - Follow the prompts

### Method 2: Group Policy (Best for Large Teams)

See [Advanced-WiX.md](Advanced-WiX.md) for MSI creation and GPO deployment.

### Method 3: Direct Distribution

Email the EXE directly or use your company's software distribution tool.

## Troubleshooting Quick Checks

### Issue: ps2exe module not found

```powershell
Install-Module -Name ps2exe -Scope CurrentUser -Force
```

### Issue: Build fails

Check that you have:
- PowerShell 5.1 or higher: `$PSVersionTable.PSVersion`
- Administrator privileges
- Internet access (for downloading ps2exe)

### Issue: Installation fails for users

Check the log file at `%TEMP%\ClaudeCodeInstaller.log`

Common causes:
- User didn't run as Administrator
- Node.js not installed (required for Claude CLI)
- Antivirus blocking execution

## What Your Users Will See

1. **Welcome Screen**:
   ```
   ╔════════════════════════════════════════════════════════════╗
   ║                                                            ║
   ║           Claude Code Installer for Windows               ║
   ║                                                            ║
   ╚════════════════════════════════════════════════════════════╝
   ```

2. **Menu Options**:
   - [1] Install Claude Code CLI
   - [2] Install VSCode + Claude Code Extension
   - [3] Install Both (CLI + VSCode Extension)
   - [4] Exit

3. **Installation Progress**: Real-time feedback with color-coded messages

4. **Completion Message**: Instructions to restart terminal/VSCode

## Pre-deployment Checklist

Before distributing to your team:

- [ ] Test on a clean Windows 11 VM
- [ ] Verify Git installation works
- [ ] Verify PATH is configured correctly
- [ ] Verify Claude CLI installs successfully
- [ ] Verify VSCode extension installs successfully
- [ ] Check installation log for errors
- [ ] Run test suite and ensure all tests pass
- [ ] Sign the EXE with your company certificate (optional but recommended)

## User Instructions Template

Copy and paste this for your team:

---

**Installing Claude Code**

1. Download [ClaudeCodeInstaller.exe](link-to-file)
2. Right-click the file and select "Run as Administrator"
3. Choose your installation option:
   - Option 1: CLI only (for terminal use)
   - Option 2: VSCode extension only
   - Option 3: Both (recommended)
4. Wait for installation to complete (5-10 minutes)
5. **Important**: Restart your terminal and VSCode
6. Test by running `claude` in your terminal

**Troubleshooting**:
- If `claude` command not found: Close and reopen your terminal
- If installation fails: Check that you ran as Administrator
- For other issues: Contact IT support with the log file from `%TEMP%\ClaudeCodeInstaller.log`

---

## Next Steps

- Customize the installer with your company branding
- Add your company's certificate for code signing
- Set up automated testing in your CI/CD pipeline
- Create an internal knowledge base article
- Monitor installation success rates and common issues

## Advanced Options

### Silent Deployment Script

For automated deployment across many machines:

```powershell
# Deploy-ClaudeCode.ps1
$installerPath = "\\fileserver\software\ClaudeCodeInstaller.exe"

# Download and run silently
$localPath = "$env:TEMP\ClaudeCodeInstaller.exe"
Copy-Item $installerPath $localPath -Force

# Install both CLI and extension
& $localPath -Silent -InstallCLI -InstallExtension

# Cleanup
Remove-Item $localPath -Force
```

### Logging for IT Support

Collect logs from users:

```powershell
# Collect installation logs
$logPath = "$env:TEMP\ClaudeCodeInstaller.log"
if (Test-Path $logPath) {
    Copy-Item $logPath "\\support-share\logs\$env:USERNAME-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
}
```

## Need Help?

- Check [README.md](README.md) for detailed documentation
- See [Advanced-WiX.md](Advanced-WiX.md) for MSI installer creation
- Review common issues in the troubleshooting section
- Test on a VM before wide deployment
