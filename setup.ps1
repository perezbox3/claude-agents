# setup.ps1 — Bootstrap the Claude dev environment on a new Windows machine
# Run from the cloned claude-agents directory. No admin required except winget installs.

$ErrorActionPreference = "Continue"
$repoRoot = $PSScriptRoot

Write-Host "=== Claude Dev Environment Setup ===" -ForegroundColor Cyan
Write-Host "Repo: $repoRoot`n"

# ── 1. PowerShell execution policy ────────────────────────────────────────────
Write-Host "[1/8] Setting PowerShell execution policy..." -ForegroundColor Yellow
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
Write-Host "      ExecutionPolicy = RemoteSigned (CurrentUser)" -ForegroundColor Green

# ── 2. Install tools via winget ───────────────────────────────────────────────
Write-Host "`n[2/8] Installing dependencies via winget..." -ForegroundColor Yellow
$packages = @(
    @{ Id = "Git.Git";                  Name = "Git" },
    @{ Id = "OpenJS.NodeJS.LTS";        Name = "Node.js LTS" },
    @{ Id = "Python.Python.3.13";       Name = "Python 3.13" },
    @{ Id = "GitHub.cli";               Name = "GitHub CLI" },
    @{ Id = "Microsoft.VisualStudioCode"; Name = "VS Code" },
    @{ Id = "Anthropic.Claude";         Name = "Claude Desktop" }
)

foreach ($pkg in $packages) {
    Write-Host "      $($pkg.Name)..." -NoNewline
    $result = winget install --id $pkg.Id --silent --accept-source-agreements --accept-package-agreements 2>&1
    if ($LASTEXITCODE -eq 0 -or $result -match "already installed") {
        Write-Host " OK" -ForegroundColor Green
    } else {
        Write-Host " (check manually)" -ForegroundColor Yellow
    }
}

# Claude Code CLI via npm (requires node to be in PATH — may need new shell after above)
Write-Host "      Claude Code CLI (npm)..." -NoNewline
$npmCheck = Get-Command npm -ErrorAction SilentlyContinue
if ($npmCheck) {
    npm install -g @anthropic-ai/claude-code 2>&1 | Out-Null
    Write-Host " OK" -ForegroundColor Green
} else {
    Write-Host " SKIP (npm not found — open a new terminal after Node installs, then run: npm install -g @anthropic-ai/claude-code)" -ForegroundColor Yellow
}

# ── 3. Git global config ──────────────────────────────────────────────────────
Write-Host "`n[3/8] Configuring git..." -ForegroundColor Yellow
git config --global user.name "perezbox3"
git config --global user.email "perezbox3@gmail.com"
Write-Host "      user.name = perezbox3 | user.email = perezbox3@gmail.com" -ForegroundColor Green

# ── 4. SSH config ─────────────────────────────────────────────────────────────
Write-Host "`n[4/8] Setting up SSH config..." -ForegroundColor Yellow
$sshDir = "$env:USERPROFILE\.ssh"
New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
$sshConfigSrc = "$repoRoot\config\ssh_config"
$sshConfigDst = "$sshDir\config"

if (Test-Path $sshConfigDst) {
    Write-Host "      ~/.ssh/config already exists — skipping (diff manually if needed)" -ForegroundColor Yellow
} else {
    Copy-Item $sshConfigSrc $sshConfigDst -Force
    Write-Host "      Copied ssh_config with shortcuts: development, dhfc, projects, personal" -ForegroundColor Green
}

Write-Host "      !! Copy your SSH key to $sshDir\id_ed25519 (never stored in this repo)" -ForegroundColor Red

# ── 5. PowerShell profile ─────────────────────────────────────────────────────
Write-Host "`n[5/8] Installing PowerShell profile..." -ForegroundColor Yellow
$profileDir = Split-Path $PROFILE -Parent
New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
$profileSrc = "$repoRoot\config\powershell_profile.ps1"

if (Test-Path $PROFILE) {
    Write-Host "      Profile already exists at $PROFILE" -ForegroundColor Yellow
    Write-Host "      Source is at: $profileSrc — merge manually if needed" -ForegroundColor Yellow
} else {
    Copy-Item $profileSrc $PROFILE -Force
    Write-Host "      Profile installed to $PROFILE" -ForegroundColor Green
    Write-Host "      !! Edit it and replace the YOUR_*_KEY placeholders with real ipauth.net keys" -ForegroundColor Red
}

# ── 6. Claude Code settings ───────────────────────────────────────────────────
Write-Host "`n[6/8] Installing Claude Code settings..." -ForegroundColor Yellow
$claudeDir = "$env:USERPROFILE\.claude"
New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null
$settingsSrc = "$repoRoot\config\claude_settings.json"
$settingsDst = "$claudeDir\settings.json"

if (Test-Path $settingsDst) {
    Write-Host "      settings.json already exists — skipping" -ForegroundColor Yellow
    Write-Host "      Source is at: $settingsSrc — merge manually if needed" -ForegroundColor Yellow
} else {
    Copy-Item $settingsSrc $settingsDst -Force
    Write-Host "      Claude settings installed (theme, permissions)" -ForegroundColor Green
}

# ── 7. Install Claude agents ──────────────────────────────────────────────────
Write-Host "`n[7/8] Installing Claude agents (core-team + enterprise)..." -ForegroundColor Yellow
& "$repoRoot\install.ps1"

# ── 8. Wire up post-commit auto-push hook ─────────────────────────────────────
Write-Host "`n[8/8] Wiring post-commit auto-push hook..." -ForegroundColor Yellow
git -C $repoRoot config core.hooksPath .githooks
Write-Host "      core.hooksPath = .githooks (commits will auto-push to origin)" -ForegroundColor Green

# ── Done ─────────────────────────────────────────────────────────────────────
Write-Host "`n=== Setup complete ===" -ForegroundColor Cyan
Write-Host @"

Remaining manual steps:
  1. SSH KEY   — Copy id_ed25519 (private key) to ~/.ssh/id_ed25519
                 Then run: ssh-add ~/.ssh/id_ed25519
                 Or generate a new key: ssh-keygen -t ed25519 -C "perezbox3@gmail.com"
                 Then add the public key to each server's ~/.ssh/authorized_keys

  2. IPAUTH    — Edit your PowerShell profile and fill in the real API keys:
                 notepad `$PROFILE
                 (Keys are in your ipauth.net dashboard per server)

  3. CLAUDE    — Authenticate Claude Code:
                 claude

  4. GITHUB    — Authenticate GitHub CLI:
                 gh auth login

  5. RESTART   — Open a new PowerShell window to load the profile and PATH changes

"@ -ForegroundColor Yellow
