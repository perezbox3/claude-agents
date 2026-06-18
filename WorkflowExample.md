# Workflow Example

A full end-to-end walkthrough of one feature using the agent team. This is not abstract —
every prompt is what you would actually type, and every agent response is representative of
what you would get back.

**The scenario:** You are adding a protected `/api/status` endpoint to a Node.js/Express web
project. The endpoint returns server health data and must require an API key. The repo lives
at `~/Projects/myapp`, main branch, and there is no auth anywhere yet.

---

## Step 1 — PLAN: tech-lead (breakdown mode)

You have a goal. You do not have a plan. Start here every time.

**What you type:**
```
Use tech-lead. Goal: add a protected /api/status endpoint to the Express app that returns
server health (uptime, memory, version) and requires a valid API key in the Authorization
header. Repo: ~/Projects/myapp, main branch. What exists: Express app running, no auth
anywhere, no /api routes yet. I want the breakdown.
```

**What you get back:**
```
GOAL: Add a protected /api/status endpoint so operators can programmatically check server
health without exposing it to the public.

RISKIEST ASSUMPTION: The API key validation approach — hardcoded key vs env var vs database
lookup — determines the data model and test surface. Task 1 resolves this by building the
thinnest working version (env var) so the shape is proven before any complexity is added.

TASKS (ordered):

  1. Wire the route and auth middleware (env-var key, no database)
     Scope: create routes/api.js, add GET /api/status returning JSON, write middleware that
     reads Authorization header and compares to API_KEY env var, reject with 401 if missing
     or wrong, mount the router in app.js
     DoD: curl with correct key returns 200 + JSON payload; curl without key returns 401;
          curl with wrong key returns 401; one integration test covers all three cases
     Gate: code-reviewer; security-reviewer (auth + input handling)
     First step: create routes/api.js with a stub GET /api/status that returns {ok: true},
                 mount it in app.js, confirm the route answers before touching auth

  2. Add health payload (uptime, memory, version)
     Scope: populate the response body using process.uptime(), process.memoryUsage(),
     and the version field from package.json; no external calls
     DoD: response includes uptime (seconds), heapUsed (bytes), rss (bytes), version (string);
          values change between calls (uptime increases); test asserts shape, not exact values
     Gate: code-reviewer

  3. Document and harden
     Scope: add API_KEY to .env.example with a comment, add the endpoint to README under
     "API", confirm the key is never logged (grep the codebase)
     DoD: a teammate could set this up from the README alone; no key appears in any log output
     Gate: code-reviewer; security-reviewer

OUT OF SCOPE: key rotation, multiple keys, rate limiting, response caching, metrics history

PARKED: per-key permissions, admin dashboard showing health trends

RE-PLAN AT: after task 2 is done and merged
```

**What you do:** Start task 1. Create a branch: `git checkout -b api-status-auth`.
Write the route stub first — confirm the endpoint answers before touching auth.
One task in flight. The other tasks wait.

---

## Step 2 — BUILD: you write every line

You create `routes/api.js`, write the middleware, add the test. Midway through, you hit a
question: should the middleware live in the route file or in a separate `middleware/` folder?
This is exactly when you call senior-dev-mentor.

---

## Step 3 — DISCUSS: senior-dev-mentor (weighing a design decision)

**What you type:**
```
Use senior-dev-mentor. I am on task 1 of the api-status plan: building the auth middleware
for GET /api/status in ~/Projects/myapp. I have the route working (stub returns 200). Now
I need to put the API key middleware somewhere. I see two options:

  A. Define the middleware inline in routes/api.js — simple, co-located with the route
  B. Put it in middleware/requireApiKey.js — reusable if we add more protected routes later

Today there is only one protected route. What are the tradeoffs and what would you do?
```

**What you get back:**
```
OPTIONS:

  A. Inline in routes/api.js
     + Zero setup cost; the reader sees the whole route in one file
     - If a second protected route appears, you copy-paste the check; now there are two
       places to update when the key format changes
     Risk: low today, grows linearly with the number of protected routes

  B. middleware/requireApiKey.js
     + One definition; every protected route imports it; changes propagate everywhere
     + Testable in isolation — you can unit-test the middleware without spinning up the router
     - One extra file for a function that is currently used once
     Risk: premature if the second protected route never comes; not premature if it does

RECOMMENDATION: B — separate middleware file.

The deciding factor is testability, not reuse. A middleware function that reads a header and
compares it to an env var has its own failure modes (missing header, wrong format, env var
not set). Those are easier to cover in a focused unit test than through the full route.
The file cost is one import line; the test cost savings are real.

Shape:
  middleware/requireApiKey.js exports a single Express middleware function.
  routes/api.js imports it: router.use(requireApiKey) before the status handler.
  Test file: tests/middleware/requireApiKey.test.js — three cases (valid, missing, wrong).

Questions you should be able to answer about your own code:
  1. What does your middleware return when API_KEY is not set in the environment at all?
     (undefined === undefined is true — that is a bug if the env var is missing)
  2. Is the comparison timing-safe? (String equality is not; for an API key check at this
     scale it is probably acceptable, but you should make the decision consciously)
  3. Where does API_KEY get loaded — dotenv in app.js, or assumed to be in the environment?
```

