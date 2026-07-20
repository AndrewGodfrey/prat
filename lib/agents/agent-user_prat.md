# instructions from the 'prat' dev environment (apply to all repos)
Source: prat/lib/agents/agent-user_prat.md
---

## Environment facts

### Useful pwsh commands

These are PowerShell functions/aliases, not tool-calling tools.

- `glp [range]` — compact git log (date, author, hash, message). Prefer over `git log --oneline`
  when reviewing history. Example: `glp main...localAgentSandbox`.
  Features: Omits author where irrelevant; automatically adds `--graph` where relevant.
- `c` — Set-LocationUsingShortcut (navigate by repo shortcut)

### Pratified projects

To check if a project is pratified, `Get-PratProject (Get-Location)` — returns `$null` if not registered.

When telling the user to run something, prefer these pwsh aliases over full command names:

- `d` — Deploy-Codebase (pratified projects only — see below)
- `t` — Test-Codebase (pratified projects only — see below)
- `b` — Build-Codebase (pratified projects only — see below)
- `pb` — Prebuild-Codebase (pratified projects only — see below)

For usage details, load the `pratified-dev-loop` skill.


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

See the `testing` skill for more detail. Assume all repos are pratified — use `t` and the
`pratified-dev-loop` skill by default. Only use `run-tests` if the repo is marked non-pratified,
either in its own `AGENTS.md` (e.g. `**Pratified:** No`) or in the user's personal instructions
(for repos where editing `AGENTS.md` isn't possible).

When context is compacted/summarized, record the state of each test run (not yet run / verified red /
verified green) alongside file changes. These are distinct states with different implications.

There is no such thing as "indirect" test coverage: a coverage tool only reports a line as covered
if it actually executed, so a function every test replaces with a mock is uncovered, regardless of
how often it's referenced.

### Dev environment

- Managed by the `de` and `prat` repos. Each `de` repo is user-specific. If a user says "the" de repo
  they mean their own one.

---

## Editing files

When inserting content, anchor on the **smallest unique string** at the insertion point. Don't pull
surrounding unchanged content into `old_string` — it causes a noisier diff and is more likely to
fail on CRLF files.

Re-read a file whenever it may have changed since you last read it — e.g. the user has edited it,
or time has passed. Don't rely on a stale read.

---

## Model workarounds

Compensate for model reasoning/behavior tendencies. Review when upgrading agent model versions.

### Plan vs. context contradictions

Before implementing a plan step, cross-check it against project instructions and done files for contradictions —
plans can go stale. Also cross-check the step spec against the plan's own design discussion: if the
discussion flags an edge case as unresolved or awkward, verify the step actually handles it.

### Reasoning

Don't borrow justifications from adjacent contexts. A fact about one thing ("this sandbox's goal is
mistake prevention") doesn't answer a different question ("should we harden this new SSH config").
Each concern stands on its own: evaluate it directly rather than letting a nearby framing dismiss it.
Same pattern: "this is a prototype" doesn't mean tests don't matter; "this is internal" doesn't mean
input validation isn't needed.

### Security reasoning: non-destructive ≠ safe

When assessing whether to allow a tool or permission: "non-destructive" (no data loss) is not the
same as "safe". There are multiple distinct failure modes beyond data destruction — exfiltration and
prompt injection are two examples. Don't grant a permission on the grounds that it can't destroy data.

### Incremental transformations

When removing any structural element during a refactor or migration — comment, error handling,
resource cleanup (e.g. `Push-Location`/`Pop-Location`), try/finally — decide whether it belongs
in the end state. If yes, carry it forward immediately — as a TODO comment if the target code
doesn't exist yet — rather than deferring with no tracking mechanism.

Applies equally to prose content (notes, musings, rationale) in plan files — when restructuring a
step, either carry such content forward or explicitly decide to discard it; don't drop it by reference.

When removing a mechanism/class entirely, a "confirmed zero remaining references" check must also
grep the plan file's own not-yet-done steps, not just source code — otherwise design notes describing
the removed mechanism linger in open steps until the user notices.

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

### Preserving investigation evidence

Don't delete artifacts an investigation produced (downloaded models, server logs, raw request/response
transcripts) once you're reporting a conclusion they back — even though scratch/experiment files are
otherwise yours to clean up freely. Keep them until the user confirms they're done reviewing, or ask
first.

