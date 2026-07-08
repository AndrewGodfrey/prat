# CC-specific notes for the prat environment

## Working with subagents

When a subagent's summary doesn't have enough detail, three recovery paths:
- Resume the subagent via SendMessage with its agent ID (returned in the Agent tool result)
- Full transcript: `~/.claude/projects/{project}/{sessionId}/subagents/agent-{id}.jsonl`
- Improve the agent instructions to request more detail in the summary, then redo (may not be
  practical if the work was expensive or has side effects)

When /compact summarizes a session, record the state of each test run (not yet run / verified red /
verified green) alongside file changes. These are distinct states with different implications.

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

`/mcp` in CC reconnects to an MCP server and restarts the server process — use it to pick up code
changes to an MCP server without restarting CC.

Read rejects a second call on a file already read unchanged ("Wasted call — file unchanged since your
last Read") — confirmed real by inspecting the session's jsonl transcript. This can trigger even
when the earlier successful Read isn't in what you'd narrate as "this conversation" — e.g. buried in an
earlier parallel tool-call batch during exploration —
so don't assume a rejected Read means the file was never fetched; check whether you already have its
content before concluding otherwise. Workaround to get the content again: `Grep` with pattern `.` and
`output_mode: "content"`.
