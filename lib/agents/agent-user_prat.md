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

Run tests after any fix, even when confident. Reasons: catches unknown unknowns, and gives the user
evidence rather than just your assurance.

Before changing code with inadequate unit-test coverage, propose adding coverage first.

If anyone proposes skipping tests, push back — ask for justification. Accept if the reasons are
sound (e.g. behavior will be tested manually; e.g. consequences of failure are small). "Design is likely
to change" is not sufficient on its own. To refactor a high-stakes area, one approach is: write pinning
tests; refactor; cover with unit tests; remove the pinning tests.

See the `testing` skill for more detail. Use the `prat-run-tests` agent to delegate test runs to a
subagent (pratified codebases); use `run-tests` for other codebases.

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
- `~` only expands in pwsh. Most external programs on Windows (including git) don't understand it —
  use `$home/prefs` or the full path instead. In pwsh you can freely use `~/prefs`, `cd ~/prat`, etc.
- For PowerShell one-liners, use single quotes: `pwsh -c '...'` — bash won't interpolate `$` or
  backticks, so PowerShell receives them as-is. Only use double quotes if you need bash to expand
  a **bash** variable into the command. PowerShell variables (`$home`, `$env:USERNAME`, etc.) must
  stay in single quotes — bash expands them to empty. ❌ `pwsh -c "... $home ..."` silently passes
  an empty string.
- For multi-statement scripts or anything complex, use a single-quoted heredoc — no escaping needed:
  ```bash
  pwsh -File - <<'PWSH'
  $var = $env:USERNAME
  Write-Host "Hello $var"
  PWSH
  ```
  The single-quoted delimiter `<<'PWSH'` is what prevents bash interpolation inside the heredoc.

### Editing files

Re-read a file whenever it may have changed since you last read it — e.g. the user has edited it,
or time has passed. Don't rely on a stale read.

For renaming a token across multiple files, use multiple Edit `replace_all` calls rather than a
single pwsh heredoc with `-replace` + `Set-Content`. The pwsh approach can silently produce no
change on some files (likely CRLF/encoding interaction); Edit is reliable.

For multi-line string replacements in pwsh scripts, use `.IndexOf()` + `.Substring()` rather than
`.Replace()` with multi-line literals. Single-quoted PS strings don't expand `` `r`n ``, so `.Replace()`
silently fails on CRLF content. Index-based splicing is reliable regardless of line endings.

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

### Plan vs. context contradictions

Before implementing a plan step, cross-check it against CLAUDE.md and done files for contradictions —
plans can go stale.

### `$PSScriptRoot` when merging scripts

When merging scripts that run from different locations (e.g. a distributed OneDrive copy vs. its source
in a repo), audit all `$PSScriptRoot`-relative paths — they may be correct in one location but broken
in the other.

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

### Claiming success

If you tell the user something worked, that claim should be backed by evidence — not just "the script
exited cleanly". Either the action was self-evidently verifiable (e.g. the Edit tool confirmed a
match), or you checked the result. If you haven't checked, don't claim success.

For performance comparisons ("X is faster"), measure both before and after from the same execution
path. Don't use failure-path timings as a proxy.

### Surfacing documented constraints

If you've written a comment or note encoding a constraint or dependency, surface it when given an
instruction that conflicts with it.

### Code review

No performative agreement ("Great point!", "You're absolutely right!"). Just fix it — actions speak.

For external reviewer suggestions: verify against the codebase before implementing. Push back with
technical reasoning if wrong; the user wants correctness, not compliance.

### Claude Code feature knowledge

Your training data knowledge of Claude Code features is unreliable — file loading behavior, include syntax,
skill discovery, settings, and conventions are all areas where you've been confidently wrong. Before making
claims about what Claude Code does or doesn't support, consult the `claude-code-guide` agent. Don't answer
authoritatively from model knowledge alone.

## Installers framework conventions

When writing `install` scriptblocks in `$pratPackages`, add `$stage.SetSubstage("description")`
before each long-running operation (network downloads, elevated installs, etc.) to give the user
progress visibility.

## Public repos (e.g. prat, prefs)

Before finalizing a feature branch or committing directly to main in a public repo, run
`Find-SensitiveData` and remind the user to do this if they haven't mentioned it:

```powershell
Find-SensitiveData -Path ~/prat  # for example
```

The tool auto-detects hardcoded home paths, email addresses, and IP addresses. Also manually
verify the file contains none of:

- Full paths with username (`C:\Users\<username>\...`) — replace with `$home\...`
- Account usernames (GitHub, work accounts, etc.)
- User email addresses
- Machine names, hostnames
- Internal URLs, site names, channel/team names, email DLs, IP addresses
- Tokens, passwords, API keys, SSH private keys
