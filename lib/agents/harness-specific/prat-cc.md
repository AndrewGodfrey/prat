# CC-specific notes for the prat environment

## Working with subagents

When a subagent's summary doesn't have enough detail, three recovery paths:
- Resume the subagent via SendMessage with its agent ID (returned in the Agent tool result)
- Full transcript: `~/.claude/projects/{project}/{sessionId}/subagents/agent-{id}.jsonl`
- Improve the agent instructions to request more detail in the summary, then redo (may not be
  practical if the work was expensive or has side effects)

---

## Model workarounds — CC-specific

### Claude Code feature knowledge

Your training data knowledge of Claude Code features is unreliable — file loading behavior, include syntax,
skill discovery, settings, and conventions are all areas where you've been confidently wrong. Before making
claims about what Claude Code does or doesn't support, consult the `claude-code-guide` agent. Don't answer
authoritatively from model knowledge alone.

The fetched CC documentation is also unreliable in practice. Known example: the `additionalContext` JSON
field in UserPromptSubmit hook output is documented as working but is silently ignored by CC — plain stdout
is what actually gets injected. Verify CC hook behavior empirically rather than trusting docs.

Verified flag (not prominent in docs): `claude --settings <path>` loads an additional JSON merged into the
standard settings hierarchy with no on-disk residue. Use this for per-launch overrides (e.g. session-specific
`skillOverrides`) rather than writing to `.claude/settings.local.json`.

Picking up a change depends on which file it lands in:

- Settings source fragments (`Get-ClaudeUserSettings_*.ps1` — hook registrations, permissions):
  `d` regenerates `~/.claude/settings.json`, and CC picks the new content up mid-session — no
  restart (verified 2026-07-11: a newly registered PostToolUse hook fired without one).
- MCP server code: `/mcp` reconnects and restarts the server process — no CC restart.
- Hook script code (the `.ps1` a registered command points at): nothing — the command runs the
  source file, so edits are live on the next hook fire.
- Instruction files (CLAUDE.md sources, `agent-user_*.md`): `d` to deploy, then end and resume the
  CC session — instructions are read at session start.

Some roles deny the Bash and/or PowerShell tools outright via `permissions.deny` in
`.claude/settings.local.json` (typically to force a different execution path, e.g. a sandboxed
alternative). A denied tool doesn't surface via ToolSearch either — a search for it returns zero
matches, the same as a tool that was never registered. If ToolSearch can't find an execution tool
you'd expect to exist, check `.claude/settings.local.json` for `permissions.deny` before concluding
it's absent or searching further.

Glob can return no matches when the pattern embeds parent directories (observed: pattern
`lib/agents/skills/**/*.md` with `path` set to the repo root found nothing despite matching files
existing). Put the full directory in `path` and start the pattern at `**/`.

Read rejects a second call on a file already read unchanged ("Wasted call — file unchanged since your
last Read") — confirmed real by inspecting the session's jsonl transcript. This can trigger even
when the earlier successful Read isn't in what you'd narrate as "this conversation" — e.g. buried in an
earlier parallel tool-call batch during exploration —
so don't assume a rejected Read means the file was never fetched; check whether you already have its
content before concluding otherwise. Workaround to get the content again: `Grep` with pattern `.` and
`output_mode: "content"`.
