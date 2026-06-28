---
name: reflect
description: End-of-session self-improvement sweep. User-invocable only — do not trigger autonomously.
---

Review this session for improvements worth capturing. Two categories:

1. **Behavioral mistakes** — things where a fresh agent session would have made the same error without
   additional direction. This includes tool errors that the agent automatically worked around.
2. **Discovered context** — things you had to explore or look up that a fresh agent would also
   have to rediscover. Even in smooth executions, there may be non-obvious facts (API quirks,
   column names, indirection patterns) that cost investigation time.
   
There are various ways to address these, in decreasing order of preference:

- modify a tool, or add a new one
- change configuration to make the mistake impossible
- use the `remember` skill to add it to context somewhere

When considering context edits, be aware that the agent is biased towards adding very
specific context, which over time accumulates context which degrades the quality of the agent's work.
Contradictory instructions are especially costly.

When drafting proposed additions to instructions or rules, don't tack on a closing explanatory
sentence unless it heads off a specific competing interpretation. If the rule's reasoning is
obvious from the rule itself, the closer is filler.
