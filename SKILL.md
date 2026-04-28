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
