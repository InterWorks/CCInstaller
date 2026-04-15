#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Claude Code Installer for Windows
.DESCRIPTION
    Automated installer for Claude Code CLI and VSCode extension with all prerequisites
#>

[CmdletBinding()]
param(
    [switch]$Silent,
    [switch]$InstallCLI,
    [switch]$InstallVSCode,
    [switch]$InstallExtension,
    [switch]$SkipGit
)

# Configuration
$Script:Config = @{
    GitInstallerUrl = "https://github.com/git-for-windows/git/releases/download/v2.52.0.windows.1/Git-2.52.0-64-bit.exe"
    VSCodeInstallerUrl = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-user"
    #NodeInstallerUrl = "https://nodejs.org/dist/v22.12.0/node-v22.12.0-x64.msi"
    NodeInstallerUrl = "https://nodejs.org/dist/latest/node-v25.3.0-x64.msi"
    ClaudeInstallScript = "https://claude.ai/install.ps1"
    ClaudeExtensionId = "Anthropic.claude-code"
    LocalBinPath = "$env:USERPROFILE\.local\bin"
    TempDir = "$env:TEMP\ClaudeCodeInstaller"
    LogFile = "$env:TEMP\ClaudeCodeInstaller.log"
}

# Color scheme for console output
$Script:Colors = @{
    Success = "Green"
    Error = "Red"
    Warning = "Yellow"
    Info = "Cyan"
    Prompt = "White"
}

#region Logging Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $Script:Config.LogFile -Value $logMessage

    $color = $Script:Colors[$Level]
    Write-Host $Message -ForegroundColor $color
}

#endregion

#region UI Functions

function Show-Banner {
    $host.UI.RawUI.WindowTitle = "Claude Code Installer"
    Clear-Host
    Write-Host @"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║           Claude Code Installer for Windows                ║
║                 Made by InterWorks :)                      ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
    Write-Host ""
}

function Show-Menu {
    Write-Host "Please select installation options:" -ForegroundColor $Script:Colors.Prompt
    Write-Host ""
    Write-Host "  [1] Install Claude Code CLI" -ForegroundColor White
    Write-Host "  [2] Install VSCode + Claude Code Extension" -ForegroundColor White
    Write-Host "  [3] Install Both (CLI + VSCode Extension)" -ForegroundColor White
    Write-Host "  [4] Exit" -ForegroundColor White
    Write-Host ""

    do {
        $choice = Read-Host "Enter your choice (1-4)"
    } while ($choice -notmatch '^[1-4]$')

    return $choice
}

#endregion

#region Prerequisite Checks

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-GitInstalled {
    try {
        $gitVersion = git --version 2>$null
        if ($gitVersion) {
            Write-Log "Git is already installed: $gitVersion" -Level Success
            return $true
        }
    }
    catch {
        Write-Log "Git is not installed" -Level Warning
        return $false
    }
    return $false
}

function Test-GitBashPath {
    $gitBashPath = "C:\Program Files\Git\bin\bash.exe"
    if (Test-Path $gitBashPath) {
        return $gitBashPath
    }

    # Check alternative locations
    $altPaths = @(
        "C:\Program Files (x86)\Git\bin\bash.exe",
        "$env:ProgramFiles\Git\bin\bash.exe",
        "${env:ProgramFiles(x86)}\Git\bin\bash.exe"
    )

    foreach ($path in $altPaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}

function Test-NodeInstalled {
    try {
        $nodeVersion = node --version 2>$null
        if ($nodeVersion) {
            Write-Log "Node.js is already installed: $nodeVersion" -Level Success
            return $true
        }
    }
    catch {
        Write-Log "Node.js is not installed" -Level Warning
        return $false
    }
    return $false
}

function Test-VSCodeInstalled {
    $vscodePaths = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
        "$env:ProgramFiles\Microsoft VS Code\Code.exe",
        "${env:ProgramFiles(x86)}\Microsoft VS Code\Code.exe"
    )

    foreach ($path in $vscodePaths) {
        if (Test-Path $path) {
            Write-Log "VSCode is already installed at: $path" -Level Success
            return $true
        }
    }

    Write-Log "VSCode is not installed" -Level Warning
    return $false
}

function Test-ClaudeCLIInstalled {
    try {
        $claudeVersion = claude --version 2>$null
        if ($claudeVersion) {
            return $true
        }
    }
    catch {
        return $false
    }
    return $false
}

