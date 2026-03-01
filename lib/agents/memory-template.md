# Memory

This file is read-only. Save memories by editing the correct source files:

## How to save memories
- Cross-repo + not user-specific → `prat/lib/agents/agent-user.md`
- Cross-repo + user-specific → the user's `de/lib/agents/agent-user.md` (though they might manage it differently)
- Project-specific → edit the project repo's `CLAUDE.md`, e.g. `prat/CLAUDE.md`
  - If it doesn't already add one, tell the user you're creating a new one.
- Context-specific pattern → create/update a skill in `prat/lib/agents/skills/`
  - skills are opt-in — the user's `de` deploys none/some/all of them
  - but even so - if they can be reliably triggered when needed, skills are preferred, for things that aren't
    relevant to most tasks in most projects.
- If none of these fit - ask the user. Do not edit `~/.claude/projects/*/memory/` files - those are deployed by `d`.

These are in git repos — edits are visible and reviewable. No need to wait for confirmation.

## What to save
- Stable patterns confirmed across multiple interactions
- Key architectural decisions, important file paths, project structure
- User preferences for workflow, tools, communication style
- Solutions to recurring problems

## What NOT to save
- Session-specific context (current task, in-progress work)
- Anything that duplicates existing CLAUDE.md instructions
- Speculative or unverified conclusions.
