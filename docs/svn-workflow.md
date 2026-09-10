# SVN Workflow — Work Projects

> **Last updated:** 2026-09-10
> **Status:** setup verified working; deploy step not yet confirmed with Tony.

The company is pivoting off GitHub onto a self-hosted Subversion server (`svn01`)
for **work projects**. Personal projects stay on GitHub. This doc is the flow I
should be implementing.

---

## The setup

- **Server:** `svn01.netsec-ops.com` → SSH alias `svn01` (`149.248.6.219`, user `svn`), Subversion 1.14.5
- **Access:** SSH-only, IP-gated (IPAuth allowlist), **per-repository grants**, deny-by-default
- **This machine:** configured and verified (SlikSvn 1.14.2, `~/.ssh/config` alias, `%APPDATA%\Subversion\config` `[tunnels]` → Windows OpenSSH, `ssh -T svn01` handshake OK)
- **Key:** `~/.ssh/id_ed25519` is passphrase-protected and no ssh-agent runs by default. Once per session:
  ```
  eval $(ssh-agent -s); ssh-add ~/.ssh/id_ed25519
  ```
  Otherwise every `svn` command prompts for the passphrase.

### On a new device

1. Install an SVN client — pin the 1.14 family (`winget install --id Slik.Subversion --exact`)
2. Send Tony the **public** key (`~/.ssh/id_ed25519.pub`); generate one with `ssh-keygen -t ed25519` if needed
3. Open the personal IPAuth link from the network I'll work on; wait ~2 min
4. Add `svn01` to `~/.ssh/config`:
   ```
   Host svn01
       HostName 149.248.6.219
       User svn
       IdentityFile ~/.ssh/id_ed25519
   ```
