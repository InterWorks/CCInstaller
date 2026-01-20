# Claude Code Installer for Windows

Automated installer that handles all the common setup issues with Claude Code on Windows, including Git for Windows installation and PATH configuration.

## Features

- **Interactive GUI**: User-friendly menu for selecting installation options
- **Automatic prerequisite installation**: Installs Git for Windows if not present
- **PATH configuration**: Automatically adds `%USERPROFILE%\.local\bin` to PATH
- **Git Bash configuration**: Sets `CLAUDE_CODE_GIT_BASH_PATH` environment variable
- **Flexible installation**: Choose between CLI only, VSCode extension only, or both
- **Smart detection**: Skips VSCode installation if already present
- **Comprehensive logging**: Detailed logs for troubleshooting

## Prerequisites for Building

- Windows 10/11
- PowerShell 5.1 or higher
- Administrator privileges
- Internet connection (for downloading dependencies)

## Building the Installer

### Option 1: Using ps2exe (Recommended)

1. Open PowerShell as Administrator
2. Navigate to the installer directory:
   ```powershell
   cd C:\Users\acewi\Desktop\CCInstaller
   ```
3. Run the build script:
   ```powershell
   .\Build-Installer.ps1
   ```
4. The installer will be created in the `.\build` directory

### Option 2: Run PowerShell Script Directly (Testing)

For testing purposes, you can run the PowerShell script directly:

```powershell
# Interactive mode
.\Install-ClaudeCode.ps1

# Silent mode with CLI only
.\Install-ClaudeCode.ps1 -Silent -InstallCLI

# Silent mode with VSCode extension only
.\Install-ClaudeCode.ps1 -Silent -InstallExtension

# Silent mode with both
.\Install-ClaudeCode.ps1 -Silent -InstallCLI -InstallExtension
```

## Using the Installer

### End-User Instructions

1. Right-click on `ClaudeCodeInstaller.exe`
2. Select "Run as Administrator"
3. Follow the on-screen prompts:
   - Option 1: Install Claude Code CLI
   - Option 2: Install VSCode + Claude Code Extension
   - Option 3: Install Both
   - Option 4: Exit

## What Gets Installed

### For CLI Installation:
- Git for Windows (if not present)
- Claude Code CLI
- Sets `CLAUDE_CODE_GIT_BASH_PATH` environment variable
- Adds `%USERPROFILE%\.local\bin` to PATH

### For VSCode Extension Installation:
- Visual Studio Code (if not present)
- Claude Code extension for VSCode
- All prerequisites from CLI installation

## Post-Installation

After installation completes:

1. **Restart your terminal** (PowerShell, CMD, or Git Bash)
2. **Restart VSCode** if it was already running
3. Run `claude` in your terminal to start using Claude Code CLI
4. Open VSCode and the Claude Code extension should be available

## Troubleshooting

### Installation Log

Detailed logs are saved to: `%TEMP%\ClaudeCodeInstaller.log`

### Common Issues

**Issue**: "This installer requires administrator privileges"
- **Solution**: Right-click the installer and select "Run as Administrator"

**Issue**: `claude` command not found after installation
- **Solution**: Close and reopen your terminal to refresh environment variables

**Issue**: Git Bash path not detected
- **Solution**: Check installation log for the detected path. Manually set if needed:
  ```powershell
  $env:CLAUDE_CODE_GIT_BASH_PATH="C:\Program Files\Git\bin\bash.exe"
  ```

## Code Signing

To sign the executable for enterprise distribution:

```powershell
# Using your company's code signing certificate
signtool sign /f "path\to\certificate.pfx" /p "password" /tr http://timestamp.digicert.com /td sha256 /fd sha256 "build\ClaudeCodeInstaller.exe"
```

## Customization

### Changing Installation Defaults

Edit [Install-ClaudeCode.ps1](Install-ClaudeCode.ps1) and modify the `$Script:Config` section:

```powershell
$Script:Config = @{
    GitInstallerUrl = "..."      # Update to specific Git version
    VSCodeInstallerUrl = "..."   # Update to specific VSCode version
    LocalBinPath = "..."         # Change default bin path
    # ... more options
}
```

### Adding a Custom Icon

1. Create or obtain a `.ico` file (see [ICON-GUIDE.md](ICON-GUIDE.md) for detailed instructions)
2. Save it as `InterWorks-Logo.ico` in the installer directory
3. Build the installer - the icon will be automatically included

Or specify a custom path:
```powershell
.\Build-Installer.ps1 -IconFile ".\path\to\your-logo.ico"
```

For detailed icon creation instructions, see [ICON-GUIDE.md](ICON-GUIDE.md)

### Branding

Update the build script with your company information:

```powershell
Company = "Your Company Name"
Product = "Claude Code Installer"
Copyright = "Copyright © $(Get-Date -Format yyyy) Your Company"
```

## Testing Checklist

Test the installer in these scenarios:

- [ ] Fresh Windows 11 VM with no prerequisites
- [ ] Machine with Git already installed
- [ ] Machine with VSCode already installed
- [ ] Machine with both Git and VSCode installed
- [ ] Machine with Node.js not installed
- [ ] Silent installation mode
- [ ] Non-administrator user (should show error)

## Architecture

### Components

1. **Install-ClaudeCode.ps1**: Main installer script
   - Prerequisite checking
   - Component installation
   - Environment configuration
   - User interface

2. **Build-Installer.ps1**: Build automation
   - Packages PowerShell into EXE
   - Sets executable metadata
   - Handles versioning

### Installation Flow

```
┌─────────────────────────────────────┐
│  Check Administrator Privileges     │
└───────────────┬─────────────────────┘
                │
                ▼
┌─────────────────────────────────────┐
│  Show Menu / Parse Parameters       │
└───────────────┬─────────────────────┘
                │
                ▼
┌─────────────────────────────────────┐
│  Check & Install Git for Windows    │
└───────────────┬─────────────────────┘
                │
                ▼
┌─────────────────────────────────────┐
│  Configure Git Bash Path            │
└───────────────┬─────────────────────┘
                │
                ▼
┌─────────────────────────────────────┐
│  Add Local Bin to PATH              │
└───────────────┬─────────────────────┘
                │
                ▼
┌─────────────────────────────────────┐
│  Install Selected Components:       │
│  • Claude CLI (via npm)             │
│  • VSCode (if needed)               │
│  • Claude Extension                 │
└───────────────┬─────────────────────┘
                │
                ▼
┌─────────────────────────────────────┐
│  Show Completion Message            │
└─────────────────────────────────────┘
```

## License

This installer is provided as-is for internal company use. Ensure compliance with licenses for all installed components:
- Git for Windows: GPL v2
- Visual Studio Code: Microsoft Software License
- Claude Code: Anthropic's terms of service

## Support

For issues or questions:
1. Check the installation log at `%TEMP%\ClaudeCodeInstaller.log`
2. Review the troubleshooting section above
3. Contact your IT support team
4. Report bugs to the installer maintainer

## Version History

### v1.0.0 (Initial Release)
- Interactive installation menu
- CLI and VSCode extension support
- Automatic Git for Windows installation
- PATH configuration
- Comprehensive logging
