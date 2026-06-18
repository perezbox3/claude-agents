# Architecture

Final, current-state diagrams only. When the workflow or system changes, the diagram changes
with it - replace the file, do not accumulate versions (git history keeps the old ones).
Working drafts and sketches do not live here.

## Index

| Diagram | Shows |
|---|---|
| [`agent-team-loop.svg`](agent-team-loop.svg) | The daily development loop: the five core seats around the developer - plan, build, discuss, gate, and the when-stuck path. The tight view. |
| [`agent-team-cicd.svg`](agent-team-cicd.svg) | The delivery pipeline beyond MVP: seven CI/CD stages left to right, agent seats bucketed under each stage, deterministic rails at BUILD/CI, and the once-per-product stage gate (platform-readiness-reviewer) at the MVP -> production doorway. |

## Conventions

- SVG, dark canvas, text as text (searchable, diffable).
- Solid borders = seats in use today; dashed = seats added as the product grows.
- Every diagram must be readable standalone: title, one-line subtitle, legend when borders or
  colors carry meaning.
