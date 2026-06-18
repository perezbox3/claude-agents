# Why agents instead of one massive session?

It is the same model underneath, so why bother? Because the difference is not the brain, it is
what is in front of the brain when it works. Four real differences, then the question everyone
asks: how does it keep context?

## 1. A context window is a finite, degrading resource

One massive session accumulates everything: every file you opened, every dead end, every tool
dump, every tangent. Three costs compound:

- **Capacity.** The window fills. Then the harness summarizes/compacts older history, and
  detail you needed silently drops out.
- **Attention quality.** This is the one people miss: the model attends over EVERYTHING in
  context. 150k tokens of exploration noise dilutes its focus on the current task. A long
  session does not just run out of room, it gets dumber per token as signal-to-noise falls.
- **Cost and latency.** Every turn re-processes the whole scroll.

An agent gets a fresh window containing exactly two things: its instruction file and the
invocation. The reviewer reading your auth change has 100% of its attention on the auth change.

## 2. Independence (the big one for review)

In one session, the model that wrote the code reviews its own code WITH ITS OWN REASONING
STILL IN CONTEXT. It already believes the code is correct; it argued itself into every decision
sitting right there in the scroll. The "review" becomes self-confirmation.

An agent cannot see the parent conversation. For a builder that is a limitation; for a reviewer
it is the entire point: it cannot be talked into agreeing. It reads the code cold, like a
teammate who was not in the room. This is the same reason human teams do not let authors
approve their own PRs, and it is why the gates in this repo (code-reviewer, security-reviewer)
are separate seats instead of a "now review yourself" prompt.

## 3. Instructions that do not drift

A persona prompt given 80k tokens ago fades; everything since dilutes it. An agent's entire
identity is its file: the landmines, the verdict contract, the "never do X" list arrive at full
strength every single invocation. That is why these agents reliably end with their output
contracts; a long session asked to "keep being a skeptical reviewer" slowly stops being one.

## 4. Parallelism and blast radius

Agents run concurrently (five reviewers at once); a session is serial. And tool scoping is real
safety: a read-only reviewer CANNOT edit code no matter how confused it gets, because it does
not have the tool. A 2am session with everything in one window has no such guarantee.

## So how does it keep context? It does not, and that is the design

There is no shared memory between agents, deliberately. Continuity comes through three
channels, and the analogy is exactly a human team, which also does not share one brain:

| Channel | Human equivalent | In practice |
|---|---|---|
| **The invocation** | The ticket / the briefing | The parent session passes exactly what is needed: the symptom, the repo path, the decision quoted. If it is not in the invocation, the agent does not know it - which forces clean handoffs |
| **Artifacts on disk** | Docs, tickets, wikis | tech-lead writes `PLAN-<slug>.md`, diagnostic-engineer writes `MAP-<scope>.md`, the gate verdicts land in the PR. Context lives in the REPO, not in a chat scroll, so it survives every session ending |
| **The return** | The report back | The agent's final output comes back into the main session, which stays the orchestrator holding the thread |

The mental model: **the main session is the thread; agents are scoped excursions that return a
result.** The durable memory of the project is the repo itself - plans, maps, verdicts,
commits. A chat scroll is the worst possible database; files are the best.

## The honest counterpoint: agents are not free

Each agent re-reads the code cold (token cost, latency), and for small, tight, iterative work a
single session is better - the overhead of briefing an agent exceeds the work. The rule of
thumb:

- **Stay in one session** for the building: tight iteration, small fixes, conversation.
- **Delegate to an agent** when you need INDEPENDENCE (review), FRESH ATTENTION on a big
  surface (mapping, auditing, a long trace), or PARALLELISM (several scoped jobs at once).
- **Do not fan out to rename a variable.**

Related: [Agents, Hooks, and Loops](agents-hooks-loops.md) for what agents are mechanically and
where they run.