function Test-ClaudeExtensionInstalled {
    try {
        $extensions = code --list-extensions 2>$null
        if ($extensions -contains $Script:Config.ClaudeExtensionId) {
            return $true
        }
    }
    catch {
        Write-Log "Could not check for Claude Code extension" -Level Warning
        return $false
    }
    return $false
}

function Test-PathVariable {
    param([string]$PathToCheck)

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $fullPath = "$userPath;$machinePath"

    return $fullPath -split ';' | Where-Object { $_ -eq $PathToCheck }
}

#endregion

#region Installation Functions

function Install-GitForWindows {
    Write-Log "Downloading Git for Windows..." -Level Info

    $installerPath = Join-Path $Script:Config.TempDir "git-installer.exe"

    try {
        # Download Git installer
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Script:Config.GitInstallerUrl -OutFile $installerPath -UseBasicParsing
        $ProgressPreference = 'Continue'

        Write-Log "Installing Git for Windows (this may take a few minutes)..." -Level Info

        # Install Git silently
        $process = Start-Process -FilePath $installerPath -ArgumentList "/VERYSILENT", "/NORESTART", "/NOCANCEL", "/SP-", "/CLOSEAPPLICATIONS", "/RESTARTAPPLICATIONS", "/COMPONENTS=gitlfs" -Wait -PassThru

        if ($process.ExitCode -eq 0) {
            Write-Log "Git for Windows installed successfully" -Level Success

            # Refresh environment variables
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

            return $true
        }
        else {
            Write-Log "Git installation failed with exit code: $($process.ExitCode)" -Level Error
            return $false
        }
    }
    catch {
        Write-Log "Error installing Git: $_" -Level Error
        return $false
    }
}

function Set-GitBashEnvironmentVariable {
    # Check if already set
    $existingPath = [Environment]::GetEnvironmentVariable("CLAUDE_CODE_GIT_BASH_PATH", "User")
    if ($existingPath -and (Test-Path $existingPath)) {
        Write-Log "CLAUDE_CODE_GIT_BASH_PATH is already set to: $existingPath" -Level Success
        return $true
    }

    $gitBashPath = Test-GitBashPath

    if (-not $gitBashPath) {
        Write-Log "Could not find Git Bash executable" -Level Error
        return $false
    }

    Write-Log "Setting CLAUDE_CODE_GIT_BASH_PATH environment variable..." -Level Info

    try {
        [Environment]::SetEnvironmentVariable("CLAUDE_CODE_GIT_BASH_PATH", $gitBashPath, "User")
        $env:CLAUDE_CODE_GIT_BASH_PATH = $gitBashPath
        Write-Log "Git Bash path set to: $gitBashPath" -Level Success
        return $true
    }
    catch {
        Write-Log "Error setting Git Bash path: $_" -Level Error
        return $false
    }
}

