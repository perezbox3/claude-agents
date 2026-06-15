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

## Installing Agents
Run `install.ps1` (Windows) to copy agents into `~/.claude/agents/` where Claude Code picks them up globally.

## On a New Machine
```
git clone https://github.com/perezbox3/claude-agents.git ~/claude-agents
cd ~/claude-agents
./install.ps1
```
