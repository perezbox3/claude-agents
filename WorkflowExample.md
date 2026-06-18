# Workflow Example

A full end-to-end walkthrough of one feature using the agent team. Every prompt is what you
would actually type; every agent response is representative of what you get back.

**The scenario:** You are adding Stripe webhook handling to a PHP project. When Stripe sends
a `payment_intent.succeeded` event, you need to record the payment in MySQL and mark the
associated order as paid. The repo lives at `~/Projects/myapp`, main branch. Stripe is already
used for checkout — this is the first webhook endpoint.

**Stack:** PHP, MySQL, HTML/CSS/JS, Stripe  
**Deploy:** SSH into server → `git pull`  
**Servers:** development (104.237.131.5), projects (173.255.195.153)

---

## Step 1 — PLAN: tech-lead (breakdown mode)

You have a goal. You do not have a plan. Start here every time.

**What you type:**
```
Use tech-lead. Goal: add a Stripe webhook endpoint that listens for payment_intent.succeeded
events, verifies the Stripe signature, records the payment in MySQL, and marks the order as
paid. Repo: ~/Projects/myapp, main branch. What exists: Stripe checkout already works
(stripe-php library installed), orders table in MySQL has a status column, no webhook
handling anywhere. I want the breakdown.
```

**What you get back:**
```
GOAL: Handle Stripe payment confirmations server-side so orders are reliably marked paid
even if the user closes the browser before the success page loads.

RISKIEST ASSUMPTION: Stripe signature verification — if the webhook secret is wrong or the
raw request body is consumed before verification, every webhook silently fails or (worse)
accepts forged events. Task 1 proves verification works before any database writes happen.

TASKS (ordered):

  1. Wire the endpoint and verify the Stripe signature
     Scope: create webhooks/stripe.php, read the raw POST body, verify using
     \Stripe\Webhook::constructEvent() with STRIPE_WEBHOOK_SECRET from env, return 400
     on failure, return 200 on success (no DB write yet), register the route in your
     router or .htaccess, configure the endpoint in the Stripe dashboard
     DoD: Stripe CLI sends a test payment_intent.succeeded event and the endpoint returns
          200; sending a request with a wrong signature returns 400; the raw body is never
          decoded before verification
     Gate: code-reviewer; security-reviewer (input handling + external webhook)
     First step: create webhooks/stripe.php that reads php://input, calls constructEvent(),
                 and returns 200/400 — no database, no business logic yet

  2. Record the payment and mark the order paid
     Scope: on verified payment_intent.succeeded, extract the payment intent ID and amount,
     INSERT into a payments table (payment_intent_id, amount, status, created_at), UPDATE
     orders SET status='paid' WHERE stripe_payment_intent_id = the intent ID; wrap both
     writes in a transaction so they succeed or fail together
     DoD: a test webhook event creates a payments row and updates the order row atomically;
          sending the same event twice does not create a duplicate payment row (idempotency
          via UNIQUE KEY on payment_intent_id); order status confirmed as 'paid' after event
     Gate: code-reviewer; security-reviewer

  3. Harden and deploy
     Scope: add STRIPE_WEBHOOK_SECRET to .env.example with instructions, add error logging
     (failed verifications, DB errors), test with Stripe CLI against the dev server, deploy
     to projects server via git pull, re-run Stripe CLI test against live endpoint
     DoD: endpoint live on projects server and returning 200 for test events; failed
          verifications logged but not exposed to caller; deployment steps documented
     Gate: code-reviewer

OUT OF SCOPE: refund handling, other event types, webhook retry logic, admin UI

PARKED: customer.subscription.* events for future subscription support

RE-PLAN AT: after task 2 is merged
```

**What you do:** Start task 1. Create branch: `git checkout -b stripe-webhooks`.
Create `webhooks/stripe.php` — just the signature verification, no database yet. Confirm it
answers before writing any business logic.

---

## Step 2 — BUILD: you write every line

You create `webhooks/stripe.php`, wire the route, and get the endpoint answering. Then you
hit a design question: the database writes need to be in a transaction, but your current DB
helper does not support transactions. Do you add transaction support to the helper or do
you use PDO directly in the webhook file?

---

## Step 3 — DISCUSS: senior-dev-mentor (weighing a design decision)