function Install-NodeJS {
    Write-Log "Downloading Node.js installer..." -Level Info

    $installerPath = Join-Path $Script:Config.TempDir "node-installer.msi"

    try {
        # Download Node.js installer
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Script:Config.NodeInstallerUrl -OutFile $installerPath -UseBasicParsing
        $ProgressPreference = 'Continue'

        Write-Log "Installing Node.js (this may take a few minutes)..." -Level Info

        # Install Node.js silently
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$installerPath`"", "/quiet", "/norestart" -Wait -PassThru

        if ($process.ExitCode -eq 0) {
            Write-Log "Node.js installed successfully" -Level Success

            # Refresh environment variables
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

            return $true
        }
        else {
            Write-Log "Node.js installation failed with exit code: $($process.ExitCode)" -Level Error
            return $false
        }
    }
    catch {
        Write-Log "Error installing Node.js: $_" -Level Error
        return $false
    }
}

function Add-LocalBinToPath {
    $localBinPath = $Script:Config.LocalBinPath

    # Create directory if it doesn't exist
    if (-not (Test-Path $localBinPath)) {
        Write-Log "Creating directory: $localBinPath" -Level Info
        New-Item -Path $localBinPath -ItemType Directory -Force | Out-Null
    }

    # Check if already in PATH
    if (Test-PathVariable -PathToCheck $localBinPath) {
        Write-Log "Local bin directory is already in PATH" -Level Success
        return $true
    }

    Write-Log "Adding $localBinPath to user PATH..." -Level Info

    try {
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $newPath = "$currentPath;$localBinPath"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")

        # Update current session
        $env:Path += ";$localBinPath"

        Write-Log "Local bin directory added to PATH" -Level Success
        return $true
    }
    catch {
        Write-Log "Error adding to PATH: $_" -Level Error
        return $false
    }
}

function Install-ClaudeCLI {
    Write-Log "Installing Claude Code CLI..." -Level Info

    try {
        # Download the native installer script
        Write-Log "Downloading Claude Code installer..." -Level Info
        $installerScript = Join-Path $Script:Config.TempDir "claude-install.ps1"

        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Script:Config.ClaudeInstallScript -OutFile $installerScript -UseBasicParsing
        $ProgressPreference = 'Continue'

        Write-Log "Running Claude Code installer (this may take a few minutes)..." -Level Info

        # Run the installer script
        $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy", "Bypass", "-File", "`"$installerScript`"" -Wait -PassThru -NoNewWindow

        if ($process.ExitCode -eq 0) {
            Write-Log "Claude Code CLI installed successfully" -Level Success

            # Refresh environment variables
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

            return $true
        }
        else {
            Write-Log "Claude Code CLI installation failed with exit code: $($process.ExitCode)" -Level Error
            return $false
        }
    }
    catch {
        Write-Log "Error installing Claude Code CLI: $_" -Level Error
        return $false
    }
}

function New-VSCodeDesktopShortcut {
    Write-Log "Creating Desktop shortcut for VSCode..." -Level Info

    $vscodePaths = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
        "$env:ProgramFiles\Microsoft VS Code\Code.exe",
        "${env:ProgramFiles(x86)}\Microsoft VS Code\Code.exe"
    )

    $vscodeExePath = $null
    foreach ($path in $vscodePaths) {
        if (Test-Path $path) {
            $vscodeExePath = $path
            break
        }
    }

    if (-not $vscodeExePath) {
        Write-Log "Could not find VSCode executable for shortcut creation" -Level Warning
        return $false
    }

    try {
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $shortcutPath = Join-Path $desktopPath "Visual Studio Code.lnk"

        $wshShell = New-Object -ComObject WScript.Shell
        $shortcut = $wshShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $vscodeExePath
        $shortcut.WorkingDirectory = [Environment]::GetFolderPath("UserProfile")
        $shortcut.Description = "Visual Studio Code"
        $shortcut.Save()

        Write-Log "Desktop shortcut created successfully" -Level Success
        return $true
    }
    catch {
        Write-Log "Error creating desktop shortcut: $_" -Level Warning
        return $false
    }
}

function Install-VSCode {
    Write-Log "Downloading Visual Studio Code..." -Level Info

    $installerPath = Join-Path $Script:Config.TempDir "vscode-installer.exe"

    try {
        # Download VSCode installer
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Script:Config.VSCodeInstallerUrl -OutFile $installerPath -UseBasicParsing
        $ProgressPreference = 'Continue'

        Write-Log "Installing Visual Studio Code..." -Level Info

        # Install VSCode silently
        $process = Start-Process -FilePath $installerPath -ArgumentList "/VERYSILENT", "/NORESTART", "/MERGETASKS=!runcode,addcontextmenufiles,addcontextmenufolders,addtopath" -Wait -PassThru

        if ($process.ExitCode -eq 0) {
            Write-Log "Visual Studio Code installed successfully" -Level Success

            # Refresh environment variables
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

            # Create desktop shortcut
            New-VSCodeDesktopShortcut

            return $true
        }
        else {
            Write-Log "VSCode installation failed with exit code: $($process.ExitCode)" -Level Error
            return $false
        }
    }
    catch {
        Write-Log "Error installing VSCode: $_" -Level Error
        return $false
    }
}

