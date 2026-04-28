#!/usr/bin/env bash
#
# Claude Code Installer for macOS
# Installs Claude Code CLI and VSCode extension with all prerequisites.
#
# Usage:
#   Interactive:  bash Install-ClaudeCode.sh
#   Silent CLI:   bash Install-ClaudeCode.sh --silent --cli
#   Silent VSCode: bash Install-ClaudeCode.sh --silent --vscode
#   Silent both:  bash Install-ClaudeCode.sh --silent --cli --vscode

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

CLAUDE_EXTENSION_ID="Anthropic.claude-code"
LOCAL_BIN_PATH="$HOME/.local/bin"
SKILL_DIR="$HOME/.claude/skills/dev-setup"
SKILL_FILE="$SKILL_DIR/SKILL.md"
TEMP_DIR=$(mktemp -d /tmp/ClaudeCodeInstaller.XXXXXX)
LOG_FILE="/tmp/ClaudeCodeInstaller.log"
touch "$LOG_FILE" && chmod 600 "$LOG_FILE"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

SILENT=false
INSTALL_CLI=false
INSTALL_VSCODE=false

for arg in "$@"; do
    case "$arg" in
        --silent)  SILENT=true ;;
        --cli)     INSTALL_CLI=true ;;
        --vscode)  INSTALL_VSCODE=true ;;
    esac
done

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    case "$level" in
        SUCCESS) echo -e "\033[32m$message\033[0m" ;;
        ERROR)   echo -e "\033[31m$message\033[0m" ;;
        WARNING) echo -e "\033[33m$message\033[0m" ;;
        INFO)    echo -e "\033[36m$message\033[0m" ;;
        *)       echo "$message" ;;
    esac
}

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

show_banner() {
    clear
    echo -e "\033[36m╔════════════════════════════════════════════════════════════╗"
    echo    "║                                                            ║"
    echo    "║           Claude Code Installer for macOS                  ║"
    echo    "║                 Made by InterWorks :)                      ║"
    echo    "║                                                            ║"
    echo -e "╚════════════════════════════════════════════════════════════╝\033[0m"
    echo
}

show_menu() {
    echo "Please select installation options:"
    echo
    echo "  [1] Install Claude Code CLI"
    echo "  [2] Install VSCode + Claude Code Extension"
    echo "  [3] Install Both (CLI + VSCode Extension)"
    echo "  [4] Exit"
    echo

    local choice
    while true; do
        read -rp "Enter your choice (1-4): " choice
        case "$choice" in
            [1-4]) echo "$choice"; return ;;
            *) echo "Please enter 1, 2, 3, or 4." ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Prerequisite checks
# ---------------------------------------------------------------------------

check_git() {
    if git --version &>/dev/null; then
        log SUCCESS "Git is already installed: $(git --version)"
        return 0
    fi
    log WARNING "Git is not installed"
    return 1
}

check_homebrew() {
    if command -v brew &>/dev/null; then
        log SUCCESS "Homebrew is already installed: $(brew --version | head -1)"
        return 0
    fi
    log WARNING "Homebrew is not installed"
    return 1
}

check_node() {
    if node --version &>/dev/null; then
        log SUCCESS "Node.js is already installed: $(node --version)"
        return 0
    fi
    log WARNING "Node.js is not installed"
    return 1
}

check_vscode() {
    for try_dir in "/Applications" "$HOME/Applications"; do
        if [[ -d "$try_dir/Visual Studio Code.app" ]]; then
            log SUCCESS "VSCode is already installed in $try_dir"
            return 0
        fi
    done
    log WARNING "VSCode is not installed"
    return 1
}

check_claude_cli() {
    if claude --version &>/dev/null; then
        return 0
    fi
    return 1
}

