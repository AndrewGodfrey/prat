---
name: reflect
description: End-of-session self-improvement sweep. Runs as part of the wrap, wrap-session, and
  ready-for-user-review flows; outside those, user-invocable only — do not trigger autonomously.
---

Review this session for sources of friction worth capturing. Two categories:

1. **Behavioral mistakes** — things where a fresh agent session would have made the same error without
   additional direction. This includes tool errors that the agent automatically worked around.
2. **Discovered context** — things you had to explore or look up that a fresh agent would also
   have to rediscover. Even in smooth executions, there may be non-obvious facts (API quirks,
   column names, indirection patterns) that cost investigation time.

For each item, decide if you know enough to propose a decent fix/improvement. Noticing a problem
and knowing its fix are different things, and you can nearly always produce *a* fix for
something you just tripped over. Where you only have the problem, record it instead: say what happened, what
it cost, and something cheap to re-run, so a later session can test the observation rather than trust it.
Repeated sightings of one problem are what justify changing anything,
and a patch applied in their place makes the problem harder to see, not easier. Where
such records live is a layer above this one; if your instructions don't say, ask.

There are various ways to fix/improve these, in decreasing order of preference:

- modify a tool, or add a new one
- change configuration to make the mistake impossible (e.g. a hook or permission rule)
- use the `remember` skill to add it to context — it decides where, and how to keep additions
  from degrading always-loaded files

Take action on the findings in this session: The session that produced a finding is the only one holding the
context that makes it cheap to fix, so a general preference for short sessions is not a reason to defer
here — reflect is the exception to it.

What action to take, depends on whether this is happening before or after "/wrap". If before: Make or record
fixes/improvements while you work. After "/wrap", record them for later, and don't make changes to the work itself.