function Install-DevSetupSkill {
    $skillDir = Join-Path $env:USERPROFILE ".claude\skills\interworks-setup"
    $skillFile = Join-Path $skillDir "SKILL.md"

    Write-Log "Installing InterWorks developer-setup skill..." -Level Info

    try {
        if (-not (Test-Path $skillDir)) {
            New-Item -Path $skillDir -ItemType Directory -Force | Out-Null
        }

        $skillContent = @'
---
name: dev-setup
description: Verify and configure the development environment — GitHub account, org membership, pre-commit hooks, and marketplace access. Run once per staff member, or re-run to diagnose issues.
---

# /dev-setup — Vibe Coding Environment Setup

> **Run once per staff member.** This skill verifies the development environment and completes the setup that the installer doesn't handle (GitHub account, org membership, marketplace access). It also serves as a diagnostic tool — re-run it anytime to check for issues.

## Distribution

This skill is the bootstrap entry point for new staff. It must reach users **before** they have GitHub org access, which is why it is **not** distributed via the plugin marketplace. Instead, it is bundled directly into the installers and placed on disk — this means it has no namespace prefix and is invoked as `/dev-setup`, not `/interworks:dev-setup`.

The source of truth for this file is `InterWorks/claude-plugins` (for version control alongside the other InterWorks skills), but the distribution mechanism is the installer, not the marketplace.

- **Windows:** The custom InterWorks installer drops this skill file into `~/.claude/skills/interworks-setup/SKILL.md` alongside Git, Node.js, GitHub CLI, Python, pre-commit, gitleaks, and Claude Code.
- **macOS:** The macOS installer does the same.

Once this skill gets the user into the InterWorks GitHub org, **server-managed settings** connects their Claude Code to the private plugin marketplace (`InterWorks/claude-plugins`), which delivers the remaining `/interworks:*` skills (starting with `/interworks:dev-new-project`) automatically.

---

You are helping an InterWorks staff member set up their development environment. Many of these people have never used a terminal, Git, or GitHub. Be patient, explain what you're doing in plain language, and never assume prior knowledge. If something fails, troubleshoot it — don't just show the error and move on.

## Step 0: Detect Environment

Before doing anything, gather baseline information:

1. Detect the operating system (Windows or macOS).
2. Detect the shell environment (PowerShell, cmd, zsh, bash).
3. Check which of the tools below are already installed and their versions.
4. Build a checklist of what needs to be installed/configured.

Present the checklist to the user:
- "Here's what I found on your machine, and here's what we still need to set up."
- Show green checkmarks for what's already good, and outline what's remaining.

## Step 1: Verify Core Tooling

The InterWorks installer (Windows or macOS) installs all of these tools as part of setup. Verify each is present and working. If something is missing, install it using the instructions below — but also flag it, as a missing tool likely indicates a gap in the installer that the installer developer should know about.

### Git CLI

**Check:** Run `git --version`.

**If missing:**
- **macOS:** `xcode-select --install` (installs Git as part of Xcode Command Line Tools).
- **Windows:** This should have been installed by the InterWorks installer. If missing, download and install from https://git-scm.com/downloads/win using default options.

**Configure (if not already set):**
```
git config --global user.name "<their full name>"
git config --global user.email "<their InterWorks email>"
```

Ask the user for their full name and InterWorks email address if not already configured.

### GitHub CLI (`gh`)

**Check:** Run `gh --version`.

**If missing:**
- **macOS:** `brew install gh` (if Homebrew is available). If Homebrew is not installed, install it first: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`.
- **Windows:** `winget install --id GitHub.cli` (if winget is available). Otherwise, download from https://cli.github.com/.

### Node.js (via nvm)

**Check:** Run `node --version` and `nvm --version` (or `nvm version` on Windows).

**If missing:**
- **macOS/Linux:** Install nvm: `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash`, then restart the shell and run `nvm install --lts`.
- **Windows:** Install nvm-windows from https://github.com/coreybutler/nvm-windows/releases. After install, run `nvm install lts` and `nvm use lts`.

**Verify:** `node --version` and `npm --version` both return version numbers.

### Python (via pyenv)

**Check:** Run `python3 --version` (macOS/Linux) or `python --version` (Windows) and `pyenv --version`.

**If missing:**
- **macOS:** `brew install pyenv`, then add pyenv init to shell profile, then `pyenv install 3.12` (or latest stable) and `pyenv global 3.12`.
- **Windows:** Install pyenv-win from https://github.com/pyenv-win/pyenv-win. After install, `pyenv install 3.12` and `pyenv global 3.12`.

**Verify:** `python3 --version` (or `python --version` on Windows) returns the expected version.

## Step 2: GitHub Account

**Check:** Run `gh auth status`.

**If not authenticated:**
1. Ask: "Do you already have a GitHub account?"
2. **If yes:** Proceed to authentication.
3. **If no:** Walk them through creating one at https://github.com/signup.
   - **Account identifiability requirement:** Their GitHub account must be clearly tied to them — real name or a company-recognizable username (not an anonymous handle). This is an InterWorks policy.
   - Recommend using their InterWorks email as the primary email on the account.

**Authenticate:**
```
gh auth login
```
- Select `GitHub.com`
- Select `HTTPS` as the preferred protocol
- Authenticate via browser (the easiest path for non-developers)

**Verify:** Run `gh auth status` and confirm it shows the correct username and that the token has the required scopes.

**GitHub Profile Name:**
After authentication, check if the user has set their GitHub profile Name field:
```
gh api /user --jq '.name'
```
- If the Name field is empty or null, explain: "GitHub has a 'Name' field in your profile settings that's separate from your username. Setting this to your real name makes it much easier for coworkers to find you — otherwise people only see your username in member lists and PRs."
- Walk them through setting it: GitHub.com → Settings → Profile → Name → enter their full name → Save.
- After they set it, verify with the same `gh api /user --jq '.name'` command.
- If they already have a name set, confirm it and move on.

## Step 3: InterWorks GitHub Org Membership

**Check:** Run `gh api /user/memberships/orgs/InterWorks --jq '.state'` to check org membership status.

**If not a member:**
- Explain: "You need to be added to the InterWorks GitHub organization. I'll help you request access."
- **Process:** Slack **Ben Bausili** (Global Director of Product) and request to be added to the InterWorks GitHub org. Include your GitHub username in the message.
  - Provide the username they just authenticated with so they can copy/paste it into the Slack message.
  - Tell them to come back and re-run `/dev-setup` once they've been added, or continue with the remaining steps that don't require org access.

**If pending (invited but not yet accepted):**
- Walk them through accepting the invitation at https://github.com/orgs/InterWorks/invitation or via `gh api --method PATCH /user/memberships/orgs/InterWorks --field state=active`.

**If active:** Confirm and move on.

**"All Members" Team Membership:**
Once org membership is active, check if the user is in the "All Members" team:
```
gh api /orgs/InterWorks/teams/all-members/memberships/{username} --jq '.state' 2>/dev/null
```
- If not a member, add them: `gh api --method PUT /orgs/InterWorks/teams/all-members/memberships/{username}`
- Explain: "We add everyone to the 'All Members' team so you can see shared repos across the org. This is our workaround since GitHub Teams plan doesn't support 'internal' repo visibility."
- **Note:** This requires the authenticated user to have team maintainer or org admin permissions. If the API call fails due to permissions, skip this step — the user will be added by an admin.

## Step 4: Pre-commit (gitleaks)

**Check:** Run `pre-commit --version`.

**If missing:**
- Install pre-commit: `pip install pre-commit` (or `pip3 install pre-commit`).

**Configure globally:**
- Create or update the global pre-commit config so gitleaks runs on every repo by default.
- `git config --global init.templateDir ~/.git-template`
- Create `~/.git-template/hooks/` if it doesn't exist.
- Run `pre-commit init-templatedir ~/.git-template` to install hooks into the global template.
- Create `~/.pre-commit-config.yaml` with:
```yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.21.2
    hooks:
      - id: gitleaks
```

**Verify:** Create a temp repo, stage a file, and confirm pre-commit runs gitleaks.

## Step 5: Install the InterWorks Plugin

> **Prerequisite:** This step requires InterWorks GitHub org membership (Step 3). If org membership is still pending, skip this step and tell the user to re-run `/dev-setup` after they've been added.

The InterWorks plugin marketplace (`InterWorks/claude-plugins`) has already been registered in your Claude Code via server-managed settings — you just need to install the plugin now that you have org access to authenticate to the private repo.

Run the following command:
```
/plugin install dev-new-project@interworks
```

Or, if you prefer the interactive UI:
1. Run `/plugin` to open the plugin manager.
2. Navigate to the **Discover** tab.
3. Find `dev-new-project` under the `interworks` marketplace and press Enter to install.

Install at **user scope** so it's available across all your projects.

**If the marketplace or plugin isn't visible:**
- Confirm org membership is active (Step 3) — you need org access to authenticate to the private marketplace repo.
- Restart Claude Code if you only just gained org access (server-managed settings are polled at startup and hourly).
- If it's still not visible after a restart, ask in **#iw-ai-coe** on Slack.

## Step 6: Smoke Test

Run a quick verification of everything:

1. `git --version` — Git is installed
2. `gh auth status` — GitHub CLI is authenticated
3. `node --version` — Node.js is available
4. `python3 --version` (or `python --version`) — Python is available
5. `pre-commit --version` — pre-commit is installed
6. `gh api /user/memberships/orgs/InterWorks --jq '.state'` — org membership is active
7. `gh api /user --jq '.name'` — GitHub profile Name is set
8. `gh api /orgs/InterWorks/teams/all-members/memberships/{username} --jq '.state'` — in "All Members" team (if org access is active)
9. Confirm `/interworks:dev-new-project` is installed and available (if org access is active)

Present a final summary:
- Green checkmarks for everything that passed
- Any items that still need attention (e.g., org membership pending)
- If everything passed: "You're all set! Run `/interworks:dev-new-project` to start your first project."
- If org membership is pending: "Almost there! Once Ben adds you to the GitHub org, re-run `/dev-setup` to finish the last step. In the meantime, your dev environment is ready."

## Tone & Approach

- **You are a helpful coworker, not a manual.** Speak conversationally.
- **Explain the "why" briefly** — e.g., "We use gitleaks to automatically catch any passwords or API keys before they get committed to code."
- **Don't overwhelm.** Show progress, celebrate small wins ("Git is installed!"), keep momentum.
- **If something fails, troubleshoot.** Don't just say "installation failed" — look at the error, suggest fixes, try alternatives.
- **Never ask the user to figure out technical details.** If you need their name and email, ask for their name and email — don't ask them to "configure git" and hand them a command to fill in.
'@

        Set-Content -Path $skillFile -Value $skillContent -Encoding UTF8
        Write-Log "Developer-setup skill installed to: $skillFile" -Level Success
        return $true
    }
    catch {
        Write-Log "Error installing developer-setup skill: $_" -Level Error
        return $false
    }
}

function Install-ClaudeExtension {
    Write-Log "Installing Claude Code extension for VSCode..." -Level Info

    try {
        # Install extension using code CLI
        $process = Start-Process -FilePath "code" -ArgumentList "--install-extension", $Script:Config.ClaudeExtensionId, "--force" -Wait -PassThru -NoNewWindow

        if ($process.ExitCode -eq 0) {
            Write-Log "Claude Code extension installed successfully" -Level Success
            return $true
        }
        else {
            Write-Log "Extension installation failed with exit code: $($process.ExitCode)" -Level Error
            return $false
        }
    }
    catch {
        Write-Log "Error installing extension: $_" -Level Error
        return $false
    }
}

#endregion

#region Main Installation Process

function Start-Installation {
    param(
        [bool]$InstallCLI,
        [bool]$InstallVSCodeAndExtension
    )

    Write-Log "Starting Claude Code installation process..." -Level Info
    Write-Host ""

    # Step 1: Install Git if needed
    if (-not (Test-GitInstalled)) {
        Write-Log "Git for Windows is required to install Claude Code CLI" -Level Warning
        if (-not $Silent) {
            $response = Read-Host "Install Git for Windows? (Y/N)"
            if ($response -ne 'Y' -and $response -ne 'y') {
                Write-Log "Installation cancelled by user" -Level Warning
                return $false
            }
        }

        if (-not (Install-GitForWindows)) {
            Write-Log "Git installation failed. Cannot continue." -Level Error
            return $false
        }
    }

    # Step 2: Configure Git Bash path
    if (-not (Set-GitBashEnvironmentVariable)) {
        Write-Log "Failed to configure Git Bash path" -Level Error
    }

    # Step 3: Add local bin to PATH
    if (-not (Add-LocalBinToPath)) {
        Write-Log "Failed to add local bin to PATH" -Level Error
    }

    # Step 4: Install Claude CLI if requested
    if ($InstallCLI) {
        Write-Host ""
        $cliInstalled = Test-ClaudeCLIInstalled
        if ($cliInstalled) {
            Write-Log "Claude Code CLI is already working properly, skipping installation" -Level Success
        }
        else {
            if (-not (Install-ClaudeCLI)) {
                Write-Log "Claude CLI installation failed" -Level Error
            }
        }
    }

    # Step 5: Install developer-setup skill
    if (-not (Install-DevSetupSkill)) {
        Write-Log "Developer-setup skill installation failed" -Level Warning
    }

    # Step 6: Install VSCode and extension if requested
    if ($InstallVSCodeAndExtension) {
        Write-Host ""

        $vscodeInstalled = Test-VSCodeInstalled

        if (-not $vscodeInstalled) {
            if (-not $Silent) {
                $response = Read-Host "Install Visual Studio Code? (Y/N)"
                if ($response -eq 'Y' -or $response -eq 'y') {
                    if (-not (Install-VSCode)) {
                        Write-Log "VSCode installation failed" -Level Error
                        return $false
                    }
                }
                else {
                    Write-Log "Skipping VSCode installation" -Level Warning
                    return $false
                }
            }
            else {
                if (-not (Install-VSCode)) {
                    Write-Log "VSCode installation failed" -Level Error
                    return $false
                }
            }
        }

        # Install extension
        Write-Host ""
        $extensionInstalled = Test-ClaudeExtensionInstalled
        if ($extensionInstalled -eq $true) {
            Write-Log "Claude Code extension is already installed, skipping installation" -Level Success
        }
        else {
            if (-not (Install-ClaudeExtension)) {
                Write-Log "Extension installation failed" -Level Error
            }
        }
    }

    return $true
}

function Show-CompletionMessage {
    $host.UI.RawUI.WindowTitle = "Claude Code Installer"
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  Installation Complete!" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Log "Claude Code has been installed successfully" -Level Success
    Write-Host ""
    Write-Host "IMPORTANT: " -ForegroundColor Yellow -NoNewline
    Write-Host "Please restart your terminal/VSCode for changes to take effect" -ForegroundColor White
    Write-Host ""
    Write-Host "To use Claude Code CLI, open a new PowerShell or CMD window and run:" -ForegroundColor White
    Write-Host "  claude" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Any Claude Code installation will require you to login to your Anthropic account." -ForegroundColor White
    Write-Host "Follow the prompts when you run the 'claude' command or use the VSCode extension for the first time." -ForegroundColor White
    Write-Host ""
    Write-Host "Next step: " -ForegroundColor Yellow -NoNewline
    Write-Host "Open Claude Code and run " -ForegroundColor White -NoNewline
    Write-Host "/dev-setup" -ForegroundColor Cyan -NoNewline
    Write-Host " to complete your environment setup (GitHub, Python, pre-commit, and more)." -ForegroundColor White
    Write-Host ""
    Write-Host "Installation log saved to: $($Script:Config.LogFile)" -ForegroundColor Gray
    Write-Host ""
}

#endregion

#region Main Entry Point

function Main {
    # Initialize
    if (-not (Test-Path $Script:Config.TempDir)) {
        New-Item -Path $Script:Config.TempDir -ItemType Directory -Force | Out-Null
    }

    # Check for admin rights
    if (-not (Test-Administrator)) {
        Write-Host "This installer requires administrator privileges." -ForegroundColor Red
        Write-Host "Please run as administrator (Right-click -> Run as Administrator)" -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit 1
    }

    Show-Banner

    # Determine installation mode
    if ($Silent) {
        # Use parameters for silent mode
        Start-Installation -InstallCLI:$InstallCLI -InstallVSCodeAndExtension:$InstallExtension
    }
    else {
        # Interactive mode
        $choice = Show-Menu

        switch ($choice) {
            "1" {
                $null = Start-Installation -InstallCLI $true -InstallVSCodeAndExtension $false
                Show-CompletionMessage
            }
            "2" {
                $null = Start-Installation -InstallCLI $false -InstallVSCodeAndExtension $true
                Show-CompletionMessage
            }
            "3" {
                $null = Start-Installation -InstallCLI $true -InstallVSCodeAndExtension $true
                Show-CompletionMessage
            }
            "4" {
                Write-Log "Installation cancelled by user" -Level Warning
                exit 0
            }
        }
    }

    # Cleanup
    if (Test-Path $Script:Config.TempDir) {
        Remove-Item -Path $Script:Config.TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Read-Host "Press Enter to exit"
}

# Run the installer
Main

#endregion