### Generated files don't accumulate in the source tree

Generated files must not accumulate in the source tree — not even gitignored: a gitignored but
un-cleaned dir is *worse* than a visible one, since nothing ever removes it. Put generated output
where it's managed: `auto/` (the audited, auto-cleaned home) or your scratchpad for transient
scratch. The pratified tools (`t`, `b`, …) already route output to `auto/`; the rule bites on ad-hoc
runs (raw `pytest`/`dotnet`/a build) — redirect output up front (`COVERAGE_FILE`,
`PYTHONPYCACHEPREFIX`, MSBuild `OutputPath`/`BaseIntermediateOutputPath` via
`Directory.Build.props`). "It can't be redirected" is a claim to verify, not accept. Never gitignore
a stray to silence it.

### Claiming success

Every claim needs evidence traced from the artifact itself, not an adjacent signal — whether the
claim is about success, cost, a trend, a cause, or code behavior. "The script exited cleanly" is
not evidence it worked: either the action was self-evidently verified (e.g. the Edit tool confirmed
a match), or you checked the result. Two sharp recurring instances:

- Before claiming a function "never raises" or "handles all failure modes", trace every I/O/external
  call inside it — don't generalize from the exception types its try/except already names.
- A declining count may just mean less activity — normalize against volume before calling it a trend.

The same discipline covers pending-work claims (name the concrete check) and causes: the data shows
what happened, but a cause — including one stated in a skill or doc — is a hypothesis until it has
its own evidence.

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

### Scope discipline applies to your unsolicited additions, not to user-raised problems

When the user surfaces a problem affecting them, engage with it — don't reach for "out of scope",
"follow-up bug", or "different team's area" as a default. YAGNI/scope rules are about resisting
your own scope creep, not about deflecting the user's concerns. Filing a bug is sometimes punting,
not pragmatism — name it as a tradeoff, not the obvious answer. If proposing to defer, ground
the reasoning in real, observed constraints (PR scope, branch state, time pressure the user has
expressed) — not invented preferences.

### Code review

No performative agreement ("Great point!", "You're absolutely right!") and no self-approval of your
own output ("looks good", "clean", "elegant") — an unvalidated quality assessment is filler; of
course it looks right to you, you just generated it. Just fix it — actions speak.

Verify against the codebase before implementing or asserting — whether the claim comes from an
external reviewer or is a finding you generated yourself. Push back with technical reasoning if a
suggestion is wrong — the user wants correctness, not compliance.

### External references

When the user provides a URL, preserve it verbatim in any file you write it to — don't collapse
to anchor form (`#123`) or a bare issue number.

## Planning

### Sequencing removal vs. replacement

When a plan splits removing an old mechanism from wiring its replacement across separate steps,
order the removal after the replacement is live (or guard it as a no-op until then). Deleting the
old mechanism first leaves the system broken in between. This also applies when a single step's own
task list bundles the removal with a "once the new code lands" condition — code-complete/TDD-passing
is not the same as wired live; read "once X supersedes it" as "once X is live," not "once X exists."

## Public repos (e.g. prat, prefs)

Before finalizing a feature branch or committing directly to main in a public repo,
invoke `/check-prat-layers`. This runs `Find-SensitiveData` and `Find-LayerViolations`
across all installed prat-ecosystem repos with the appropriate merged config for each.

## Layer conventions

When writing examples or prose in prat (or any public layer):
- Use generic placeholder names (`myproject`, `myrepo`, `myfunction`) — never real names from
  private layers (like the user's `de` repo)
- Don't reference identifiers that don't exist in prat itself
- Referencing expected filenames in a de repo (e.g. `de/lib/agents/agent-user_de.md`) is
  fine — that's part of the prat ecosystem. But don't reference specific contents of a particular user's de repo
  — that's a layer violation

