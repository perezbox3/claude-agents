# Agent Team Loop

One human, five agents. You write every line of code. The agents plan, advise, gate, and untangle.

## The Flow

```
tech-lead (PLAN)
     ↓
YOU (BUILD) ←──────────────────────────────┐
     │                                      │
     ├── stuck/broken → diagnostic-engineer │
     │        └── map + trace + fix shape ──┘
     │                                      │
     ├── want to discuss → senior-dev-mentor│
     │        └── options + recommendation ─┘
     │
     ↓
GATE (submit for review)
     ├── code-reviewer → BLOCK / APPROVE-WITH-NOTES / APPROVE
     └── security-reviewer (auth/input/secrets/money) → BLOCK / PASS
          └── APPROVE → DONE (merged, tests passing, runnable from README)
               └── BLOCK → fix + resubmit ──────────────────────────────┘
```

## Agents

| Agent | Invoke when | Output | Never does |
|---|---|---|---|
| `tech-lead` | Starting a task, standup check-in, done-check | Plan / ON-TRACK / PASS | Write code |
| `diagnostic-engineer` | Lost or something breaks | Map + trace + fix shape | Write the fix |
| `senior-dev-mentor` | Weighing options or approaches | Options + recommendation + questions | Write the feature |
| `code-reviewer` | Before every merge | BLOCK / APPROVE-WITH-NOTES / APPROVE | Write the fix |
| `security-reviewer` | Before merge when touching auth/input/secrets/money | BLOCK / PASS | Write the fix |

## Rules of the Road
- **Nothing merges unreviewed** — the gate is the point of having a team
- **Diagnose before you fix** — no cause asserted without evidence
- **Plan before you build** — done is defined before work starts
- **Agents advise and gate; they never build for you**

---

## New Machine Setup

### Quick start
```powershell
git clone https://github.com/perezbox3/claude-agents.git ~/claude-agents
cd ~/claude-agents
.\setup.ps1
```

`setup.ps1` handles everything automatically:

| Step | What it does |
|---|---|
| 1 | Sets `ExecutionPolicy = RemoteSigned` for CurrentUser |
| 2 | Installs Git, Node.js LTS, Python 3.13, GitHub CLI, VS Code, Claude Desktop via winget |
| 3 | Sets git global config (name + email) |
| 4 | Copies SSH config with host shortcuts (development, dhfc, projects, personal) |
| 5 | Installs PowerShell profile (server status on shell open) |
| 6 | Installs Claude Code settings (theme, permissions) |
| 7 | Deploys all 5 agents to `~/.claude/agents/` |

### After running setup.ps1 — 5 manual steps

**1. SSH key** — the private key is never in this repo. Either copy it from your existing machine:
```
# On old machine (Git Bash):
scp ~/.ssh/id_ed25519 USERNAME@NEWMACHINE:/path/
# On new machine — place it at ~/.ssh/id_ed25519 then:
ssh-add ~/.ssh/id_ed25519
```
Or generate a fresh one and add the public key to each server's `~/.ssh/authorized_keys`:
```powershell
ssh-keygen -t ed25519 -C "perezbox3@gmail.com"
# Then copy ~/.ssh/id_ed25519.pub to each server
```

**2. ipauth.net keys** — the PowerShell profile uses placeholder keys. Edit it and fill in the real ones from your ipauth.net dashboard:
```powershell
notepad $PROFILE
```
Replace `YOUR_DEV_AUTH_KEY`, `YOUR_DEV_QUERY_KEY`, etc.

**3. Claude Code** — authenticate:
```powershell
claude
```

**4. GitHub CLI** — authenticate:
```powershell
gh auth login
```

**5. Restart PowerShell** — so PATH and profile changes take effect.

### SSH host shortcuts (after keys are set up)
```powershell
ssh development   # 104.237.131.5  (perezbox3)
ssh dhfc          # 45.79.71.196   (deploy)
ssh projects      # 173.255.195.153 (perezbox3)
ssh personal      # 45.33.119.137  (perezbox3)
```

### Repo structure
```
claude-agents/
├── agents/               # Agent definition files (deployed by install.ps1)
│   ├── code-reviewer.md
│   ├── diagnostic-engineer.md
│   ├── security-reviewer.md
│   ├── senior-dev-mentor.md
│   └── tech-lead.md
├── config/               # Machine config templates (no secrets)
│   ├── ssh_config        # SSH host shortcuts
│   ├── powershell_profile.ps1  # Server status checker (fill in ipauth keys)
│   └── claude_settings.json   # Claude Code permissions + theme
├── CLAUDE.md             # This file
├── install.ps1           # Deploys agents only (called by setup.ps1)
└── setup.ps1             # Full bootstrap for a new machine
```

### Updating agents on an existing machine
```powershell
cd ~/claude-agents
git pull
.\install.ps1
```