**What you do:** Create `middleware/requireApiKey.js`. The mentor flagged two real issues
(missing env var behavior, timing safety). You decide: add an explicit startup check that
throws if `API_KEY` is not set, and accept plain string comparison for now (document the
decision in a comment). Write the three middleware unit tests. Back to building.

---

## Step 4 — STUCK: diagnostic-engineer (when something breaks)

Task 1 is nearly done. Tests pass locally. You try `curl` with the correct key and get a 401
anyway. You have been staring at it for 20 minutes and cannot see why.

**What you type:**
```
Use diagnostic-engineer. Symptom: GET /api/status returns 401 even when the correct API key
is sent in the Authorization header. Smaller keys work. Repo ~/Projects/myapp, branch
api-status-auth. Tried: console.log in the middleware confirms the header is being read;
compared the key in the log to the env var — they look identical. The middleware is mounted
via router.use(requireApiKey) in routes/api.js. I want the trace, not a guess.
```

**What you get back:**
```
SYSTEM MAP (upload path):
  app.js:12          express.json() middleware
  app.js:18          router mounted at /api → routes/api.js
  routes/api.js:3    requireApiKey middleware (routes/api.js:3 imports middleware/requireApiKey.js)
  middleware/requireApiKey.js:7   header read: req.headers['authorization']
  middleware/requireApiKey.js:9   comparison: header === process.env.API_KEY

TRACE:

  Divergence point: middleware/requireApiKey.js:9

  You said "they look identical" but console.log cannot show whitespace or encoding
  differences. The comparison is a plain string equality check.

  SUSPECTED (HIGH): trailing newline in API_KEY from the .env file.
  dotenv strips trailing newlines on most values, but if API_KEY was set directly in the
  shell environment (export API_KEY="abc123\n") or in a .env file with Windows CRLF line
  endings, the value includes \r or \n. The key you send in the header does not.
  Observation that would CONFIRM this: add console.log(JSON.stringify(process.env.API_KEY))
  — if it shows \r or \n inside the quotes, this is the cause.

  SUSPECTED (MEDIUM): Authorization header includes the "Bearer " prefix.
  If the .env value is the raw key (abc123) but curl sends "Bearer abc123", the comparison
  fails. Check: console.log(JSON.stringify(req.headers['authorization'])) to see the
  exact string received.

  RULED OUT: the middleware not being mounted — you confirmed the header is read, so the
  middleware is running.
  RULED OUT: route path mismatch — same reason.

BLAST RADIUS: the same comparison flaw would affect any other protected route added later.

HOW I FOUND IT: the only way a visually identical string comparison fails is an invisible
character or a format mismatch. Whitespace and prefix are the two most common causes.
```

**What you do:** Run `console.log(JSON.stringify(process.env.API_KEY))`. It shows `"abc123\r"` —
CRLF in the `.env` file. Fix: add `.trim()` to the env var read in the middleware.
Tests pass. Curl with the correct key returns 200.

---

## Step 5 — STANDUP: tech-lead (mid-flight check-in)

Task 1 is done and merged. You've been working on task 2 for a while and also started adding
rate limiting "while you were in there."

**What you type:**
```
Use tech-lead, standup mode. Plan: the api-status plan from step 1 (tasks: 1. auth middleware,
2. health payload, 3. docs/harden). Task 1 merged yesterday. Since then: finished the health
payload (task 2), started adding per-IP rate limiting using express-rate-limit because it
seemed like a good time. That work is in progress in the same branch. Am I on track?
```

**What you get back:**
```
CALL: RABBIT-HOLE

EVIDENCE: task 2 (health payload) is done — that is on track. Rate limiting was explicitly
placed in OUT OF SCOPE in the plan. It is not in any task's definition of done. Adding it
now means two things are in flight on the same branch: the completed task 2 changes and an
uncommitted, unscoped feature.

NEXT ACTION: commit and push what belongs to task 2 (the health payload), then stop.
Open a separate branch for rate limiting. Either add it to the plan as task 4 (with a DoD
and a gate) or move it to PARKED until the current plan is closed.

PARKED: rate limiting (express-rate-limit, per-IP) — good idea, not in scope for this plan.
        Add as task 4 after task 3 is done, or open a new plan.
```

**What you do:** Stash the rate-limiting work, commit the health payload on its own,
merge task 2. Create a separate branch for rate limiting later.

---

## Step 6 — GATE: code-reviewer

Task 2 merged. Task 3 (docs + harden) is done. Time to gate the full feature before calling
it complete. Run code-reviewer first.

**What you type:**
```
Use code-reviewer. Review branch api-status-auth vs main in ~/Projects/myapp.
Changed files: middleware/requireApiKey.js, routes/api.js, tests/middleware/requireApiKey.test.js,
tests/api/status.test.js, .env.example, README.md.
DoD from the plan: key in env var, 401 without/wrong key, 200 with correct key, shape test
for payload, no key in logs, teammate can set up from README.
```

