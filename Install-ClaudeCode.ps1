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

    # Step 5: Install VSCode and extension if requested
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