check_claude_extension() {
    if code --list-extensions 2>/dev/null | grep -Fqix "${CLAUDE_EXTENSION_ID}"; then
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# Installation functions
# ---------------------------------------------------------------------------

install_xcode_tools() {
    log INFO "Installing Xcode Command Line Tools (includes Git)..."
    # xcode-select --install is interactive; detect when it completes
    xcode-select --install 2>/dev/null || true

    # Wait for the install to finish (it opens a GUI dialog)
    echo "A dialog has appeared asking you to install the Xcode Command Line Tools."
    echo "Please click 'Install' and wait for it to complete, then press Enter here."
    read -rp "Press Enter once the Xcode Command Line Tools are installed: "

    if check_git; then
        return 0
    fi
    log ERROR "Git still not found after Xcode Command Line Tools install."
    return 1
}

install_homebrew() {
    log INFO "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Homebrew on Apple Silicon installs to /opt/homebrew; add to PATH for this session
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    if check_homebrew; then
        add_homebrew_to_shell_profile
        return 0
    fi
    log ERROR "Homebrew installation failed."
    return 1
}

add_homebrew_to_shell_profile() {
    local brew_shellenv
    if [[ -x /opt/homebrew/bin/brew ]]; then
        brew_shellenv='eval "$(/opt/homebrew/bin/brew shellenv)"'
    else
        brew_shellenv='eval "$(/usr/local/bin/brew shellenv)"'
    fi

    for profile in "$HOME/.zprofile" "$HOME/.bash_profile"; do
        if [[ -f "$profile" ]] && grep -q 'brew shellenv' "$profile" 2>/dev/null; then
            return 0  # already present
        fi
    done

    # Write to the profile matching the active shell
    local target
    if [[ "$SHELL" == */zsh ]]; then
        target="$HOME/.zprofile"
    else
        target="$HOME/.bash_profile"
    fi
    echo "" >> "$target"
    echo "# Homebrew" >> "$target"
    echo "$brew_shellenv" >> "$target"
    log SUCCESS "Added Homebrew to $target"
}

install_node() {
    log INFO "Installing Node.js via Homebrew..."
    brew install node

    # Refresh PATH
    hash -r 2>/dev/null || true

    if check_node; then
        return 0
    fi
    log ERROR "Node.js installation failed."
    return 1
}

add_local_bin_to_path() {
    mkdir -p "$LOCAL_BIN_PATH"

    if echo "$PATH" | tr ':' '\n' | grep -qx "$LOCAL_BIN_PATH"; then
        log SUCCESS "~/.local/bin is already in PATH"
        return 0
    fi

    log INFO "Adding ~/.local/bin to PATH..."

    # Determine the active shell profile to persist the change
    local profile
    if [[ "$SHELL" == */zsh ]]; then
        profile="$HOME/.zshrc"
    else
        profile="$HOME/.bash_profile"
    fi

    # Only append if the marker isn't already in the profile (prevents duplicates on reruns)
    if ! grep -q '# Added by Claude Code Installer' "$profile" 2>/dev/null; then
        echo "" >> "$profile"
        echo "# Added by Claude Code Installer" >> "$profile"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$profile"
    fi

    # Apply to current session
    export PATH="$HOME/.local/bin:$PATH"

    log SUCCESS "~/.local/bin added to PATH (persisted to $profile)"
}

install_claude_cli() {
    log INFO "Installing Claude Code CLI..."
    curl -fsSL https://claude.ai/install.sh | sh

    # The installer may add claude to ~/.local/bin or similar; refresh PATH
    export PATH="$HOME/.local/bin:$PATH"
    hash -r 2>/dev/null || true

    if check_claude_cli; then
        log SUCCESS "Claude Code CLI installed successfully"
        return 0
    fi
    log ERROR "Claude Code CLI installation failed"
    return 1
}

install_vscode() {
    log INFO "Downloading Visual Studio Code..."

    local zip_path="$TEMP_DIR/vscode.zip"
    curl -fsSL "https://code.visualstudio.com/sha/download?build=stable&os=darwin-universal" \
        -o "$zip_path"

    log INFO "Installing Visual Studio Code..."
    unzip -q "$zip_path" -d "$TEMP_DIR"

    if [[ -d "$TEMP_DIR/Visual Studio Code.app" ]]; then
        # Prefer /Applications (system-wide); fall back to ~/Applications if not writable
        local install_dir="/Applications"
        if [[ ! -w "$install_dir" ]]; then
            log WARNING "/Applications is not writable; installing to ~/Applications instead"
            install_dir="$HOME/Applications"
            mkdir -p "$install_dir"
        fi
        mv "$TEMP_DIR/Visual Studio Code.app" "$install_dir/"
        log SUCCESS "Visual Studio Code installed to $install_dir"

        # Install the 'code' CLI symlink
        install_vscode_cli_symlink "$install_dir"
        return 0
    fi
    log ERROR "VSCode app bundle not found after extracting download"
    return 1
}

install_vscode_cli_symlink() {
    local install_dir="${1:-/Applications}"
    local code_bin="$install_dir/Visual Studio Code.app/Contents/Resources/app/bin/code"
    if [[ -f "$code_bin" ]]; then
        mkdir -p "$LOCAL_BIN_PATH"
        ln -sf "$code_bin" "$LOCAL_BIN_PATH/code"
        log SUCCESS "'code' command linked to ~/.local/bin/code"
    fi
}

install_claude_extension() {
    log INFO "Installing Claude Code extension for VSCode..."

    if ! command -v code &>/dev/null; then
        log WARNING "'code' command not found; trying known paths..."
        local code_bin
        for try_dir in "/Applications" "$HOME/Applications"; do
            local try_bin="$try_dir/Visual Studio Code.app/Contents/Resources/app/bin/code"
            if [[ -f "$try_bin" ]]; then
                code_bin="$try_bin"
                break
            fi
        done
        if [[ -n "$code_bin" ]]; then
            ln -sf "$code_bin" "$LOCAL_BIN_PATH/code"
            export PATH="$LOCAL_BIN_PATH:$PATH"
        else
            log ERROR "Cannot find 'code' binary — extension installation skipped"
            return 1
        fi
    fi

    if code --install-extension "$CLAUDE_EXTENSION_ID" --force; then
        log SUCCESS "Claude Code extension installed successfully"
        return 0
    fi
    log ERROR "Extension installation failed"
    return 1
}

install_dev_setup_skill() {
    log INFO "Installing InterWorks developer-setup skill..."

    mkdir -p "$SKILL_DIR"

    # Fallback for local/dev runs: if a SKILL.md sits next to this script, use it directly
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$script_dir/SKILL.md" ]]; then
        log INFO "Loading SKILL.md from disk (local/dev run)"
        cp "$script_dir/SKILL.md" "$SKILL_FILE"
        log SUCCESS "Developer-setup skill installed to: $SKILL_FILE"
        return 0
    fi

    # SKILL_CONTENT_START - replaced at build time by the workflow from SKILL.md
    cat > "$SKILL_FILE" << 'SKILL_EOF'
---
name: dev-setup
description: Verify and configure the development environment — GitHub account, org membership, pre-commit hooks, and marketplace access. Run once per staff member, or re-run to diagnose issues.
---

# /dev-setup — Vibe Coding Environment Setup

> **Run once per staff member.** This skill verifies the development environment and completes the setup that the installer doesn't handle (GitHub account, org membership, marketplace access). It also serves as a diagnostic tool — re-run it anytime to check for issues.

## Distribution

This skill is the bootstrap entry point for new staff. It must reach users **before** they have GitHub org access, which is why it is **not** distributed via the plugin marketplace. Instead, it is bundled directly into the installers and placed on disk — this means it has no namespace prefix and is invoked as `/dev-setup`, not `/interworks:dev-setup`.

The source of truth for this file is `InterWorks/claude-plugins` (for version control alongside the other InterWorks skills), but the distribution mechanism is the installer, not the marketplace.

- **Windows:** The custom InterWorks installer drops this skill file into `~/.claude/skills/dev-setup/SKILL.md` so `/dev-setup` is available immediately, before marketplace access is configured. The installer also handles Git, Node.js, and Claude Code itself.
- **macOS:** The macOS installer likewise places this skill file on disk as part of installing Claude Code components.

This skill then guides the user through everything the installer doesn't handle directly: GitHub account setup, org membership, Python, pre-commit/gitleaks, and marketplace access.

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
# macOS/Linux (bash/zsh):
gh api /orgs/InterWorks/teams/all-members/memberships/{username} --jq '.state' 2>/dev/null
# Windows (PowerShell):
gh api /orgs/InterWorks/teams/all-members/memberships/{username} --jq '.state' 2>$null
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
- If it's still not visible after a restart, ask in **#iw-ai** on Slack.

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
SKILL_EOF
    # SKILL_CONTENT_END

    log SUCCESS "Developer-setup skill installed to: $SKILL_FILE"
}

# ---------------------------------------------------------------------------
# Main installation process
# ---------------------------------------------------------------------------

run_installation() {
    local install_cli="$1"
    local install_vscode="$2"

    log INFO "Starting Claude Code installation process..."
    echo

    # Step 1: Ensure Git is available (via Xcode Command Line Tools)
    if ! check_git; then
        log WARNING "Git is required. It can be installed via Xcode Command Line Tools."
        if [[ "$SILENT" == true ]]; then
            log ERROR "Git/Xcode Command Line Tools are missing. Silent mode cannot run the interactive installer. Install them first or re-run without --silent."
            return 1
        fi
        read -rp "Install Xcode Command Line Tools (includes Git)? (Y/N): " response
        if [[ "$response" != [Yy] ]]; then
            log WARNING "Installation cancelled by user"
            return 1
        fi
        if ! install_xcode_tools; then
            log ERROR "Git installation failed. Cannot continue."
            return 1
        fi
    fi

    # Step 2: Ensure Homebrew is available
    if ! check_homebrew; then
        log WARNING "Homebrew is required to install Node.js and other tools."
        if [[ "$SILENT" == true ]]; then
            log ERROR "Homebrew is missing. Silent mode cannot run the interactive Homebrew installer. Install Homebrew first or re-run without --silent."
            return 1
        fi
        read -rp "Install Homebrew? (Y/N): " response
        if [[ "$response" != [Yy] ]]; then
            log WARNING "Skipping Homebrew — Node.js installation will be skipped"
        else
            install_homebrew || log WARNING "Homebrew installation failed — Node.js installation will be skipped"
        fi
    fi

    # Step 3: Add ~/.local/bin to PATH
    add_local_bin_to_path

    # Step 4: Install Node.js if needed
    if ! check_node; then
        if check_homebrew; then
            install_node || log WARNING "Node.js installation failed"
        else
            log WARNING "Skipping Node.js installation (Homebrew not available)"
        fi
    fi

    # Step 5: Install Claude CLI if requested
    if [[ "$install_cli" == true ]]; then
        echo
        if check_claude_cli; then
            log SUCCESS "Claude Code CLI is already installed, skipping"
        else
            install_claude_cli || { log ERROR "Claude CLI installation failed"; return 1; }
        fi
    fi

    # Step 6: Install developer-setup skill
    install_dev_setup_skill || log WARNING "Developer-setup skill installation failed"

    # Step 7: Install VSCode and extension if requested
    local skip_vscode=false
    if [[ "$install_vscode" == true ]]; then
        echo
        if ! check_vscode; then
            if [[ "$SILENT" == false ]]; then
                read -rp "Install Visual Studio Code? (Y/N): " response
                if [[ "$response" != [Yy] ]]; then
                    log WARNING "Skipping VSCode installation"
                    skip_vscode=true
                fi
            fi
            if [[ "$skip_vscode" == false ]]; then
                install_vscode || { log ERROR "VSCode installation failed"; return 1; }
            fi
        fi

        if [[ "$skip_vscode" == false ]]; then
            echo
            if check_claude_extension; then
                log SUCCESS "Claude Code extension is already installed, skipping"
            else
                install_claude_extension || log WARNING "Extension installation failed"
            fi
        fi
    fi

    return 0
}

show_completion_message() {
    local installed_cli="${1:-false}"
    local installed_vscode="${2:-false}"

    echo
    echo -e "\033[32m═══════════════════════════════════════════════════════════\033[0m"
    echo -e "\033[32m  Installation Complete!\033[0m"
    echo -e "\033[32m═══════════════════════════════════════════════════════════\033[0m"
    echo
    log SUCCESS "Claude Code has been installed successfully"
    echo
    echo -e "\033[33mIMPORTANT:\033[0m Please open a new terminal window for PATH changes to take effect"
    echo
    if [[ "$installed_cli" == true ]]; then
        echo "To use Claude Code CLI, open a new terminal and run:"
        echo -e "  \033[36mclaude\033[0m"
        echo
        echo "You will be prompted to log in to your Anthropic account the first time you run 'claude'."
        echo
    fi
    if [[ "$installed_vscode" == true ]]; then
        echo "Open VSCode and log in to your Anthropic account when prompted by the Claude Code extension."
        echo
    fi
    echo -e "\033[33mNext step:\033[0m Open Claude Code and run \033[36m/dev-setup\033[0m to complete your environment setup"
    echo "           (GitHub account, org membership, Python, pre-commit, and more)."
    echo
    echo -e "\033[90mInstallation log saved to: $LOG_FILE\033[0m"
    echo
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

main() {
    # Trap to clean up temp dir on exit
    trap 'rm -rf "$TEMP_DIR"' EXIT

    if [[ "$SILENT" == true ]]; then
        if run_installation "$INSTALL_CLI" "$INSTALL_VSCODE"; then
            show_completion_message "$INSTALL_CLI" "$INSTALL_VSCODE"
        else
            log ERROR "Installation did not complete successfully. Check the log for details: $LOG_FILE"
            exit 1
        fi
        return
    fi

    show_banner

    local choice
    choice=$(show_menu)

    case "$choice" in
        1) run_installation true false  && show_completion_message true false ;;
        2) run_installation false true  && show_completion_message false true ;;
        3) run_installation true true   && show_completion_message true true ;;
        4) log WARNING "Installation cancelled by user"; exit 0 ;;
    esac

    read -rp "Press Enter to exit"
}

main
