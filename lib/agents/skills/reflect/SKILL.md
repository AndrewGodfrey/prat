---
name: reflect
description: End-of-session self-improvement sweep. Runs as part of the wrap, wrap-session, and
  code-complete flows; outside those, user-invocable only — do not trigger autonomously.
---

Review this session for improvements worth capturing. Two categories:

1. **Behavioral mistakes** — things where a fresh agent session would have made the same error without
   additional direction. This includes tool errors that the agent automatically worked around.
2. **Discovered context** — things you had to explore or look up that a fresh agent would also
   have to rediscover. Even in smooth executions, there may be non-obvious facts (API quirks,
   column names, indirection patterns) that cost investigation time.
   
There are various ways to address these, in decreasing order of preference:

- modify a tool, or add a new one
- change configuration to make the mistake impossible (e.g. a hook or permission rule)
- use the `remember` skill to add it to context — it decides where, and how to keep additions
  from degrading always-loaded files
