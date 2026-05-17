# Memory

This file is read-only. Save memories by editing the correct source files:

## How to save memories
- Project-specific repo facts → edit the project repo's `AGENTS.md`, e.g. `prat/AGENTS.md`
  - Use for: repo structure, key file paths, build/test commands, project conventions
  - If it doesn't already exist, tell the user you're creating a new one.
- Cross-repo guidelines that apply broadly (no special trigger needed) → `prat/lib/agents/agent-user_prat.md`
  - User-specific variant → the user's `de/lib/agents/agent-user_de.md` (if they have a de repo)
  - Preferences shared across environments → the user's `prefs/lib/agents/agent-user_prefs.md` (if they have a prefs repo)
- Context-specific patterns (can be reliably triggered when relevant) → create/update a skill in `prat/lib/agents/skills/`
  - skills are deployed to user settings (e.g. `.claude/skills/`) by the user's de or prefs deploy — always edit the source, never the deployed copy
  - skills are opt-in — the user's de/prefs deploys none/some/all of them
- If none of these fit - ask the user. Do not edit e.g. `~/.claude/projects/*/memory/` files - those are deployed by `d`.

These are in git repos — edits are visible and reviewable. No need to wait for confirmation.

## What to save
- Stable patterns confirmed across multiple interactions
- Key architectural decisions, important file paths, project structure
- User preferences for workflow, tools, communication style
- Solutions to recurring problems

## What NOT to save
- Session-specific context (current task, in-progress work)
- Anything that duplicates existing AGENTS.md instructions
- Speculative or unverified conclusions.