**What you get back (example):**
```
VERDICT: APPROVE-WITH-NOTES

MUST-FIX: none

SHOULD-FIX:
  middleware/requireApiKey.js:14 — the error response body is {error: "Unauthorized"} but
  the status code comment says 401. If a caller checks the body to distinguish "missing key"
  from "wrong key", they cannot. Consider {error: "missing_api_key"} vs {error: "invalid_api_key"}.
  Not a correctness bug today, but will matter the first time someone debugs a 401 in production.

  tests/api/status.test.js:22 — the payload shape test asserts heapUsed exists but does not
  assert it is a number. A future refactor that returns heapUsed as a string would pass this
  test. Change to: expect(typeof res.body.heapUsed).toBe('number')

NICE:
  .env.example — the comment explains what the key is but not the expected format (length,
  characters). A one-liner like "# 32+ character random string, e.g. openssl rand -hex 16"
  helps whoever sets this up next.

INFERRED (not observed — run before calling done):
  The .trim() fix on process.env.API_KEY was confirmed working locally. Verify it also works
  when the env var is set via the deployment environment (not .env file) to confirm .trim()
  does not strip characters it should not.
```

**What you do:** Fix the two SHOULD-FIX items (they're quick). The NICE item too — one line.
Now run security-reviewer. The task touches auth and input handling — the trigger rule applies.

---

## Step 7 — GATE: security-reviewer

**What you type:**
```
Use security-reviewer. Same branch api-status-auth vs main in ~/Projects/myapp, same files.
This change adds API key auth: reads Authorization header, compares to env var, returns health
data. Auth and input handling are the surfaces.
```

**What you get back (example):**
```
VERDICT: PASS-WITH-NOTES

BLOCK: none

NOTES:
  middleware/requireApiKey.js — string equality comparison (===) is not timing-safe.
  A timing attack on a local API key check at this traffic level is a theoretical risk,
  not a practical one. Acceptable for current scale. If this ever gates access to sensitive
  data or runs at high volume, replace with crypto.timingSafeEqual(). Document the decision.

  routes/api.js:31 — process.memoryUsage() and process.uptime() expose runtime internals.
  Acceptable for an operator endpoint behind auth. Ensure this route is never accidentally
  made public (no auth middleware removal without a security pass).

  No secrets in logs: confirmed by grep. No key echoed in responses: confirmed.
  Error responses do not leak which part of validation failed: confirmed (both missing and
  wrong key return 401 with the same body).
```

**What you do:** Add a comment in the middleware about the timing-safe decision.
PASS means the feature can ship.

---

## Step 8 — DONE-CHECK: tech-lead

Both gates passed. Run the done-check before merging.

**What you type:**
```
Use tech-lead, done-check mode. Task 3 of the api-status plan (docs + harden).
Branch api-status-auth. Tests pass locally. code-reviewer APPROVE-WITH-NOTES (notes addressed).
security-reviewer PASS-WITH-NOTES (notes addressed with comment). Check it against the DoD.
```

**What you get back:**
```
VERDICT: DONE

DOD LINE-BY-LINE:
  ✓ curl with correct key returns 200 + JSON payload — confirmed by passing integration test
  ✓ curl without key returns 401 — confirmed by test
  ✓ curl with wrong key returns 401 — confirmed by test
  ✓ response includes uptime, heapUsed, rss, version — confirmed by shape test
  ✓ API_KEY in .env.example with comment — present
  ✓ endpoint documented in README — present
  ✓ no key appears in any log output — confirmed by security-reviewer grep
  ✓ gates passed — code-reviewer APPROVE-WITH-NOTES (notes addressed),
                   security-reviewer PASS-WITH-NOTES (notes addressed)

REMAINING: nothing. Merge when ready.
```

**What you do:** Merge the branch. Feature is done.

---

## The full loop at a glance

```
tech-lead (breakdown)
  → you build the route stub (confirm it answers)
    → senior-dev-mentor (middleware location question)
      → you build the middleware + tests
        → diagnostic-engineer (401 bug — CRLF in env var)
          → you fix .trim(), tests pass
  → tech-lead (standup — catches rate-limiting rabbit hole)
    → you commit task 2, stash rate limiting
  → code-reviewer (APPROVE-WITH-NOTES, two fixes)
  → security-reviewer (PASS-WITH-NOTES, one comment added)
→ tech-lead (done-check — DONE)
→ merge
```

Total agent invocations: 6. Every one had a specific trigger. None were optional for a
task touching auth.

---

## When to skip which agents

| Situation | Skip? |
|---|---|
| Tiny change (typo, copy update, config value) | Skip senior-dev-mentor; still gate with code-reviewer |
| No auth/input/secrets/money | Skip security-reviewer |
| No design fork mid-build | Skip senior-dev-mentor |
| Nothing broken | Skip diagnostic-engineer |
| Always | Never skip tech-lead done-check; never skip code-reviewer |

The gates are not optional. Everything else is triggered by the situation.
