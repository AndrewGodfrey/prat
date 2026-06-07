---
name: audit-code
description: Use when producing a shareable audit deliverable that surveys many callsites of a concept, API, field, or pattern across a codebase, and classifies each callsite into one of a small set of decisions (e.g. `keep` / `switch` / `add` / `defer` / `discuss`). The deliverable is intended for review, possibly by other people too.
---

## Why this shape

A code-audit doc has two jobs that pull in opposite directions:

1. **Help the author reason** about each callsite. Grouping by decision (D1, D2…) is how the
   thinking happens — similar callsites cluster, the label falls out of the cluster, and the
   prose justifying the label can cover all of them at once.
2. **Prove completeness to a reviewer** who didn't iterate with the author. A flat
   callsite-by-callsite appendix is the only way a reviewer can verify "every callsite I
   care about appears here and has a label". Per-decision tables alone don't prove this —
   the reviewer would have to track which callsites haven't been mentioned yet.

The format below carries both: per-decision sections for the reasoning, a flat appendix for
the completeness check. Both reference the same callsite IDs so reviewers can jump back and
forth.

## When to use

- Surveying every use of a concept across the codebase to decide what to change.
- Migration, deprecation, security review, or any "classify N callsites against K decisions" task.

## Structure

**Header**:

- `# Audit all uses of <thing>` — title.
- Task / user-story link.
- **Code references callout** — pin all code links to a specific commit SHA (full 40 chars, since some tools reject 
  short SHAs). Note that revisiting against newer master means updating the SHA.

**Action tables — near the top, before Background**:

- **Workitems filed** — `| Item | Notes |`. One row per workitem (however the project tracks those) created from the audit,
  with a pointer to which decision it came from.
- **Discussion needed** — `| Decision | Topic |`. One row per `discuss` decision, so a reader
  sees open questions before reading prose.

**Background** — what the concept is, why the audit exists, what the per-callsite question is.

**Entity relationships** (optional) — mermaid ERD if the concept's identity is entangled with
other entities.

**Decisions** (the reasoning aid) — one section per decision, in the form:

```markdown
### <a id="d<N>"></a>D<N>. <one-line topic> — `<label>`

<2-6 lines of prose: what these callsites have in common, why this label.>

| #   | Code reference |
| --- | -------------- |
| [<callsite-id>](#<callsite-id>) | [<file>:<line>](<ADO url>) |
```

**Summary table** — at the top of the Decisions block, mapping label → list of decision links:

```markdown
| Label  | Meaning                                  | Decisions          |
| ------ | ---------------------------------------- | ------------------ |
| keep   | no action needed                         | [D1](#d1), [D4](#d4) |
| switch | should use <new thing> instead           | none               |
| ...    |                                          |                    |
```

**Appendix** (the completeness proof) — `## Appendix: callsite → decision`, a flat table of
every callsite with its decision label. Order by callsite ID. Anchor each row with
`<a id="<callsite-id>"></a>` so per-decision tables can link back. If a callsite isn't in the
appendix, it's not in the audit — this is the table reviewers scan to verify nothing's missing.

## Callsite IDs

Use a service-prefix scheme: 2 letters for the service/area + sequential number (e.g. `FO1`, `FO2`
for component Foo). Lets decision prose cite IDs without re-linking and keeps the appendix scannable.

## Code links

"linkify" code references where possible. That is, if the repo has a remote that lets you make urls for browsing the code,
do that. Hopefully you have an appropriate 'linkify' skill loaded, since this those URLs are tricky.
