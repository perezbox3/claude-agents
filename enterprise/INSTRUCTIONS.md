# Enterprise: how to actually use these agents

The [README](README.md) explains what this bucket is; this is the operating manual with the
prompts. The worked example continues from
[core-team/INSTRUCTIONS.md](../core-team/INSTRUCTIONS.md): the expense tracker now has its
first paying customer on the horizon - a 12-person company wants to use it as a team.

## When this bucket activates

Any exit signal from [mvp/README.md](../mvp/README.md): a first paying customer or a signed
commitment, opening signups to strangers, a first external API consumer, or the team deciding
"this is going to production." At that moment, run the stage gate ONCE. Until then, this
bucket stays closed and you build lean with the core team.

---

## The stage gate: platform-readiness-reviewer

State the product, the MOTION (B2B / B2C / reseller), and what "production" means - the
verdict depends on the market you name:

> Use platform-readiness-reviewer. Product: the expense tracker at ~/code/expenses. Motion:
> B2B, small teams (5-50 people), one company = one account with multiple users. "Production"
> means: first paying customer onboards next month, self-serve signup stays closed for now.
> Today it is a single-user app. Run the gate.

**What you get back:** a verdict (READY / READY-WITH-SIGNOFFS / NOT-READY), the 10-category
scorecard with evidence (it reads your actual schema and routes, not your README), and the gap
list ranked by retrofit cost. For this example, expect something like:

- **ONE-WAY-DOOR:** the schema has no org level - expenses hang off a user, but the buyer is a
  company. Adding orgs later means migrating every table. Fix before launch.
- **RETROFIT-HARD:** no usage metering events; per-seat billing cannot be computed later.
- **BOLT-ON:** no audit export for the customer admin - date it, ship anyway.

**What you do with it:**
1. Copy the scorecard into the product repo (`docs/PLATFORM-READINESS.md`).
2. Work the ONE-WAY-DOORs first - each becomes a tech-lead breakdown like any other goal
   ("Use tech-lead. Goal: introduce an organizations table and scope expenses to org...").
3. Sign the accepted-risk line for anything you consciously ship open.
4. Re-score when the doors close: "Use platform-readiness-reviewer. Re-score against
   docs/PLATFORM-READINESS.md; the org model shipped, metering shipped, audit export still
   open."

## The growth seats

Add each seat when its stage starts hurting, in roughly this order. Same golden rule as the
core team: the agent starts cold; brief it fully.

### architect-reviewer (PLAN) - before any non-trivial design

The one-way doors stop being a side check and become a real design review:

> Use architect-reviewer. Design to review before I build it: introducing organizations to the
> expense tracker. Plan: new orgs table, users get org_id, expenses scoped through the user's
> org, org-admin role approves expenses over a limit. Repo ~/code/expenses, current schema in
> db/schema.sql. Interrogate it.

You get a GO / GO-WITH-CHANGES / NO-GO with ranked findings (expect it to ask: what happens to
an expense when its user leaves the org? who owns receipts at offboarding? is the approval
limit money stored as DECIMAL?). Resolve BLOCKERs before tech-lead breaks the work down.

### test-engineer (TEST) - when the suite becomes the merge gate

> Use test-engineer. The org model just shipped on branch orgs-v1 (~/code/expenses). Write the
> isolation tests: org A users must never read or write org B expenses or receipts, on every
> route. Also the entitlement boundaries: seat limit reached, member removed mid-session.
> Wire whatever you write into the existing CI config so it gates merges.

It writes tests only - if it finds a bug, it reports; the fix is yours, gated as usual.

### devops-engineer (DEPLOY) - when deploys stop being "copy files"

> Use devops-engineer. ~/code/expenses deploys today by copying files to one VPS by hand.
> First paying customer arrives next month. Set up: a staging environment, a repeatable deploy
> script with rollback, a health endpoint, and a backup with a TESTED restore. Production
> promotion stays manual.

### docs-engineer (OPERATE) - at the end of every build, and periodically

> Use docs-engineer. The org model and the new deploy pipeline shipped this week in
> ~/code/expenses. Run the documented-checklist: README quickstart, runbook lines for the new
> service and cron, restore notes, and flag any diagram now lying. Write what is missing.

Periodically (monthly is fine), drift mode:

> Use docs-engineer, drift mode. Diff the last month of commits in ~/code/expenses against the
> docs and give me the gap list ranked by restore-risk.

---

## Quick reference

| Situation | Type this |
|---|---|
| First customer / open signup approaching | "Use platform-readiness-reviewer. Product: ... Motion: ... Production means: ... Run the gate." |
| Gaps closed, want the doorway re-checked | "Use platform-readiness-reviewer. Re-score against docs/PLATFORM-READINESS.md; shipped: ..., still open: ..." |
| Non-trivial design before code | "Use architect-reviewer. Design to review: ... Current schema: ... Interrogate it." |
| Multi-user feature shipped | "Use test-engineer. Write the isolation + boundary tests for ... and wire them into CI." |
| Deploys are scary | "Use devops-engineer. Today we deploy by ... Set up staging, rollback, health, tested restore." |
| Build week ends | "Use docs-engineer. Shipped this week: ... Run the documented-checklist." |

## Anti-patterns

- **Running the stage gate per change.** It is once per product, then re-scores. Per-change
  gating is code-reviewer and security-reviewer's job.
- **Running it without naming the motion.** B2B-teams vs B2C-single-user changes which gaps are
  real; an unstated market gets you a hedged scorecard.
- **Treating BOLT-ONs as blockers.** Date them and ship. The gate ranks by retrofit cost
  precisely so launch does not wait on a status page.
- **Treating ONE-WAY-DOORs as bolt-ons.** The whole point: schema, money, time, and contracts
  are cheap now and brutal later. These either close or get a signed accepted-risk line.
- **Adopting all four growth seats on day one.** Add a seat when its stage hurts; a 12-person
  customer does not need an SRE practice.
