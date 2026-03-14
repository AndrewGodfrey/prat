# instructions from the 'prat' dev environment (apply to all repos)

---

## Environment facts

These are stable — no periodic review needed.

### Useful tools

- `glp [range]` — compact git log (date, author, hash, message). Prefer over `git log --oneline`
  when reviewing history. Example: `glp main...localAgentSandbox`.
  Features: Omits author where irrelevant; automatically adds `--graph` where relevant.

#### Interactive aliases (installed by prat into `~/prat/auto/profile/interactiveAliases.ps1`)

When telling the user to run something, prefer these aliases over full command names:

- `d` — Deploy-Codebase (runs the deploy script for the current codebase)
- `ude` — Update-DevEnvironment
- `t` — Test-Project
- `b` — Build-Codebase
- `c` — Set-LocationUsingShortcut (navigate by repo shortcut)

### Forcing a deploy stage to re-run

Some deploy stages track state in instDb files. For those, to force a re-run:
`rppr <stageName> && d`. The stage name matches the string passed to `StartStage`.

### Testing

Write the test first, and run it to verify it fails in the expected way. Only implement after that.

Run tests after any fix, even when confident. Reasons: catches unknown unknowns, and gives the user
evidence rather than just your assurance.

Before changing code with inadequate unit-test coverage, propose adding coverage first.

If anyone proposes skipping tests, push back — ask for justification. Accept if the reasons are
sound (e.g. behavior will be tested manually; e.g. consequences of failure are small). "Design is likely
to change" is not sufficient on its own. To refactor a high-stakes area, one approach is: write pinning
tests; refactor; cover with unit tests; remove the pinning tests.

See the `testing` skill for more detail. Use the `test-and-fix` agent to delegate test-fixing to a
subagent.

When /compact summarizes a session, record the state of each test run (not yet run / verified red /
verified green) alongside file changes. These are distinct states with different implications.

### Self-improvement

#### Capturing corrections

When the user corrects a behavioral mistake, update the relevant file so it doesn't recur:
- Dev-environment-wide facts and tools (apply to any repo when using this environment) → `prat/lib/agents/agent-user.md`
- Repo-specific facts → that repo's `CLAUDE.md` (e.g. `prat/CLAUDE.md` for prat-specific conventions)
- User-specific preferences → `de/lib/agents/agent-user.md`
- Triggerable procedures → modify/create a command or agent (or skill, but skill triggering seems unreliable)

Distinguish behavioral corrections ("you didn't X", "why didn't you Y") from one-time task direction
("please also include X in this document"). Test: would a fresh Claude have made the same mistake
without this direction? If yes, capture it. If no, it was context-specific — skip.

Edge case: "please ask me before doing X" sounds one-time but is usually a standing preference — flag
for confirmation before capturing.

### Dev environment

- Managed by the `de` and `prat` repos. Each `de` repo is user-specific. If a user says "the" de repo
  they mean their own one.
- When making a plan, label each step with "[USER]" or "[CLAUDE]" as appropriate.

### Style

- Markdown files: wrap lines at 120 characters max. Break at natural phrase boundaries
  for readability (like this).

---

## Claude Code / tool workarounds (Windows)

CC is not well-designed for Windows. Review this section when CC improves Windows support.

### Bash tool

- Always use forward slashes in paths, e.g. `C:/Users/foo` not `C:\Users\foo`. Backslashes will be
  misinterpreted.
- `~` only expands in pwsh. Most external programs on Windows (including git) don't understand it —
  use `$home/prefs` or the full path instead. In pwsh you can freely use `~/prefs`, `cd ~/prat`, etc.
- For PowerShell one-liners, use single quotes: `pwsh -c '...'` — bash won't interpolate `$` or
  backticks, so PowerShell receives them as-is. Only use double quotes if you need bash to expand
  a variable into the command first.
- For multi-statement scripts or anything complex, use a single-quoted heredoc — no escaping needed:
  ```bash
  pwsh -File - <<'PWSH'
  $var = $env:USERNAME
  Write-Host "Hello $var"
  PWSH
  ```
  The single-quoted delimiter `<<'PWSH'` is what prevents bash interpolation inside the heredoc.

### Editing files

When replacing a large block of text in a Windows file (CRLF line endings), the Edit tool's
string matching can fail even when the content looks correct — "String to replace not found."
Workaround for large deletions:
1. Insert marker comments using small targeted Edits (short unique strings match reliably):
   - Before the block: `<!-- DELETE_FROM_HERE -->`
   - After the block: `<!-- DELETE_TO_HERE -->`
2. Use a pwsh script to splice between the markers:
   ```bash
   pwsh -File - <<'PWSH'
   $path = 'C:/path/to/file.md'
   $c = Get-Content $path -Raw
   $a = $c.IndexOf('<!-- DELETE_FROM_HERE -->')
   $b = $c.IndexOf('<!-- DELETE_TO_HERE -->') + '<!-- DELETE_TO_HERE -->'.Length
   if ($c[$b] -eq "`r") { $b++ }
   if ($c[$b] -eq "`n") { $b++ }
   Set-Content $path ($c.Substring(0, $a) + $c.Substring($b)) -NoNewline -Encoding UTF8
   PWSH
   ```

---

## Model workarounds

Compensate for model reasoning/behavior tendencies. Review when upgrading Claude model versions.

### Reasoning

Don't borrow justifications from adjacent contexts. A fact about one thing ("this sandbox's goal is
mistake prevention") doesn't answer a different question ("should we harden this new SSH config").
Each concern stands on its own: evaluate it directly rather than letting a nearby framing dismiss it.
Same pattern: "this is a prototype" doesn't mean tests don't matter; "this is internal" doesn't mean
input validation isn't needed.

### Incremental transformations

When removing a comment during a refactor or migration, decide whether it belongs in the end
state. If yes, carry it forward immediately — as a TODO comment if the target code doesn't exist
yet — rather than deferring with no tracking mechanism.

### Debugging

Find root cause before fixing. If three fixes have failed, stop and question the approach rather
than attempting a fourth.

### Code review

No performative agreement ("Great point!", "You're absolutely right!"). Just fix it — actions speak.

For external reviewer suggestions: verify against the codebase before implementing. Push back with
technical reasoning if wrong; the user wants correctness, not compliance.

### Don't say "noted"

Don't say "noted" — it implies the information will be remembered, which is only true if it was
actually written somewhere persistent. Either write it down or say nothing.

### Pacing and initiative

Don't prompt for commits or ask "ready to commit?" after each response — the user signals when they're
ready for commit-prep.

Don't start commit prep (calling the git skill, running git status/diff/log, staging) without explicit
instruction. "Tests pass" is not a signal to commit — the user signals readiness.
