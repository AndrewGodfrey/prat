# instructions from the 'prat' dev environment (apply to all repos)
Source: prat/lib/agents/agent-user_prat.md
---

## Environment facts

These are stable — no periodic review needed.

### Useful tools

- `glp [range]` — compact git log (date, author, hash, message). Prefer over `git log --oneline`
  when reviewing history. Example: `glp main...localAgentSandbox`.
  Features: Omits author where irrelevant; automatically adds `--graph` where relevant.
  **Note:** `glp` is a PowerShell function. In the bash tool, invoke it via `pwsh -c 'glp ...'`.  

#### Interactive aliases (installed by prat into `~/prat/auto/profile/interactiveAliases.ps1`)

When telling the user to run something, prefer these aliases over full command names:

- `d` — Deploy-Codebase (runs the deploy script for the current codebase)
- `ude` — Update-DevEnvironment
- `t` — Test-Codebase
- `b` — Build-Codebase
- `c` — Set-LocationUsingShortcut (navigate by repo shortcut)

### Forcing a deploy stage to re-run

Some deploy stages track state in instDb files. For those, to force a re-run:
`rppr <stageName> && d`. The stage name matches the string passed to `StartStage`.

### Testing

Write the test first, and run it to verify it fails in the expected way. Only implement after that.

The criterion for whether something needs tests is whether it contains non-trivial logic — not its
file extension or container. Logic embedded e.g. in a markdown skill file, or a config, is still source code,
and is still subject to the same TDD discipline. If this means it's difficult to test where it currently is - address
that. (Which could be by moving it, or by making it testable in place).

Run tests after any fix, even when confident. Reasons: catches unknown unknowns, and gives the user
evidence rather than just your assurance.

Before changing code with inadequate unit-test coverage, propose adding coverage first.

If anyone proposes skipping tests, push back — ask for justification. Accept if the reasons are
sound (e.g. behavior will be tested manually; e.g. consequences of failure are small). "Design is likely
to change" is not sufficient on its own. To refactor a high-stakes area, one approach is: write pinning
tests; refactor; cover with unit tests; remove the pinning tests.

See the `testing` skill for more detail. Use the `prat-run-tests` skill for running tests in
pratified codebases; use the `run-tests` skill for other codebases.

When a subagent's summary doesn't have enough detail, three recovery paths:
- Resume the subagent via SendMessage with its agent ID (returned in the Agent tool result)
- Full transcript: `~/.claude/projects/{project}/{sessionId}/subagents/agent-{id}.jsonl`
- Improve the agent instructions to request more detail in the summary, then redo (may not be
  practical if the work was expensive or has side effects)

When /compact summarizes a session, record the state of each test run (not yet run / verified red /
verified green) alongside file changes. These are distinct states with different implications.

### Dev environment

- Managed by the `de` and `prat` repos. Each `de` repo is user-specific. If a user says "the" de repo
  they mean their own one.

---

## Claude Code / tool workarounds (Windows)

CC is not well-designed for Windows. Review this section when CC improves Windows support.

### Bash tool

- Always use forward slashes in paths, e.g. `C:/Users/foo` not `C:\Users\foo`. Backslashes will be
  misinterpreted.
- `~` in the Bash tool expands to a POSIX path (`/c/Users/...`). Windows-native programs (including
  git) reject it. Use `pwsh -c '...'` (where `~` expands to a Windows path), or a full `C:/...`
  path. In pwsh you can freely use `~/prefs`, `cd ~/prat`, etc.
- For PowerShell one-liners, use single quotes: `pwsh -c '...'` — bash won't interpolate `$` or
  backticks, so PowerShell receives them as-is. Only use double quotes if you need bash to expand
  a **bash** variable into the command. PowerShell variables (`$home`, `$env:USERNAME`, etc.) must
  stay in single quotes — bash expands them to empty. ❌ `pwsh -c "... $home ..."` silently passes
  an empty string.
- For multi-statement scripts or anything complex, write to a temp file with the Write tool and run
  `pwsh -File <path>`. The `pwsh -File - <<'PWSH'` heredoc approach is unreliable — pwsh can treat
  stdin as interactive and print prompts instead of running the script.

### Editing files

Re-read a file whenever it may have changed since you last read it — e.g. the user has edited it,
or time has passed. Don't rely on a stale read.

To undo an edit you just made, your default move is an **inverse Edit**: swap the `old_string`
and `new_string` from your original Edit call. You have both in your working memory — there's
no need to regenerate the prior content from inferred memory, and no need to reach for
`git diff` first. Reach for git only if you have a specific reason to doubt your own context
(file modified externally, many turns elapsed since the edit, suspect whitespace/CRLF
handling, or your edit overlaps other recent changes you want to preserve). Don't use
`git checkout <file>` — it can wipe accumulated work even on files that appear untracked.

For renaming a token across multiple files, use multiple Edit `replace_all` calls rather than a
single pwsh heredoc with `-replace` + `Set-Content`. The pwsh approach can silently produce no
change on some files (likely CRLF/encoding interaction); Edit is reliable.

Before using `replace_all`, scan the file and confirm every occurrence should be replaced —
string literals, `Describe`/`Context` labels, and comments can all contain the token without
being targets. If any occurrence should be left untouched, use targeted individual Edits instead.

For multi-line string replacements in pwsh scripts, use `.IndexOf()` + `.Substring()` rather than
`.Replace()` with multi-line literals. Single-quoted PS strings don't expand `` `r`n ``, so `.Replace()`
silently fails on CRLF content. Index-based splicing is reliable regardless of line endings.

When replacing a large block of text in a Windows file (CRLF line endings), the Edit tool's
string matching can fail even when the content looks correct — "String to replace not found."
Workaround for large deletions:
1. Insert marker comments using small targeted Edits (short unique strings match reliably):
   - Before the block: `<!-- DELETE_FROM_HERE -->`
   - After the block: `<!-- DELETE_TO_HERE -->`
