# MVP Development

The playbook for the proving phase: POC through MVP. There are no extra agents in this bucket
on purpose - **the core team IS the MVP team.** This phase is about speed with guardrails, not
process.

## The doctrine: smallest correct version

- Build the thinnest end-to-end slice that proves the idea (the walking skeleton), then flesh it.
- No speculative abstraction: no interfaces with one implementation, no config for things that
  never vary, no framework where the stdlib does the job.
- Defer deliberately. Entitlement engines, SSO, audit exports, status pages, white-labeling -
  all correctly ignored at this stage. The [enterprise stage gate](../enterprise/README.md)
  exists precisely so you can skip these NOW without losing track of them.
- The loop still applies: plan -> build -> discuss -> gate. Lean does not mean unreviewed.

## The one exception: one-way doors

A handful of decisions are nearly free at design time and brutal to retrofit. Do not BUILD the
platform now - just do not weld these doors shut:

1. **Tenant/account hierarchy lives in the schema**, even if today has exactly one level.
2. **Money is DECIMAL/integer-cents; timestamps are timezone-aware.** Floats and naive
   datetimes are migrations waiting to happen.
3. **Any shape an external party might consume is additive-only from day one.** Renaming a
   field in a private function is free; in a consumed API it is a breaking change.
4. **Billable/limitable actions are at least countable** (an event row), even if nothing reads
   it yet. You cannot bill or limit what you never measured, and usage data cannot be
   backfilled.

When planning a feature that touches the data model, money, time, or an external shape, have
tech-lead (or architect-reviewer, for anything non-trivial) check the doors.

## Exit signals: when MVP ends

Any of these means you are at the doorway and it is time to run the
[stage gate](../enterprise/README.md):

- The first paying customer, or a signed commitment to one
- Opening signups to people you do not know
- The first external consumer of your API
- The team deciding "this is going to production"

At that moment, run `platform-readiness-reviewer` once. It grades the gap, not the past - a
lean MVP with open gaps is the system working as designed.