**What you type:**
```
Use senior-dev-mentor. I am on task 2 of the Stripe webhook plan in ~/Projects/myapp:
recording the payment and marking the order paid. The two DB writes need to be atomic.
My current DB helper (lib/db.php) wraps PDO but has no transaction support — it just
runs single queries. I see two options:

  A. Use PDO directly in webhooks/stripe.php for this transaction (bypass the helper)
  B. Add beginTransaction/commit/rollback methods to lib/db.php, then use it here

The helper is used in about 8 other files. What are the tradeoffs and what would you do?
```

**What you get back:**
```
OPTIONS:

  A. PDO directly in webhooks/stripe.php
     + Zero change to shared code; risk is contained to this file
     + Faster to write right now
     - You now have two patterns in the codebase: the helper and raw PDO; whoever reads
       this file next will wonder why it is different
     - If you need transactions elsewhere (you probably will), this pattern gets copied

  B. Add transaction support to lib/db.php
     + One pattern throughout the codebase
     + Any future code that needs transactions uses the same interface
     - Touches shared code that 8 files depend on; requires testing those files still work
     Risk: low — beginTransaction/commit/rollback are pass-through wrappers on PDO;
           you are not changing query behavior

RECOMMENDATION: B — add to the helper.

The deciding factor is that transactions are not a webhook-specific need. You will want them
again (order creation, user registration with a related record, anything with two writes).
Adding to the helper now costs 10 lines; adding it after copy-paste has spread costs a
refactor. The risk to the 8 existing files is minimal — they do not call transaction methods
that do not exist yet.

Shape:
  lib/db.php: add beginTransaction(), commit(), rollback() — each calls the PDO equivalent.
  webhooks/stripe.php: $db->beginTransaction(); ... $db->commit(); in a try/catch that calls
  $db->rollback() on failure.

Questions you should be able to answer:
  1. What happens if the INSERT succeeds but the UPDATE fails — does your catch block
     actually call rollback, or does it just log and return 200?
     (Returning 200 on a partial failure tells Stripe the event was handled — it will not retry.)
  2. Is the PDO connection set to throw exceptions (ERRMODE_EXCEPTION)?
     If not, a failed query returns false instead of throwing, and your try/catch never fires.
```

**What you do:** Add transaction methods to `lib/db.php`. The mentor flagged a critical
point — returning 200 on a partial failure is a silent data corruption bug. Make sure the
catch block calls `rollback()` and returns 500, not 200. Stripe will retry on 5xx.

---

## Step 4 — STUCK: diagnostic-engineer (when something breaks)

Task 2 is done locally. You test with the Stripe CLI and the endpoint returns 400 on every
event — even valid ones. Signature verification is failing but you cannot see why.

**What you type:**
```
Use diagnostic-engineer. Symptom: Stripe webhook endpoint returns 400 on all events including
valid test events from the Stripe CLI. Repo ~/Projects/myapp, branch stripe-webhooks.
The error is "No signatures found matching the expected signature for payload" from
Stripe\Exception\SignatureVerificationException. Tried: confirmed STRIPE_WEBHOOK_SECRET
matches the secret shown in the Stripe CLI. The raw body is read with file_get_contents('php://input').
I want the trace, not a guess.
```

**What you get back:**
```
SYSTEM MAP (request path):
  .htaccess / router        → routes POST /webhook/stripe to webhooks/stripe.php
  webhooks/stripe.php:8     → $payload = file_get_contents('php://input')
  webhooks/stripe.php:12    → $event = \Stripe\Webhook::constructEvent($payload, $sigHeader, $secret)

TRACE:

  Divergence point: the payload reaching constructEvent() does not match what Stripe signed.

  CONFIRMED: framework or middleware consumed php://input before your code reads it.
  php://input is a stream — it can only be read once per request. If your router, an
  authentication middleware, or any code earlier in the stack calls json_decode(file_get_contents
  ('php://input')) or reads $_POST before your webhook handler runs, the stream is empty by
  the time your handler reads it. constructEvent() then receives an empty string, which never
  matches the signature.

  Observation that confirms this: add error_log(strlen($payload)) immediately after line 8.
  If it logs 0, the stream was already consumed upstream.

  SUSPECTED (MEDIUM): a middleware is calling json_decode(file_get_contents('php://input'))
  on every request for API endpoints. Webhook endpoints need to bypass this or read the body
  before the middleware does.

  RULED OUT: wrong webhook secret — the CLI shows the exact secret to use; a secret mismatch
  produces a different error ("timestamp outside the tolerance zone" or a hash mismatch with
  a non-empty payload, not "no signatures found").

BLAST RADIUS: any future webhook endpoint (from any provider) will hit this same problem
if the middleware pattern is not addressed.

HOW I FOUND IT: "no signatures found" with a non-empty secret means the payload is empty or
whitespace. The only common cause in PHP is a consumed input stream.
```

