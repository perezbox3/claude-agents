# Project Context

Reference this file when invoking agents so they have standing context about the environment
without you having to re-explain it each time.

**Example invocation opener:**
```
Use tech-lead. Context: ~/claude-agents/config/project-context.md. Goal: ...
```

---

## Stack

| Layer | Technology |
|---|---|
| Backend | PHP |
| Frontend | HTML, CSS, JavaScript (vanilla or lightweight libs) |
| Database | MySQL (primary), SQLite (lightweight/embedded projects) |
| Payments | Stripe (stripe-php library) |
| Auth | Custom or simple session-based; no framework-level auth |

No full PHP framework (Laravel/Symfony) assumed — projects are typically custom or lightweight.
Confirm the actual structure when invoking agents on a specific repo.

---

## Servers

| Alias | IP | User | Purpose |
|---|---|---|---|
| `development` | 104.237.131.5 | perezbox3 | Dev / testing |
| `projects` | 173.255.195.153 | perezbox3 | Production projects |
| `dhfc` | 45.79.71.196 | deploy | DHFC deployment |
| `personal` | 45.33.119.137 | perezbox3 | Personal projects |

SSH access: `ssh development`, `ssh projects`, etc. (shortcuts configured in `~/.ssh/config`)

---

## Deploy pattern

No CI/CD pipeline. Manual deploy on every server:

```bash
ssh <server>
cd /var/www/<project>
git pull origin main
```

**Before every deploy:**
- Schema changes run manually via MySQL before `git pull`
- New env vars confirmed present on the server before `git pull`
- Error log tailed during first test after deploy: `tail -f /var/log/<project>/error.log`

No rollback automation — rollback is `git checkout <previous-commit>` or reverting the pull.

---

## Project types

| Type | Description |
|---|---|
| Solo | You are the only developer; no PR review from teammates |
| Collaborative | Other developers involved; PRs and branch-based workflow |

Both types use the full agent gate workflow regardless of team size. Solo does not mean
skipping code-reviewer or security-reviewer — the gate is still run, just agent-driven.

---

## Accounts & repos

| Account | Platform | Used for |
|---|---|---|
| `perezbox3` | GitHub | Personal projects, this agent repo |
| `perezbox` | GitHub | Work/consulting projects (e.g. dev-team) |

---

## Common patterns to watch for

**No migration system.** Schema changes are run manually on each server before deploy.
When a feature adds or alters tables, flag this explicitly in the tech-lead plan so the
deploy step accounts for it.

**Stripe webhooks.** Always verify the signature with the raw request body before any
other processing. PHP's `php://input` stream is consumed on first read — middleware that
reads the body before the webhook handler will cause signature verification to fail.

**Environment variables.** Managed via `.env` files (not committed). New vars must be
manually added to each server's `.env` before deploy. `.env.example` is the documented
contract for what vars are required.

**MySQL on production, SQLite locally (sometimes).** If a project uses SQLite locally and
MySQL in production, query compatibility matters — test on MySQL before deploying.