2. Run the helper script:
   ```bash
   pwsh -File ~/prat/lib/agents/Remove-MarkedBlock.ps1 -Path 'C:/path/to/file.md'
   ```
   Custom markers: add `-From '<!-- MY_START -->' -To '<!-- MY_END -->'`.

---

## Model workarounds

Compensate for model reasoning/behavior tendencies. Review when upgrading Claude model versions.

### Plan vs. context contradictions

Before implementing a plan step, cross-check it against CLAUDE.md and done files for contradictions —
plans can go stale. Also cross-check the step spec against the plan's own design discussion: if the
discussion flags an edge case as unresolved or awkward, verify the step actually handles it.

### Reasoning

Don't borrow justifications from adjacent contexts. A fact about one thing ("this sandbox's goal is
mistake prevention") doesn't answer a different question ("should we harden this new SSH config").
Each concern stands on its own: evaluate it directly rather than letting a nearby framing dismiss it.
Same pattern: "this is a prototype" doesn't mean tests don't matter; "this is internal" doesn't mean
input validation isn't needed.

### Incremental transformations

When removing any structural element during a refactor or migration — comment, error handling,
resource cleanup (e.g. `Push-Location`/`Pop-Location`), try/finally — decide whether it belongs
in the end state. If yes, carry it forward immediately — as a TODO comment if the target code
doesn't exist yet — rather than deferring with no tracking mechanism.

### Debugging

Find root cause before fixing. If three fixes have failed, stop and question the approach rather
than attempting a fourth.

After proposing a code fix, consider what else it affects beyond the target problem.

When investigating whether your changes caused pipeline failures, enumerate all non-feature-gated
changes (DI registrations, constructor params, interface additions, config) before concluding
failures are unrelated. Feature-gate reasoning alone is insufficient — startup and wiring changes
affect every code path.

When challenged on a causal hypothesis (e.g. "you made the edit while I was responding"), don't
restate it — either produce evidence or investigate. Repeating an unverified claim after pushback
erodes trust and wastes turns. Add diagnostic logging, check timestamps, or find another way to
confirm before asserting again.

### Claiming success

If you tell the user something worked, that claim should be backed by evidence — not just "the script
exited cleanly". Either the action was self-evidently verifiable (e.g. the Edit tool confirmed a
match), or you checked the result. If you haven't checked, don't claim success.

For performance comparisons ("X is faster"), measure both before and after from the same execution
path. Don't use failure-path timings as a proxy.

When explaining *why* a pattern exists in data, present competing hypotheses — don't assert one.
The data shows what happened; the cause is a separate claim that needs its own evidence.

When claiming a trend from time-series data, normalize against volume first. A declining count
may just mean less activity — show the *rate* before calling it a signal.

### Surfacing documented constraints

If you've written a comment or note encoding a constraint or dependency, surface it when given an
instruction that conflicts with it.

### Deferred-work comments

A "we can't yet do X" comment in code should:

- Name the precise check or behavior we can't enforce, in succinct code terms.
- Link to the work item / task that tracks the unblocker. A bare task number is enough. "Easily verifiable" is the goal.
- Not restate context the surrounding code already provides.

The comment is a pointer, not a self-contained essay.

Example (good): `// We can't yet enforce X != Y, until we have done the corresponding plumbing — task 12345.`

### Friction in tooling is a defect to address, not a cost to route around

When a tool or instruction fails (broken command, auth error, missing dep, slow check), the
default response is *not* "let me skip this and move on" or "let me spot-check manually" —
those frame friction as a per-task nuisance instead of a defect that will keep recurring. This
user prefers "slow is smooth, smooth is fast": stop and address (or at least partially address)
the root cause — fix the tool, disable the failing instruction for this user, or file a concrete
follow-up. Repeated minor friction has substantial cumulative cost. Offering to skip is fine as
*one* option, but never as the only proposal.

### Scope discipline applies to my unsolicited additions, not to user-raised problems

When the user surfaces a problem affecting them, engage with it — don't reach for "out of scope",
"follow-up bug", or "different team's area" as a default. YAGNI/scope rules are about resisting
my own scope creep, not about deflecting the user's concerns. Filing a bug is sometimes punting,
not pragmatism — name it as a tradeoff, not the obvious answer. If proposing to defer, ground
the reasoning in real, observed constraints (PR scope, branch state, time pressure the user has
expressed) — not invented preferences.

Never use quote marks unless citing the user's actual words.

### Filler confidence claims

Don't narrate your own approval of your work ("that looks right", "looks good", "this is correct",
"clean", "much simpler", "elegant". Quality assessments imply validation: if you haven't validated
independently, don't make them. (Of course it looks right to you! You just generated it!)

### Code review

No performative agreement ("Great point!", "You're absolutely right!"). Just fix it — actions speak.

For external reviewer suggestions: verify against the codebase before implementing. Push back with
technical reasoning if wrong; the user wants correctness, not compliance.

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
`skillOverrides`) rather than writing to `.claude/settings.local.json`. `agency claude` passes the flag
through to `claude`.

## Public repos (e.g. prat, prefs)

Before finalizing a feature branch or committing directly to main in a public repo,
invoke `/check-prat-layers`. This runs `Find-SensitiveData` and `Find-LayerViolations`
across all installed prat-ecosystem repos with the appropriate merged config for each.

## Layer conventions

When writing examples or prose in prat (or any public layer):
- Use generic placeholder names (`myproject`, `myrepo`, `myfunction`) — never real names from
  private layers (like the user's `de` repo)
- Don't reference identifiers that don't exist in prat itself

