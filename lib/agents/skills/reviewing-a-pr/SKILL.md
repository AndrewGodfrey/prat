---
name: reviewing-a-pr
description: Use when reviewing a pull request or feature branch — e.g. the user invokes `/review`,
  pastes a PR URL, or says "review this branch". Picks git ranges that stay clean even when the
  branch has merged from its base, so the diff reflects the feature work rather than base churn.
---

# The problem

When a branch has had its base (master/main) merged in, naïve ranges get noisy:

- `git diff <base>..<branch>` (two-dot) diffs the two tips, so it includes every base-side change
  that came in via the merge — even though those aren't part of the feature work.
- Merge commits clutter `git log <base>..<branch>` output.

The user prefers to rebase feature branches rather than merge from base, but later in a review it
can be unavoidable — so any review workflow has to handle the merged-in case correctly.

# Context

Written against Claude Code **v2.1.119**'s built-in `/review` skill, which tends to review base churn
as well as feature work. If a future `/review` skill implementation handles this cleanly, 
perhaps this skill can be retired.

# What to do instead

- **Diff: three-dot.** `git diff <base>...<branch>` diffs from the merge base to the branch tip.
  That's the feature's contribution, and it's correct whether or not base was ever merged in.
- **Log: `--no-merges`.** Drops merge commits so only feature commits remain.

# Workflow

1. Identify the base (usually `master`/`main`; occasionally a parent feature branch).

2. Fetch and gather log + stat in one chained command:
   ```
     git fetch origin && \
     git log --no-merges origin/<base>..origin/<branch> && \
     git diff --stat origin/<base>...origin/<branch>
   ```

3. For per-file diffs during review, keep three-dot:
   `git diff origin/<base>...origin/<branch> -- <path>`.

# When this doesn't apply

- Reviewing a single commit → `git show <sha>`.
- Reviewing local uncommitted changes → `/review-changes`.
