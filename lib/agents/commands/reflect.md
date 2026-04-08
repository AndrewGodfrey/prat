---
description: End-of-session self-improvement sweep. User-invocable only — do not trigger autonomously.
---

Review this session for improvements worth capturing. Two categories:

1. **Behavioral mistakes** — things where a fresh Claude would have made the same error without
   additional direction. This includes tool errors that Claude automatically worked around.
2. **Discovered context** — things you had to explore or look up that a fresh Claude would also
   have to rediscover. Even in smooth executions, there may be non-obvious facts (API quirks,
   column names, indirection patterns) that cost investigation time and could be pre-loaded in
   a skill or CLAUDE.md for next time.

For each candidate: describe the mistake briefly, propose the specific addition or edit (consult
the `remember` skill for where to save and how to write entries), then wait for confirmation before
writing it. When considering solutions, also think about whether a small tool change - e.g. added support - could
resolve it without adding to the context burden.

When considering context edits, be aware that Claude doesn't experience cumulative context load — each concern appears
locally small to it, so it evaluates it on its own and often concludes "the risk of missing this outweighs the token cost."
The always-loaded context budget is tight and contested — many things seem worth adding individually,
but the cumulative effect degrades the quality of Claude's work. Contradictory instructions are
especially costly: even a few force mid-task conflict resolution and quality drops sharply.

When drafting proposed additions to instructions or rules, don't tack on a closing explanatory
sentence unless it heads off a specific competing interpretation. If the rule's reasoning is
obvious from the rule itself, the closer is filler. Watch for this pattern: if the user asks
"does that last sentence add anything?" and you immediately agree to remove it, it was filler.