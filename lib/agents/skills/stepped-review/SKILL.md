---
name: stepped-review
description: Iterative review loop for a document or codebase. Linear scan top-to-bottom,
  stop at the first issue per user-specified criteria, propose fix, wait for go/stop/revise,
  apply, then resume from the edit position (not from the top). Use when the user asks to iterate
  through a document/codebase finding issues one at a time.
---

# Stepped review loop

Streamlined, iterative review pattern for a document, file, or codebase, with explicit user approval at
each step.

## When to invoke

User asks to scan content and stop at issues one by one, fixing each before continuing.
Examples:
- "Iterate through this doc and stop at the first issue"
- "Step through the file and fix issues one by one"
- "Find inconsistencies in here, one at a time"

## Up-front calibration

Before starting, confirm with the user if not specified:

1. **Criteria for "issue":** what counts as an issue worth stopping for? (e.g. inconsistency,
   sloppy framing, redundancy, misplaced information, factual error.) Without this, the loop
   has no decision rule and will either over- or under-flag.
2. **Narrow vs broader fixes:** when an issue could be either a narrow fix or a broader
   restructure, default to narrow. Only flag the broader option when it would be substantially
   cleaner.
3. **Per-iteration interaction:** report each issue with a proposed fix, and wait for
   go/stop/revise.

## The loop

```
1. Read region (full document or specified range), top to bottom.
2. Find the first issue per criteria.
3. Report: location (line numbers), type of issue, proposed fix.
4. Wait for go/stop/revise.
5. Apply the approved fix.
6. Resume scan from the previous position (or earlier if you just made substantial edits before that).
7. Repeat from step 2 until clean pass, or user halts.
```

## Why resume, not restart

Restart-from-top reads the full document on every pass. With n issues, that's O(n²) reads
× n passes' worth of work = O(n³) total. Linear scan-with-resumption is O(n²) total —
quadratically less work.

The temptation to restart is real (a fix might have invalidated content earlier in the
document). The rule: **only restart if a fix has ripple effects to earlier-checked
content.** Most narrow fixes don't.

## Re-read before quoting after edits

If time has passed or the user has signaled they made an edit, re-read the relevant region
before quoting it back to them.

## Termination

- Clean pass with no further issues found, or
- User halts the loop.

Optionally summarize all issues fixed at the end (one line each).