**What you do:** Check — `strlen($payload)` logs 0. Your JSON middleware runs on all routes.
Fix: move the webhook route registration above the JSON middleware, or add an early-exit in
the middleware that skips `php://input` consumption for the webhook path. Tests pass.

---

## Step 5 — STANDUP: tech-lead (mid-flight check)

Tasks 1 and 2 are merged. You are on task 3 (harden and deploy) and realize the payments
table does not exist on the production server — only in your local schema. You also notice
the orders table is missing the `stripe_payment_intent_id` column on production.

**What you type:**
```
Use tech-lead, standup mode. Plan: Stripe webhook plan, tasks 1-3. Tasks 1 and 2 merged.
On task 3: harden and deploy. Hit a blocker — payments table and orders.stripe_payment_intent_id
column do not exist on the production server (projects, 173.255.195.153). No migration system
in this project. Am I on track, and how do I handle the schema?
```

**What you get back:**
```
CALL: BLOCKED

EVIDENCE: the code is ready to deploy but the schema it depends on does not exist in
production. git pull will put the code live; the first webhook will then throw a DB error.
This is a real blocker, not a process question.

NEXT ACTION: before deploying, SSH into projects and run the schema changes manually, then
confirm they exist before running git pull.

SQL to run on the server:
  (you should write and confirm this — the agent does not write your migrations)
  CREATE TABLE payments (...) and ALTER TABLE orders ADD COLUMN stripe_payment_intent_id ...
  Run: DESCRIBE payments; DESCRIBE orders; to confirm before deploying.

ROUTED: no migration system is a project-level gap this plan should not solve — but note it.
  If this project grows, a migration system (Phinx, Flyway, or a simple numbered SQL file
  convention) prevents this exact situation next time. Add to PARKED.

PARKED: migration system for future schema changes
```

**What you do:** SSH into projects server, run the schema changes, confirm with `DESCRIBE`.
Then deploy.

---

## Step 6 — DEPLOY: the actual deploy

No agent for this — this is you executing the plan.

```bash
# On your machine:
ssh projects

# On the server:
cd /var/www/myapp
git pull origin main

# Confirm the new file is there:
ls webhooks/stripe.php

# Tail the log during a test:
tail -f /var/log/myapp/error.log
```

Then trigger a test event from the Stripe dashboard or CLI pointed at the live URL.
Confirm the payments row appears in MySQL and the order status updates to 'paid'.

---

## Step 7 — GATE: code-reviewer

Feature works on the server. Time to formally gate task 3 before calling the feature done.

**What you type:**
```
Use code-reviewer. Review branch stripe-webhooks vs main in ~/Projects/myapp.
Changed files: webhooks/stripe.php, lib/db.php, .env.example, docs/deploy.md.
DoD: endpoint verified and live on projects server, signature failures logged but not
exposed, deployment steps documented, no secrets in any file.
```

**What you get back (example):**
```
VERDICT: APPROVE-WITH-NOTES

MUST-FIX: none

SHOULD-FIX:
  webhooks/stripe.php:34 — the catch block for SignatureVerificationException logs the
  exception message, which includes the received signature hash. That hash is not a secret,
  but logging it in full means your log files contain Stripe header values. Trim to just
  the exception class and a fixed string: "Stripe signature verification failed".

  lib/db.php:41 — rollback() does not check whether a transaction is active before calling
  PDO::rollBack(). If rollback() is called outside a transaction (e.g. in a catch that runs
  when no transaction was started), PDO throws an exception. Wrap with
  if ($this->pdo->inTransaction()) before calling rollBack().

NICE:
  .env.example — STRIPE_WEBHOOK_SECRET is documented. Consider adding a comment noting
  this secret is different from STRIPE_SECRET_KEY — they come from different places in
  the Stripe dashboard and are commonly confused.

INFERRED: the middleware bypass (moving webhook route above JSON middleware) — confirmed
working via your Stripe CLI test but should be verified on the production server with a
live test event, not assumed identical to local behavior.
```

**What you do:** Fix both SHOULD-FIX items (10 minutes). Run a final live test event. Done.

