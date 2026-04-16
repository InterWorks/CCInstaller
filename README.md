# Claude Code Installer

Automated installer for Claude Code CLI and the VSCode extension, with all prerequisites handled. Supports Windows and macOS.

## For end users

Download the installer for your platform from the [latest release](../../releases/latest):

| Platform | File | How to run |
| -------- | ---- | ---------- |
| Windows | `ClaudeCodeInstaller.exe` | Right-click → **Run as Administrator** |
| macOS | `Install-ClaudeCode-mac.zip` | Unzip, then right-click `Install-ClaudeCode.command` → **Open** (required the first time due to Gatekeeper). If macOS says the file is not executable, run `chmod +x Install-ClaudeCode.command` in Terminal first. |

Both installers present an interactive menu:

```
[1] Install Claude Code CLI
[2] Install VSCode + Claude Code Extension
[3] Install Both
[4] Exit
```

### What gets installed

**Both platforms:**
- Claude Code CLI
- Visual Studio Code (if selected)
- Claude Code VSCode extension (if selected)
- Adds the user-local bin directory to PATH (`~/.local/bin` on macOS; `%USERPROFILE%\.local\bin` on Windows)
- Drops the `/dev-setup` skill into the Claude home directory (`~/.claude/skills/interworks-setup/SKILL.md` on macOS; `%USERPROFILE%\.claude\skills\interworks-setup\SKILL.md` on Windows)

**Windows only:**
- Git for Windows (if not present)
- Node.js via MSI (if not present)
- Sets `CLAUDE_CODE_GIT_BASH_PATH` environment variable

**macOS only:**
- Xcode Command Line Tools / Git (if not present)
- Homebrew (if not present; required for Node.js installation)
- Node.js via Homebrew (if not present; skipped if Homebrew installation is declined or fails)

### After installation

1. **Open a new terminal** (or restart VSCode) for PATH changes to take effect
2. Run `claude` to log in to your Anthropic account and start using Claude Code CLI
3. Open Claude Code and run `/dev-setup` to complete your environment setup (GitHub account, org membership, Python, pre-commit, and more)

### Troubleshooting

**Windows log:** `%TEMP%\ClaudeCodeInstaller.log`
**macOS log:** `/tmp/ClaudeCodeInstaller.log`

| Issue | Solution |
| ----- | -------- |
| Windows: "requires administrator privileges" | Right-click → Run as Administrator |
| macOS: "cannot be opened because it is from an unidentified developer" | Right-click → Open (instead of double-clicking) |
| macOS: "permission denied" running `.command` after unzip | Run `chmod +x Install-ClaudeCode.command` in Terminal first |
| `claude` not found after install | Open a new terminal to refresh PATH |
| Windows: Git Bash path not detected | Manually set: `$env:CLAUDE_CODE_GIT_BASH_PATH="C:\Program Files\Git\bin\bash.exe"` |

---

## For developers

### Repo structure

| File | Purpose |
|------|---------|
| `Install-ClaudeCode.ps1` | Windows installer script |
| `Install-ClaudeCode.sh` | macOS installer script |
| `Build-Installer.ps1` | Builds the Windows EXE locally via ps2exe |
| `.github/workflows/release.yml` | CI: builds and publishes release artifacts on a new `v*` tag |

### Releasing

Merge your changes to `main`, then tag the release:

```bash
git tag v1.2.3
git push origin v1.2.3
```

The Actions workflow will:
1. Build `ClaudeCodeInstaller.exe` on a Windows runner (version pulled from the tag)
2. Package `Install-ClaudeCode.command` (the macOS `.sh` with a double-clickable extension)
3. Attach both to a GitHub Release

Download the artifacts from the release and upload them to Box for distribution.

### Building locally (Windows only)

> **Normal releases don't require this.** Pushing a `v*` tag triggers the Actions workflow, which builds the EXE automatically on a Windows runner. Local builds are only needed if you want to test the EXE before tagging a release.

```powershell
# From an Administrator PowerShell session
.\Build-Installer.ps1
# Output: .\build\ClaudeCodeInstaller.exe
```

The build script installs `ps2exe` automatically if it isn't present.

### Running scripts directly (testing)

**Windows:**
```powershell
# Interactive
.\Install-ClaudeCode.ps1

# Silent
.\Install-ClaudeCode.ps1 -Silent -InstallCLI
.\Install-ClaudeCode.ps1 -Silent -InstallExtension
.\Install-ClaudeCode.ps1 -Silent -InstallCLI -InstallExtension
```

**macOS:**
```bash
# Interactive
bash Install-ClaudeCode.sh

# Silent
bash Install-ClaudeCode.sh --silent --cli
bash Install-ClaudeCode.sh --silent --vscode
bash Install-ClaudeCode.sh --silent --cli --vscode
```

### Testing checklist

**Windows:**
- [ ] Fresh Windows 11 VM with no prerequisites
- [ ] Machine with Git already installed
- [ ] Machine with VSCode already installed
- [ ] Silent installation mode
- [ ] Non-administrator user (should show error)

**macOS:**
- [ ] Fresh macOS install (no Homebrew, no Xcode tools)
- [ ] Machine with Homebrew already installed
- [ ] Machine with VSCode already installed
- [ ] Right-click → Open Gatekeeper flow on `.command` file
- [ ] Silent installation mode

### Code signing

Code signing removes the security warnings users see when running downloaded executables:
- **Windows:** SmartScreen shows "Windows protected your PC" for unsigned EXEs
- **macOS:** Gatekeeper shows "cannot be opened because it is from an unidentified developer" for unsigned files (the right-click → Open workaround bypasses this)

#### Windows

The git history shows the EXE was previously signed by the **Curator Install Server** (commit `e01bfaf`). The details of that process — what certificate was used, how it's stored, and how to invoke it — are not documented here. **Check with Derrick Austin** before attempting to sign a new release.

Once the certificate and process are confirmed, signing looks like:
```powershell
signtool sign /f "path\to\certificate.pfx" /p "password" /tr http://timestamp.digicert.com /td sha256 /fd sha256 "build\ClaudeCodeInstaller.exe"
```

Ideally this step would be added to the Actions release workflow so every release is signed automatically without a manual step.

#### macOS

Signing a `.command` file requires an **Apple Developer ID certificate** ($99/year via the Apple Developer Program). Without it, users must right-click → Open the first time, which is documented in the end-user instructions above and is acceptable for internal distribution.

If a certificate is obtained in the future:
```bash
codesign --sign "Developer ID Application: InterWorks" Install-ClaudeCode.command
```

### Customization

**Windows** — edit the `$Script:Config` block at the top of `Install-ClaudeCode.ps1` to pin specific versions or change paths:
```powershell
$Script:Config = @{
    GitInstallerUrl  = "..."   # Pin a specific Git for Windows version
    VSCodeInstallerUrl = "..." # Pin a specific VSCode version
    NodeInstallerUrl = "..."   # Pin a specific Node.js version
    LocalBinPath     = "..."   # Change the default bin path
}
```

**macOS** — equivalent URLs and paths are at the top of `Install-ClaudeCode.sh`.

**Icon** — place `InterWorks-Logo.ico` in the repo root before building. See [ICON-GUIDE.md](ICON-GUIDE.md) for creation instructions.
