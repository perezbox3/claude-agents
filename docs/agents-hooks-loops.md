# Agents, Hooks, and Loops - what they are and where they run

Claude Code gives you three different automation primitives, and the most common mistake is
using one where another belongs. The short version:

| Primitive | What it is | Deterministic? | Reach for it when |
|---|---|---|---|
| **Agent** | An AI teammate: its own instructions, its own context window, its own tools | No - it exercises judgment | The work needs judgment: review, diagnosis, planning, a verdict |
| **Hook** | A shell command the harness runs automatically at a lifecycle event | Yes - it runs no matter what the model thinks | Something must ALWAYS or NEVER happen: enforcement, rails |
| **Loop** | Recurring execution of a prompt or task on a schedule | The schedule is; the run is an AI session | The work repeats on a clock: checks, digests, chores |

The doctrine that ties them together: **consequential decisions ride on deterministic code;
agents narrate, draft, and judge; hooks enforce; loops repeat.** An instruction in a prompt is
a request. A hook is a law. Never use an agent (or a memory, or a prompt rule) where a law is
needed.

---

## Agents (judgment)

An agent is a markdown file with YAML frontmatter (name, description, tools, model) followed by
its instructions - the agent definitions in this repo's `core-team/` and `enterprise/` folders
are exactly this format.

**Where they live:**
- `~/.claude/agents/` - user-level, available in every project on that machine
- `.claude/agents/` - project-level, travels with the repo; takes precedence over user-level

**How they work:** the main session spawns the agent with a task; it gets a FRESH, isolated
context window (it cannot see your conversation - anything it needs must be in the invocation),
runs with only the tools its frontmatter allows, does its work, and returns a result. That
isolation is a feature: a reviewer that cannot see the author's reasoning cannot be talked into
agreeing with it.

**What they are not:** enforcement. An agent can be persuaded, can misread, can have an off day.
A "never merge without review" rule implemented as an agent instruction is a suggestion. The
gate is real only when the pipeline (CI) or a hook makes it mechanical.

## Hooks (enforcement)

A hook is a shell command the harness executes automatically at a lifecycle event:
`PreToolUse` (can BLOCK a tool call before it happens), `PostToolUse`, `UserPromptSubmit`,
`SessionStart`, `Stop`, and roughly thirty more.

**Where they live:** `settings.json`, in precedence order:
1. `~/.claude/settings.json` - user-level, every project on the machine
2. `.claude/settings.json` - project-level, committed, shared with the team
3. `.claude/settings.local.json` - project-level, gitignored, this machine only

**Why they matter:** hooks run *regardless of what the model decides*. They are the rails. If
you find yourself writing "always do X before Y" or "never touch Z" into an agent prompt or a
memory more than once, that rule wants to be a hook. Examples: block a dangerous command
pattern before it executes, auto-run a formatter after every file edit, load project context
when a session starts, scan output for things that must never ship.

**The critical limitation: hooks are LOCAL-ONLY.** They run in the CLI and the desktop app.
They do NOT run in cloud sessions - committed `.claude/settings.json` hooks do not execute on
Anthropic's infrastructure. Consequence: any enforcement that must hold everywhere belongs in
CI (which runs on every surface), not in a hook. Hooks guard your local sessions; CI guards
the repo.

## Loops (recurrence)

"Loops" is really three features depending on where the recurring work runs:

**1. `/loop` - in-session, CLI only.** Repeats a prompt on an interval (or self-paced) inside
your live session. Dies with the session; expires after 7 days regardless. Use for: watching
something during a work session ("check the deploy every 5 minutes").

**2. Local scheduled tasks - desktop app (created there or via `/schedule` in the CLI).** Run
on YOUR machine, with access to your local files and tools, but only while the desktop app is
open and the machine is awake. Minimum interval one minute. Use for: recurring chores that need
your local environment.

**3. Cloud routines - claude.ai/code/routines.** Run on Anthropic's infrastructure on a cron
schedule (minimum one hour), even when your machine is off. Each run gets a FRESH clone of the
repo, runs autonomously (no permission prompts), and can be triggered by API call or GitHub
events as well as the clock. They carry the repo, committed `.mcp.json`, and account-level
connectors - but NOT your hooks, NOT machine-local config, NOT locally configured MCP servers.
Use for: always-on schedules - a nightly digest, a weekly drift check.

**The team rule on loops:** schedule chores, never judgment gates. A review (code, security,
platform readiness) is run deliberately by a human at the right moment, not on a clock. A loop
that "reviews whatever changed every night" trains you to stop reading the verdicts.

## Skills (the adjacent fourth)

Worth knowing because they sit beside the other three: a skill is a `SKILL.md` playbook invoked
as a slash command (`/deploy-check`) or auto-invoked when its description matches the request.
They live in `~/.claude/skills/` (user) or `.claude/skills/` (project, committed). Unlike an
agent, a skill runs IN your main session with your context - use a skill for a ritual you run
WITH the model, an agent for work you delegate AWAY.

---

## Where each works (verified against the official docs)

| | CLI (terminal) | Desktop app | Cloud (claude.ai/code) |
|---|---|---|---|
| **Agents** | Yes - both user and project level | Yes - same files as CLI | Unverified - docs do not confirm repo-committed `.claude/agents/` load in cloud sessions; test before relying |
| **Hooks** | Yes - all events | Yes - all events | **No - hooks do not run in cloud sessions** |
| **Skills** | Yes | Yes | Partial/unverified - repo-committed skills likely load from the clone, not explicitly documented |
| **`/loop`** | Yes (session-scoped) | No - use routines | No |
| **Local scheduled tasks** | Created via `/schedule` | Yes (runs while app is open) | n/a |
| **Cloud routines** | Created via `/schedule` | Yes (Routines page) | Yes - this is their home |

**The desktop app is not a separate system.** It is the same local harness as the CLI - same
config files, same agents, same hooks, same skills - wrapped in a GUI with parallel sessions
and the routines UI attached. Anything you set up for one works in the other.

**Cloud is the different animal.** Fresh clone per run, autonomous permissions, no hooks, no
machine-local anything. Design for cloud by putting everything that matters IN the repo
(agents, skills, `.mcp.json`, CI) and trusting nothing from your machine.

---

## How this maps to our team

- **The agents in this repo** (`core-team/`, `enterprise/`) are the judgment seats: they plan,
  mentor, diagnose, review, and gate-keep with verdicts. Install them per machine
  (`~/.claude/agents/`) or per product repo (`.claude/agents/`).
- **Hooks** are where we put local session rails as they emerge (a command pattern that must
  never run, a check after every edit). Enforcement that must hold for everyone goes in CI.
- **Loops** are for the chores: when we have a nightly or weekly recurring check, it becomes a
  cloud routine. Reviews never do - a human invokes the gates.

Related: [Why agents instead of one massive session?](why-agents.md) for the reasoning behind
the agent-based team model.

*Verified against the official Claude Code documentation (code.claude.com/docs), 2026-06-12.
The "unverified" cells reflect what the docs do not state - re-check before building on them.*
