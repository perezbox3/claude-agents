# Core Team: how to actually use these agents

This is the operating manual. The [README](README.md) tells you who the seats are; this tells
you exactly what to type, when, and what you get back. One worked example runs through the
whole flow: **adding receipt upload to an expense-tracker app.**

## The golden rule of invocation

**The agent cannot see your conversation.** It starts cold, every time, on purpose (that is
what makes its review independent). So brief it like you would brief a teammate who just
walked in:

- WHAT you want (the goal or the question)
- WHERE the code is (repo path, branch, the files involved)
- WHAT you already tried or decided
- WHAT you want back (a plan? options? a verdict?)

A lazy invocation ("review my code") gets a lazy result. A briefed invocation gets a teammate.

---

## The flow, worked end to end

### Step 1: PLAN - tech-lead (breakdown mode)

You have a goal, not a plan. Type:

> Use tech-lead. Goal: add receipt upload to the expense tracker so a user can attach a photo
> or PDF of a receipt to an expense entry. Repo is at ~/code/expenses, main branch. What exists:
> expense CRUD works, no file handling anywhere yet. I want the breakdown.

**What you get back:** the plan block - the riskiest assumption, ordered tasks (max ~3) each
with scope, a definition of done, its gate, and the literal first step. tech-lead also writes
it to `docs/PLAN-receipt-upload.md` so it survives the session.

**What you do:** start task 1. One task in flight. Branch per task.

### Step 2: BUILD - you

You write every line. Tests ride with the task (the DoD says which). When you hit a design
fork mid-build, that is the next step.

### Step 3: DISCUSS - senior-dev-mentor (when weighing options)

> Use senior-dev-mentor. I am on task 2 of docs/PLAN-receipt-upload.md: storing the uploaded
> receipts. I see three options: files on disk under uploads/, BLOBs in the database, or an
> S3-style bucket. The app runs on a single small VPS today. I started writing the disk
> version, file storage.py. What are the tradeoffs and what would you do?

**What you get back:** the options with honest tradeoffs, ONE recommendation with the why,
maybe a 10-line sketch of the shape, and 1-3 questions you should be able to answer about your
own code. It will measure ("I timed both") rather than guess where it can.

**What you do:** decide. The mentor recommends; you own the decision.

### Step 4 (when needed): STANDUP - tech-lead (standup mode)

You have been "improving the thumbnail generation" for two hours. Type:

> Use tech-lead, standup mode. Plan: docs/PLAN-receipt-upload.md. Since last check: finished
> storage (task 2), then started adding thumbnail previews with three size variants and a
> background queue. Uncommitted work in src/thumbs/. Am I on track?

**What you get back:** the call. This one is a RABBIT-HOLE: thumbnails are not in any task's
scope. It parks the idea on the PARKED list, names where you left off, and points you back to
task 3.

### When STUCK: diagnostic-engineer

Something breaks and you cannot see the shape of it. Give it the symptom, not your theory:

> Use diagnostic-engineer. Symptom: uploading a receipt over ~2MB returns a 500, smaller files
> work. Repo ~/code/expenses, branch receipt-upload. Tried: increasing the framework body-size
> limit in config/app.php, no change. The error log shows nothing for the failing request.
> I want the trace and the root cause, not a guess.

**What you get back:** the map of the upload path with file:line anchors, the trace to the
divergence point, a root cause labeled CONFIRMED or SUSPECTED (with the observation that would
settle it), what was RULED OUT, the blast radius (the same missing limit on the avatar upload
you forgot about), and HOW I FOUND IT so you can run the trace yourself next time.

**What you do:** build the fix yourself, then gate it like any other change.

### Step 5: GATE - code-reviewer, then security-reviewer

Task done? It does not merge on your say-so. Two invocations, fresh context each:

> Use code-reviewer. Review the diff on branch receipt-upload vs main in ~/code/expenses.
> The change adds receipt upload: routes/receipts.php, src/storage.php, tests/receipt_test.php.
> Definition of done from docs/PLAN-receipt-upload.md task 3 applies.

> Use security-reviewer. Same branch and files. This change accepts file uploads from
> authenticated users and writes them to disk - input handling and file storage are the
> surfaces. Per the team rule, uploads always get a security pass.

**What you get back:** verdicts. BLOCK means fix and resubmit (the findings name file:line and
the specific fix). APPROVE-WITH-NOTES means the notes are your call. Security BLOCKs do not
ship, period.

**The trigger rule for security-reviewer:** anything touching auth, input handling (uploads
count), secrets, money, or outbound requests. When in doubt, run it.

### Step 6: DONE-CHECK - tech-lead (done-check mode)

> Use tech-lead, done-check mode. Task 3 of docs/PLAN-receipt-upload.md. Branch
> receipt-upload, tests pass locally, code-reviewer APPROVE-WITH-NOTES (notes addressed),
> security-reviewer PASS. Check it against the DoD.

**What you get back:** DONE or NOT-DONE, the DoD graded line by line with evidence. DONE means
merge. NOT-DONE names exactly what remains.

---

## Quick reference

| Situation | Type this |
|---|---|
| New goal, no plan | "Use tech-lead. Goal: ... Repo: ... What exists: ... I want the breakdown." |
| Mid-task drift check | "Use tech-lead, standup mode. Plan: docs/PLAN-x.md. Since last check: ..." |
| Weighing approaches | "Use senior-dev-mentor. I am on task N. Options I see: ... I tried: ... What would you do?" |
| Something is broken | "Use diagnostic-engineer. Symptom: ... Tried: ... I want the trace, not a guess." |
| Ready to merge | "Use code-reviewer. Review branch X vs main, files ... DoD from docs/PLAN-x.md." |
| Touches auth/input/secrets/money | "Use security-reviewer. Same branch. The surfaces are ..." |
| Think the task is done | "Use tech-lead, done-check mode. Task N, evidence: ..." |

## Anti-patterns (the ways people waste this team)

- **The vague brief.** "Review my code" / "it's broken" - the agent cannot see your chat;
  context you do not give is context it does not have.
- **Asking the mentor to write it.** It will not, by design. Bring options and your attempt,
  take back judgment.
- **Skipping the gate because the change is small.** Small changes break production at the
  same rate per line. Nothing merges unreviewed.
- **Leading the diagnostic with your theory.** Give the symptom and the evidence; let it trace.
  Your theory goes at the end, labeled as a theory, if at all.
- **Two tasks in flight.** Finish one. tech-lead will call this out in standup; save it the
  trouble.
- **Treating BLOCK as an insult.** It is the team working. Fix, resubmit, move on.
