# Agent Team

One human writes the code. The agents plan, advise, gate, and untangle — the guardrails and
guidance you would get on a real team, made explicit.

**This repo is the source of truth for agent development.** Edit agents here, then redeploy.
If an agent definition differs between this repo and a machine, this repo wins.

---

## The workflow

### Every day: the loop

```
1. PLAN     tech-lead turns the goal into scoped tasks, each with a definition of done
2. BUILD    you write every line; one task in flight; tests ride with the task
3. DISCUSS  senior-dev-mentor: options with tradeoffs, one recommendation, the why
4. GATE     code-reviewer always; security-reviewer when the task touches
            auth, input, secrets, money, or outbound requests
   STUCK?   diagnostic-engineer maps the system, traces the symptom with evidence
```

### Beyond MVP: the pipeline

When a build graduates toward production, the enterprise seats join:
- **architect-reviewer** — gates non-trivial designs before code is written
- **platform-readiness-reviewer** — the once-per-product stage gate at MVP → production
- **test-engineer** — behavior + failure-path + migration tests that run in CI
- **devops-engineer** — repeatable deploys, rollback, observability
- **docs-engineer** — done includes documented

## Rules of the road

- **Nothing merges unreviewed** — the gate is the point of having a team
- **Diagnose before you fix** — no cause asserted without evidence
- **Plan before you build** — done is defined before work starts
- **Agents advise and gate; they never build for you**
- **Enforcement is deterministic** — rules that must always hold live in CI or hooks, not prompts

---

## Repo structure

```
claude-agents/
├── .githooks/
│   └── post-commit           # Auto-pushes every commit to origin
├── architecture/             # Current-state SVG diagrams
├── config/                   # Machine config templates (no secrets)
│   ├── claude_settings.json  # Claude Code permissions + theme
│   ├── powershell_profile.ps1  # Server status checker (fill in ipauth keys)
│   └── ssh_config            # SSH host shortcuts
├── core-team/                # 5 always-on agent seats
│   ├── tech-lead.md
│   ├── senior-dev-mentor.md
│   ├── diagnostic-engineer.md
│   ├── code-reviewer.md
│   ├── security-reviewer.md
│   ├── README.md
│   └── INSTRUCTIONS.md       # Worked use cases with exact prompts
├── docs/
│   ├── agents-hooks-loops.md # How agents, hooks, and loops differ
│   └── why-agents.md
├── enterprise/               # 5 seats added as the product grows
│   ├── platform-readiness-reviewer.md
│   ├── architect-reviewer.md
│   ├── test-engineer.md
│   ├── devops-engineer.md
│   ├── docs-engineer.md
│   ├── README.md
│   └── INSTRUCTIONS.md
├── mvp/                      # MVP-phase playbook
│   └── README.md
├── CLAUDE.md                 # This file
├── install.ps1               # Deploys agents to ~/.claude/agents/
├── setup.ps1                 # Full bootstrap for a new Windows machine
└── sync.sh                   # Pull + commit + push reconciliation (Git Bash)
```

---

## New machine setup

### Quick start
```powershell
git clone https://github.com/perezbox3/claude-agents.git ~/Projects/claude-agents
cd ~/Projects/claude-agents
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
| 7 | Deploys all 10 agents (core-team + enterprise) to `~/.claude/agents/` |
| 8 | Wires the post-commit hook so every commit auto-pushes to origin |

### After running setup.ps1 — 5 manual steps

**1. SSH key** — the private key is never in this repo. Copy it from your existing machine:
```bash
# On old machine (Git Bash):
scp ~/.ssh/id_ed25519 USERNAME@NEWMACHINE:/path/
# On new machine — place it at ~/.ssh/id_ed25519 then:
ssh-add ~/.ssh/id_ed25519
```
Or generate a fresh one and add the public key to each server's `~/.ssh/authorized_keys`:
```powershell
ssh-keygen -t ed25519 -C "perezbox3@gmail.com"
```

**2. ipauth.net keys** — the PowerShell profile uses placeholder keys. Fill in the real ones:
```powershell
notepad $PROFILE
```
Replace `YOUR_DEV_AUTH_KEY`, `YOUR_DEV_QUERY_KEY`, etc. from your ipauth.net dashboard.

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
```
ssh development   # 104.237.131.5   (perezbox3)
ssh dhfc          # 45.79.71.196    (deploy)
ssh projects      # 173.255.195.153 (perezbox3)
ssh personal      # 45.33.119.137   (perezbox3)
```

---

## Claude Code on Windows — known gotchas

- **Use PowerShell for SSH/SCP/SFTP, not Bash.** Git Bash's ssh doesn't share the
  Windows OpenSSH agent/credentials — commands that work in PowerShell can fail
  with "Permission denied" in Bash using the exact same key. If SSH fails, retry
  in the other shell before assuming a key/auth problem.
- **Text piped through PowerShell into a native process can pick up a UTF-8 BOM**,
  even from a verified BOM-free source, even after `$OutputEncoding` fixes. This
  silently corrupts scripts, commit messages, and any file edited locally then
  pushed to a Linux server (a real one-line change can show up as the whole file
  changed in `git diff`). Fix: base64-encode locally, decode remotely
  (`base64 -d`) — the only method that's held up reliably. For multiple files,
  use `sftp -b <batchfile>` (one connection) rather than embedding several files'
  content in one command string (hits Windows' argument-length limit fast).
- **Don't add `ControlMaster`/`ControlPersist` to `ssh_config` on Windows —
  it doesn't work.** Tried it 2026-08-06: it broke SSH entirely
  (`getsockname failed: Not a socket` on every connection, not just a
  multiplexing failure). Win32-OpenSSH's ControlMaster backgrounding depends
  on Unix `fork()` semantics Windows doesn't have. There is no config-level
  fix for the rate-limit issue on this platform — the only real mitigation is
  discipline: batch related remote commands into one `ssh host "cmd1 && cmd2"`
  call, and never fire multiple separate SSH connections to the same
  rate-limited host in one turn, sequential or parallel.

---

## Keeping in sync

- **Commit = published.** The `.githooks/post-commit` hook pushes every commit automatically.
  First-time setup per clone (done by `setup.ps1`): `git config core.hooksPath .githooks`
- **`./sync.sh` = reconcile.** Pulls, commits any local uncommitted edits, and pushes.
  Run it at start and end of day (Git Bash on Windows).

---

## Updating agents on an existing machine

```powershell
cd ~/Projects/claude-agents
git pull
.\install.ps1
```

---

## Deploying agents per-project (preferred for shared repos)

Copy agent files into the product repo's `.claude/agents/` so they travel with the code:
```powershell
# From the product repo root:
Copy-Item ~/Projects/claude-agents/core-team/*.md .claude/agents/ -Force
# Add enterprise seats as needed
Copy-Item ~/Projects/claude-agents/enterprise/architect-reviewer.md .claude/agents/ -Force
```

Commit `.claude/agents/` — teammates and cloud sessions pick them up automatically.