---

## Step 8 — GATE: security-reviewer

Task touches input handling (raw POST body from an external service) and money. Trigger rule applies.

**What you type:**
```
Use security-reviewer. Branch stripe-webhooks vs main in ~/Projects/myapp, same files.
This endpoint receives raw POST bodies from Stripe, verifies the signature, and writes
payment records to MySQL. Input handling and money are the surfaces.
```

**What you get back (example):**
```
VERDICT: PASS

Notes:
  Signature verification using constructEvent() with the raw body is the correct pattern —
  confirmed. Stripe's library handles timing-safe comparison internally.

  webhooks/stripe.php: the payment intent ID from the event is inserted directly into the
  prepared statement — confirmed parameterized, not interpolated. No SQL injection surface.

  Idempotency via UNIQUE KEY on payment_intent_id: confirmed. Duplicate events are a
  guaranteed reality with Stripe; this handles them correctly.

  Returning 500 (not 200) on DB failure: confirmed. Stripe will retry — correct behavior.

  No amount from the Stripe event is trusted for pricing — the amount is recorded for
  the record only; order fulfillment keys off the event type and the intent ID, not a
  client-supplied amount. Correct.
```

Both gates pass. Run the done-check.

---

## Step 9 — DONE-CHECK: tech-lead

**What you type:**
```
Use tech-lead, done-check mode. All three tasks of the Stripe webhook plan. Branch merged,
endpoint live on projects server (173.255.195.153). code-reviewer APPROVE-WITH-NOTES (both
notes addressed). security-reviewer PASS. Live test event confirmed 200 response, payments
row created, order status updated to paid.
```

**What you get back:**
```
VERDICT: DONE

DOD LINE-BY-LINE:
  ✓ Valid Stripe event returns 200 — confirmed by live test on projects server
  ✓ Invalid signature returns 400 — confirmed by Stripe CLI test
  ✓ Payment recorded in payments table — confirmed by live test query
  ✓ Order status updated to paid atomically — confirmed; transaction rollback tested
  ✓ Duplicate event does not create duplicate payment — UNIQUE KEY confirmed in schema
  ✓ Signature failures logged but not exposed to caller — confirmed after code-reviewer fix
  ✓ STRIPE_WEBHOOK_SECRET in .env.example with instructions — confirmed
  ✓ Deployment steps documented — confirmed in docs/deploy.md
  ✓ Gates passed — code-reviewer APPROVE-WITH-NOTES (addressed), security-reviewer PASS

PARKED (from standup): migration system for future schema changes

REMAINING: nothing. Feature is done.
```

---

## The full loop at a glance

```
tech-lead (breakdown)
  → build signature verification stub
    → senior-dev-mentor (transaction design — adds methods to lib/db.php)
      → build DB writes with transaction
        → diagnostic-engineer (400 bug — consumed php://input stream)
          → fix middleware ordering
  → tech-lead (standup — schema missing on prod, routes to manual SQL before deploy)
    → run schema on server, git pull, live test
  → code-reviewer (APPROVE-WITH-NOTES, two fixes)
  → security-reviewer (PASS)
→ tech-lead (done-check — DONE)
```

---

## Your deploy checklist (for any project)

Before every deploy to a production server:

```
1. Schema changes?   SSH in and run them manually BEFORE git pull
2. Env vars?         Confirm any new .env keys exist on the server
3. git pull          cd /var/www/<project> && git pull origin main
4. Verify            Tail the error log, trigger a test action, confirm it works
5. Gate first        Never deploy without code-reviewer (and security-reviewer if applicable)
```

Servers:
```
ssh development   # 104.237.131.5   — dev/testing
ssh projects      # 173.255.195.153 — production projects
ssh dhfc          # 45.79.71.196    — DHFC deploy
ssh personal      # 45.33.119.137   — personal projects
```

---

## When to skip which agents

| Situation | Skip? |
|---|---|
| Tiny change (copy, config value, CSS tweak) | Skip senior-dev-mentor; still gate with code-reviewer |
| No auth/input/secrets/money/Stripe | Skip security-reviewer |
| No design fork mid-build | Skip senior-dev-mentor |
| Nothing broken | Skip diagnostic-engineer |
| Always | Never skip tech-lead done-check; never skip code-reviewer |

The gates (code-reviewer, security-reviewer when triggered) are not optional.
Everything else fires on the situation.
