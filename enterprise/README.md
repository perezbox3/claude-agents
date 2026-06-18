# Enterprise

What changes when real customers arrive. This bucket holds the once-per-product **stage gate**
and the seats you add to the team as the product grows past MVP. Nothing here taxes MVP
development - that is the two-speed doctrine: speed during MVP, scheduled debt review at the
doorway.

## First: the stage gate

[`platform-readiness-reviewer`](platform-readiness-reviewer.md) runs ONCE per product, at the
MVP -> production doorway (first paying customer, open signups, first external API consumer).
It audits the ten platform dimensions the lean build deliberately deferred - tenant/org model,
entitlements and metering, contract versioning, audit-as-feature, money/time correctness,
identity/SSO path, data lifecycle, SLOs, the enterprise buyer's checklist, self-serve
readiness - and returns a gap list ranked by **retrofit cost**:

- **ONE-WAY-DOOR** - blocks launch or gets an explicit signed accepted-risk
- **RETROFIT-HARD** - schedule before scale, not before launch
- **BOLT-ON** - date it and ship

Re-score on demand as the gaps close. The scorecard lives in the product repo's docs.

## Then: the seats you add

Added per pipeline stage as the work demands them (dashed boxes in
[the pipeline diagram](../architecture/agent-team-cicd.svg)):

| Agent | Pipeline stage | One line |
|---|---|---|
| [`architect-reviewer`](architect-reviewer.md) | PLAN | Interrogates non-trivial designs before code: data lifecycle, isolation, failure modes, one-way doors; GO / NO-GO verdicts |
| [`test-engineer`](test-engineer.md) | TEST | Behavior + failure-path + isolation + entitlement-boundary + migration tests; suites run IN the pipeline as merge gates |
| [`devops-engineer`](devops-engineer.md) | DEPLOY | Repeatable deploys, rollback always, tested restores, observability, SLO thinking; production promotion stays a human gate |
| [`docs-engineer`](docs-engineer.md) | OPERATE | "Done" includes "documented": runbooks, restore notes, drift mode against recent commits |

**New here? Read [INSTRUCTIONS.md](INSTRUCTIONS.md)** - the stage gate and every growth seat as
a worked use case with the exact prompts, plus the anti-patterns.

## The order of adoption (typical)

1. **At the gate:** run platform-readiness-reviewer; its gap list tells you which seats you
   need first.
2. **architect-reviewer** starts gating non-trivial designs (the one-way doors stop being
   tech-lead's side check and become a real design review).
3. **test-engineer** as the suite becomes the merge gate in CI.
4. **devops-engineer** when deploys move from "copy files" to staged dev -> prod promotion.
5. **docs-engineer** when more than one person (or one machine) must be able to run the thing.
