---
description: End-of-session self-improvement sweep. User-invocable only — do not trigger autonomously.
---

Review this session for behavioral mistakes worth capturing — things where a fresh Claude would have
made the same error without additional direction.

This includes tool errors that claude automatically worked around.

For each candidate: describe the mistake briefly, propose the specific addition or edit (consult
the `remember` skill for where to save and how to write entries), then wait for confirmation before
writing it. When considering solutions, also think about whether a small tool change - e.g. added support - could
resolve it without adding to the context burden.

When considering context edits, be aware that Claude doesn't experience cumulative context load — each concern appears
locally small to it, so it evaluates it on its own and often concludes "the risk of missing this outweighs the token cost."
The always-loaded context budget is tight and contested — many things seem worth adding individually,
but the cumulative effect degrades the quality of Claude's work. Contradictory instructions are
especially costly: even a few force mid-task conflict resolution and quality drops sharply.