5. Windows only — point SVN at OpenSSH in `%APPDATA%\Subversion\config`:
   ```
   [tunnels]
   ssh = C:/Windows/System32/OpenSSH/ssh.exe -q
   ```
   (Forward slashes. SVN's tunnel parser eats single backslashes.)
6. Verify: `ssh -T svn01` → success is one line starting `( success ( 2 2 ( ) ( edit-pipeline`

---

## Which system does a project use?

| Type | Goes to | Projects |
|---|---|---|
| **Work** | svn01 | noc, networktesting, verifyfiltering, dnsarchive, cleanbrowsing, trunc |
| **Personal** | GitHub | serverrat, relay, gamepickle, OpenFrontIO, client sites, devshell, rest |

**Unsure?** Check svn01's repo list: `r2` or higher = migrated, SVN is the source of
truth, GitHub is frozen. "not migrated" = still on GitHub, work as before.
**Never commit to both for the same project** — that creates silent drift.

---

## What I have access to

Snapshot 2026-09-02. Grants change — a real checkout is the truth.

| Repo | Migrated | My access |
|---|---|---|
| `websites/verifyfiltering` | r5 | **rw** |
| `dashboards/verifyfiltering` | r3 | **rw** |
| `websites/dnsarchive` | r2 | **rw** |
| `websites/networktesting` | r3 | **rw** |
| `dashboards/dnsarchive` | not migrated (GitHub) | rw (placeholder) |
| `backend/vouch` | r4 | r (read only) |
| `tools/claude-agents` | r10 | r (read only) |

**No grant yet — ask Tony:** `noc` (websites/dashboards/content), `trunc`,
`cleanbrowsing`, `tools/deploy-toolkit`, everything else. A checkout of an
ungranted repo fails with `Authorization failed` — ask, don't retry.

Checkout URL shape: `svn+ssh://svn@svn01/<category>/<name>/trunk`

---

## The workflow

`PLAN → LOCAL → VERIFY → COMMIT → DEPLOY`

1. **PLAN** — agree the approach before writing code (unchanged).
2. **LOCAL**
   - `svn update` **before the first edit** — every session, every working copy. No branch protects a stale file.
   - Make the change in the working copy (`~/Projects/<name>`).
   - `svn status` → `svn add <path>` for anything showing `?`.
3. **VERIFY** — lint / tests / manual smoke test (unchanged).
4. **COMMIT** *(this replaces "push")*
   - `svn update` again if it's been a while. Resolve conflicts by hand — **never** `--accept theirs-full` / `mine-full`.
   - `svn commit -m "type(scope): why this change"` — goes straight to trunk on the server. Minimum 5 chars. Permanent. No amending.
   - Substantial change → branch first:
     `svn copy ^/trunk ^/branches/<name> -m "..."`, post the `svn diff` for review, merge back.
   - Release → `svn copy ^/trunk ^/tags/<name> -m "..."`.
5. **DEPLOY** — ⚠️ **not confirmed.** The old "git pull on the dev server" step is
   retired. Dev notes say: copy specific files from the working copy to the server;
   the file list belongs in each project's README. Confirm the real target and
   mechanism with Tony (and get the `tools/deploy-toolkit` grant if that's the tool).

### Command cheat-sheet

```
svn update                  # pull — FIRST, always
svn status                  # what changed (? = untracked, needs svn add)
svn diff                    # review changes
svn add <path>              # stage a new file
svn add --force .           # stage everything not under version control
svn commit -m "message"     # commit + push in one (straight to server)
svn log -l 10               # recent history
svn log -v -r 42            # what changed in revision 42
svn revert <path>           # discard local changes to a file
svn status -u               # ask server what's newer (* = server ahead)
```

Git → SVN muscle memory: `pull → update`, `add → add`, `commit + push → commit`.

---

## How SVN differs from Git (the parts that bite)

- **No local repo, no staging, no offline commits.** `svn commit` goes straight to the server. If svn01 is down, nobody commits.
- **New files need `svn add`.** `svn status` marks them `?` and they're skipped until added — no `commit -a` equivalent.
- **Revisions are one repo-wide integer.** "Broke in r47" is a complete statement.
- **History is immutable.** No amend, no rebase, no force-push, no `filter-repo`. Log messages are permanent — write them for whoever reads them in a year.
- **A committed secret can't be removed, only rotated.** Sweep for credentials before the first commit of any tree.
- **Conflicts resolve at commit time.** Different lines auto-merge on `svn update` (`G`). Same line → `C` + conflict markers + `.mine` / `.rOLD` / `.rNEW`; commit blocked until `svn resolve --accept working <file>`.
- **Binaries don't merge at all.** `svn lock <file>` before editing, `svn unlock` after.
- **`svn:ignore` is a per-directory property**, not recursive, no `.gitignore` file.
- **`svn:eol-style=native`** — if every file suddenly shows modified, it's CRLF vs LF, not a real change.
- **One working copy per project.** Never put a working copy in Dropbox / OneDrive / iCloud (corrupts the `.svn` SQLite db).

### What the server rejects

Log message < 5 chars · credentials in a file · Windows-illegal filenames
(`: * ? " < > |`, trailing dots, `CON`/`PRN`/`AUX`/`NUL`/`COM1`) · case-colliding
filenames · files > 100 MB · modifying a tag.

### Review without pull requests

No PRs, no review UI, no protected trunk. Convention:
- Small, obvious changes → straight to trunk with a log message that explains *why*.
- Anything substantial → branch, post the `svn diff` for review, merge back.

---

## Access troubleshooting

| Symptom | Cause |
|---|---|
| `Connection timed out` | IP not on the allowlist. Reopen the IPAuth link, wait ~2 min. |
| `Permission denied (publickey)` | Key not installed, or wrong user. URL must say `svn@svn01`. |
| `Authorization failed` | Reached the server, no grant for that repo. Ask Tony. |
| Commit blocked by `... hook` | A server rule fired — the message names which. Fix the cause, don't look for a bypass. |

Anything that looks like data loss: stop and ask Tony. Working copies are cheap to
recreate; a bad commit is permanent.

---

## Open items

1. **Where the work-project apps run** — not confirmed; likely in each project's README once checked out.
2. **Deploy mechanism** — dev notes describe the principle, not a tool. `tools/deploy-toolkit` (r19) may be it; I'm not granted.
3. **Missing grants** — noc, trunc, cleanbrowsing. I've committed to these before but have no SVN grant yet.
